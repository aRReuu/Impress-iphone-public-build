import Foundation
import CryptoKit
import WCDBSwift

/// Recovered totals reflect the archive, not the device's active database.
struct ImpressV3BackupInspection {
    let manifest: ImpressV3BackupManifest
    let cardCount: Int
    let reviewCount: Int
    let learningCount: Int
    /// Nil for V1 archives: do not erase existing calibration data.
    let calibrationCount: Int?
}

/// File-provider access uses an explicit, user-selected Files folder. The
/// application never sends data to an HTTP endpoint or stores API credentials.
actor ImpressV3BackupCoordinator {
    static let shared = ImpressV3BackupCoordinator()

    static let bookmarkKey = "ImpressV3BackupCloudFolderBookmark"
    static let dirtyKey = "ImpressV3BackupNeedsSnapshot"
    static let localDateKey = "ImpressV3BackupLocalDate"
    static let cloudDateKey = "ImpressV3BackupCloudCopiedDate"
    static let failureKey = "ImpressV3BackupLastError"
    private static let lastMutationKey = "ImpressV3LastMutationTimestamp"
    private static let pendingCloudFileKey = "ImpressV3PendingCloudFile"

    private var active: Task<URL, any Swift.Error>?
    private var pendingDebouncedBackup: Task<Void, Never>?

    static func markDataChanged() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastMutationKey)
        UserDefaults.standard.set(true, forKey: dirtyKey)
        // A foreground session can last for hours; do not wait for suspension
        // to protect recently committed FSRS or card changes.
        Task(priority: .utility) {
            await shared.scheduleDebouncedBackup()
        }
    }

    private func scheduleDebouncedBackup() {
        pendingDebouncedBackup?.cancel()
        let last = UserDefaults.standard.object(forKey: Self.localDateKey) as? Date
        let elapsed = Date().timeIntervalSince(last ?? .distantPast)
        let waitSeconds = max(45, 20 * 60 - elapsed)
        pendingDebouncedBackup = Task(priority: .utility) { [self] in
            do { try await Task.sleep(nanoseconds: UInt64(waitSeconds * 1_000_000_000)) }
            catch { return }
            guard !Task.isCancelled else { return }
            await self.backupIfNeeded()
            // If a mutation landed mid-snapshot, keep it pending until the
            // next eligible interval even without leaving the foreground.
            let stillDirty = UserDefaults.standard.bool(forKey: Self.dirtyKey)
            let sinceLast = Date().timeIntervalSince(
                (UserDefaults.standard.object(forKey: Self.localDateKey) as? Date)
                    ?? .distantPast)
            if stillDirty && sinceLast < 20 * 60 {
                self.scheduleDebouncedBackup()
            }
        }
    }

    static func supportDirectory() throws -> URL {
        try FileManager.default.url(for: .applicationSupportDirectory,
            in: .userDomainMask, appropriateFor: nil, create: true)
    }

    static func localDirectory() throws -> URL {
        let root = try supportDirectory().appendingPathComponent(
            "ImpressV3Backups", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        return root
    }

    static func mostRecentLocalBackup() -> URL? {
        guard let root = try? localDirectory(),
              let files = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil)
        else { return nil }
        return files.filter { $0.lastPathComponent.hasPrefix("ImpressV3-") &&
                              $0.pathExtension == "zip" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }.first
    }

    static var cloudFolderSelected: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    static func connectCloudFolder(_ selected: URL) throws {
        guard selected.startAccessingSecurityScopedResource() else {
            throw ImpressV3BackupFailure.notAuthorized
        }
        defer { selected.stopAccessingSecurityScopedResource() }
        let bookmark = try selected.bookmarkData(options: [],
            includingResourceValuesForKeys: nil, relativeTo: nil)
        UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
    }

    static func disconnectCloudFolder() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
        UserDefaults.standard.removeObject(forKey: pendingCloudFileKey)
    }

    /// Called at launch and after data changes; no UI or export panel.
    /// One local snapshot is retained even without Files authorization.
    func backupIfNeeded() async {
        do {
            let dirty = UserDefaults.standard.bool(forKey: Self.dirtyKey)
            let previous = Self.mostRecentLocalBackup()
            let last = UserDefaults.standard.object(forKey: Self.localDateKey) as? Date
            let elapsed = Date().timeIntervalSince(last ?? .distantPast)
            if previous == nil || (dirty && elapsed >= 20 * 60) {
                _ = try await createBackup(force: true)
            } else if Self.cloudFolderSelected {
                // Retry the exact last failed local snapshot, rather than
                // assuming an old successful cloud timestamp is up to date.
                let pendingName = UserDefaults.standard.string(
                    forKey: Self.pendingCloudFileKey)
                let pending = pendingName.flatMap { name -> URL? in
                    guard name.hasPrefix("ImpressV3-"), name.hasSuffix(".zip"),
                          !name.contains("/") else { return nil }
                    let item = try? Self.localDirectory().appendingPathComponent(name)
                    guard let item, FileManager.default.fileExists(atPath: item.path) else {
                        return nil
                    }
                    return item
                }
                if let candidate = pending ?? previous,
                   pending != nil ||
                   UserDefaults.standard.object(forKey: Self.cloudDateKey) == nil {
                    try Self.copyToAuthorizedCloud(candidate)
                }
            }
        } catch {
            UserDefaults.standard.set(error.localizedDescription, forKey: Self.failureKey)
        }
    }

    func createBackup(force: Bool = true) async throws -> URL {
        if let active { return try await active.value }
        if !force && !UserDefaults.standard.bool(forKey: Self.dirtyKey),
           let recent = Self.mostRecentLocalBackup() {
            return recent
        }
        let job = Task(priority: .utility) { try await self.buildSnapshot() }
        active = job
        do {
            let result = try await job.value
            active = nil
            return result
        } catch {
            active = nil
            UserDefaults.standard.set(error.localizedDescription, forKey: Self.failureKey)
            throw error
        }
    }

    private func buildSnapshot() async throws -> URL {
        let mutationAtStart = UserDefaults.standard.double(forKey: Self.lastMutationKey)
        let root = try Self.localDirectory()
        let staging = root.appendingPathComponent(".stage-" + UUID().uuidString,
                                                   isDirectory: true)
        try FileManager.default.createDirectory(
            at: staging, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        let database = staging.appendingPathComponent("ReviewV3.sqlite")
        let repository = try ImpressV3ReviewEnvironment.repository()
        // The WCDB actor serializes this with any pending FSRS commits.
        try await repository.createConsistentBackup(to: database)
        try ImpressV3BackupArchive.verifySQLite(database)

        let history = try JSONEncoder().encode(ImpressV3LearningJournal.load())
        try history.write(to: staging.appendingPathComponent("LearningEntry-v1.json"),
                          options: .atomic)
        let prompts = try JSONEncoder().encode(ImpressV3PromptLibrary.load())
        try prompts.write(to: staging.appendingPathComponent("prompts.json"),
                          options: .atomic)
        let calibration = try await ImpressCalibrationLocalStore.shared.archiveData()
        try calibration.write(
            to: staging.appendingPathComponent("checkins-v1.json"), options: .atomic)
        let names = ["ReviewV3.sqlite", "LearningEntry-v1.json", "prompts.json",
                     "checkins-v1.json"]
        let archiveName = "ImpressV3-" +
            ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-") +
            "-" + String(UUID().uuidString.prefix(8)) + ".zip"
        let output = root.appendingPathComponent(archiveName)
        // Only a fully verified snapshot gets a discoverable .zip filename.
        // If iOS suspends the process mid-write, the partial file is never
        // mistaken for the latest valid backup.
        let partial = root.appendingPathComponent(".partial-" + UUID().uuidString)
        let result = try await Task.detached(priority: .utility) { () throws -> URL in
            defer { try? FileManager.default.removeItem(at: partial) }
            let records = try names.map {
                try ImpressV3BackupArchive.inspectFile(
                    staging.appendingPathComponent($0), name: $0).0
            }
            let manifest = ImpressV3BackupManifest.make(records)
            try JSONEncoder().encode(manifest).write(
                to: staging.appendingPathComponent("manifest.json"), options: .atomic)
            try ImpressV3BackupArchive.write(
                files: (names + ["manifest.json"]).map {
                    (name: $0, url: staging.appendingPathComponent($0))
                }, destination: partial)
            let verification = staging.appendingPathComponent(".verified-" + UUID().uuidString)
            _ = try ImpressV3BackupArchive.extract(source: partial, destination: verification)
            try ImpressV3BackupArchive.verifySQLite(
                verification.appendingPathComponent("ReviewV3.sqlite"))
            _ = try ImpressCalibrationLocalStore.validateArchiveData(
                Data(contentsOf: verification.appendingPathComponent("checkins-v1.json")))
            try FileManager.default.removeItem(at: verification)
            try FileManager.default.setAttributes([
                .protectionKey: FileProtectionType.completeUntilFirstUserAuthentication
            ], ofItemAtPath: partial.path)
            try FileManager.default.moveItem(at: partial, to: output)
            return output
        }.value
        // A new card/review commit may have arrived while this snapshot was
        // being assembled. Keep it pending for the next backup cycle.
        let mutationAfter = UserDefaults.standard.double(forKey: Self.lastMutationKey)
        UserDefaults.standard.set(mutationAfter > mutationAtStart, forKey: Self.dirtyKey)
        UserDefaults.standard.set(Date(), forKey: Self.localDateKey)
        UserDefaults.standard.removeObject(forKey: Self.failureKey)
        Self.pruneOlderLocalBackups(keeping: 7)
        // Failure to reach iCloud never invalidates the verified local backup.
        if Self.cloudFolderSelected {
            UserDefaults.standard.set(result.lastPathComponent,
                forKey: Self.pendingCloudFileKey)
            do { try Self.copyToAuthorizedCloud(result) }
            catch {
                UserDefaults.standard.set(
                    "本地备份已成功，iCloud 副本未完成：" + error.localizedDescription,
                    forKey: Self.failureKey)
            }
        }
        return result
    }

    private static func pruneOlderLocalBackups(keeping limit: Int) {
        guard let root = try? localDirectory(),
              let all = try? FileManager.default.contentsOfDirectory(
                at: root, includingPropertiesForKeys: nil) else { return }
        let backups = all.filter {
            $0.lastPathComponent.hasPrefix("ImpressV3-") && $0.pathExtension == "zip"
        }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        let pending = UserDefaults.standard.string(forKey: pendingCloudFileKey)
        for obsolete in backups.dropFirst(limit) {
            // Do not prune the sole pending cloud upload during an offline period.
            guard obsolete.lastPathComponent != pending else { continue }
            try? FileManager.default.removeItem(at: obsolete)
        }
    }

    private static func copyToAuthorizedCloud(_ archive: URL) throws {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else {
            throw ImpressV3BackupFailure.notAuthorized
        }
        var stale = false
        let folder = try URL(resolvingBookmarkData: bookmark,
            options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
        guard !stale, folder.startAccessingSecurityScopedResource() else {
            throw ImpressV3BackupFailure.notAuthorized
        }
        defer { folder.stopAccessingSecurityScopedResource() }
        let target = folder.appendingPathComponent(archive.lastPathComponent)
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var copyError: (any Swift.Error)?
        coordinator.coordinate(writingItemAt: target, options: [],
                               error: &coordinatorError) { location in
            do {
                // A previous copy may have completed before the app could
                // record the acknowledgement. An identical file is success;
                // a different existing file must never be overwritten.
                if !FileManager.default.fileExists(atPath: location.path) {
                    try FileManager.default.copyItem(at: archive, to: location)
                }
                let original = try ImpressV3BackupArchive.inspectFile(
                    archive, name: archive.lastPathComponent).0
                let copied = try ImpressV3BackupArchive.inspectFile(
                    location, name: archive.lastPathComponent).0
                guard original.sha256 == copied.sha256,
                      original.size == copied.size else {
                    throw ImpressV3BackupFailure.invalidChecksum
                }
            } catch { copyError = error }
        }
        if let coordinatorError { throw coordinatorError }
        if let copyError { throw copyError }
        // Local file-provider write is verified; remote upload scheduling is
        // controlled by iOS/iCloud and must not be presented as cloud sync done.
        let left = try ImpressV3BackupArchive.inspectFile(archive, name: archive.lastPathComponent).0
        let right = try ImpressV3BackupArchive.inspectFile(target, name: archive.lastPathComponent).0
        guard left.sha256 == right.sha256 else {
            throw ImpressV3BackupFailure.invalidChecksum
        }
        UserDefaults.standard.set(Date(), forKey: cloudDateKey)
        UserDefaults.standard.removeObject(forKey: pendingCloudFileKey)
        UserDefaults.standard.removeObject(forKey: failureKey)
    }

    /// Import is read-only until the user explicitly confirms recovery.
    func inspectRecovery(_ archive: URL) async throws -> ImpressV3BackupInspection {
        let container = try Self.supportDirectory().appendingPathComponent(
            "ImpressV3RestoreInspection-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: container) }
        return try await Task.detached(priority: .utility) {
            try ImpressV3BackupArchive.extract(source: archive, destination: container)
            let database = container.appendingPathComponent("ReviewV3.sqlite")
            try ImpressV3BackupArchive.verifySQLite(database)
            let counts = try ImpressV3BackupArchive.recordCounts(database)
            // Malformed JSON must be rejected before destructive confirmation.
            let history = try JSONDecoder().decode(
                [ImpressV3LearningEntry].self,
                from: Data(contentsOf: container.appendingPathComponent("LearningEntry-v1.json")))
            _ = try JSONDecoder().decode(
                [ImpressV3PromptTemplate].self,
                from: Data(contentsOf: container.appendingPathComponent("prompts.json")))
            let manifest = try JSONDecoder().decode(
                ImpressV3BackupManifest.self,
                from: Data(contentsOf: container.appendingPathComponent("manifest.json")))
            let calibrationCount: Int?
            if manifest.formatVersion == 2 {
                calibrationCount = try ImpressCalibrationLocalStore.validateArchiveData(
                    Data(contentsOf: container.appendingPathComponent("checkins-v1.json")))
            } else {
                calibrationCount = nil
            }
            return ImpressV3BackupInspection(manifest: manifest,
                cardCount: counts.cards, reviewCount: counts.reviews,
                learningCount: history.count, calibrationCount: calibrationCount)
        }.value
    }

    func stageRecovery(_ archive: URL) async throws {
        let base = try Self.supportDirectory()
        let pending = base.appendingPathComponent(
            "ImpressV3PendingRestore", isDirectory: true)
        guard !FileManager.default.fileExists(atPath: pending.path) else {
            throw ImpressV3BackupFailure.restoreAlreadyPending
        }
        // Preserve a recoverable copy of the CURRENT state before staging.
        _ = try await createBackup(force: true)
        let verified = base.appendingPathComponent(
            ".ImpressV3RestoreTemp-" + UUID().uuidString, isDirectory: true)
        do {
            _ = try await Task.detached(priority: .utility) {
                try ImpressV3BackupArchive.extract(source: archive, destination: verified)
                try ImpressV3BackupArchive.verifySQLite(
                    verified.appendingPathComponent("ReviewV3.sqlite"))
                let manifest = try JSONDecoder().decode(
                    ImpressV3BackupManifest.self, from: Data(contentsOf:
                        verified.appendingPathComponent("manifest.json")))
                _ = try JSONDecoder().decode([ImpressV3LearningEntry].self,
                    from: Data(contentsOf:
                        verified.appendingPathComponent("LearningEntry-v1.json")))
                _ = try JSONDecoder().decode([ImpressV3PromptTemplate].self,
                    from: Data(contentsOf: verified.appendingPathComponent("prompts.json")))
                if manifest.formatVersion == 2 {
                    _ = try ImpressCalibrationLocalStore.validateArchiveData(
                        Data(contentsOf: verified.appendingPathComponent("checkins-v1.json")))
                }
            }.value
            try FileManager.default.moveItem(at: verified, to: pending)
        } catch {
            try? FileManager.default.removeItem(at: verified)
            throw error
        }
    }

    /// Execute before V3 Repository initializes on the NEXT cold start.
    /// Restore is never allowed to replace an open WCDB pool.
    static func applyPendingAtColdLaunch() throws {
        let root = try supportDirectory()
        let pending = root.appendingPathComponent("ImpressV3PendingRestore")
        guard FileManager.default.fileExists(atPath: pending.path) else { return }
        let manifest = try JSONDecoder().decode(ImpressV3BackupManifest.self,
            from: Data(contentsOf: pending.appendingPathComponent("manifest.json")))
        let records = try manifest.files.map {
            try ImpressV3BackupArchive.inspectFile(
                pending.appendingPathComponent($0.name), name: $0.name).0
        }
        try manifest.validate(records)
        try ImpressV3BackupArchive.verifySQLite(
            pending.appendingPathComponent("ReviewV3.sqlite"))
        _ = try JSONDecoder().decode([ImpressV3LearningEntry].self,
            from: Data(contentsOf: pending.appendingPathComponent("LearningEntry-v1.json")))
        let restoredPrompts = try JSONDecoder().decode(
            [ImpressV3PromptTemplate].self,
            from: Data(contentsOf: pending.appendingPathComponent("prompts.json")))
        let restoredCalibration: Data?
        if manifest.formatVersion == 2 {
            let bytes = try Data(contentsOf: pending.appendingPathComponent("checkins-v1.json"))
            _ = try ImpressCalibrationLocalStore.validateArchiveData(bytes)
            restoredCalibration = bytes
        } else {
            // A V1 backup never had calibration; retain local V3.2 history.
            restoredCalibration = nil
        }
        let oldPromptData = UserDefaults.standard.data(
            forKey: ImpressV3PromptLibrary.storageKey)
        let liveFolder = FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ImpressV3", isDirectory: true)
        try FileManager.default.createDirectory(
            at: liveFolder, withIntermediateDirectories: true)
        let current = liveFolder.appendingPathComponent("ReviewV3.sqlite")
        let previous = root.appendingPathComponent(
            "ImpressV3PreRestore-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: previous, withIntermediateDirectories: true)
        let fileManager = FileManager.default
        let journalFolder = root.appendingPathComponent("ImpressV3", isDirectory: true)
        let journal = journalFolder.appendingPathComponent("LearningEntry-v1.json")
        let calibration = ImpressCalibrationLocalStore.canonicalURL()
        let previousCalibration = previous.appendingPathComponent("checkins-v1.json")
        var touchedCalibration = false
        var installedDB = false
        do {
            for suffix in ["", "-wal", "-shm"] {
                let priorFile = URL(fileURLWithPath: current.path + suffix)
                if fileManager.fileExists(atPath: priorFile.path) {
                    try fileManager.moveItem(at: priorFile, to: previous.appendingPathComponent(
                        priorFile.lastPathComponent))
                }
            }
            try fileManager.copyItem(
                at: pending.appendingPathComponent("ReviewV3.sqlite"), to: current)
            installedDB = true
            try fileManager.createDirectory(at: journalFolder,
                withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: journal.path) {
                try fileManager.copyItem(at: journal,
                    to: previous.appendingPathComponent("LearningEntry-v1.json"))
                try fileManager.removeItem(at: journal)
            }
            try fileManager.copyItem(at: pending.appendingPathComponent(
                "LearningEntry-v1.json"), to: journal)
            try ImpressV3PromptLibrary.save(restoredPrompts)
            if let restoredCalibration {
                try fileManager.createDirectory(
                    at: calibration.deletingLastPathComponent(),
                    withIntermediateDirectories: true)
                touchedCalibration = true
                if fileManager.fileExists(atPath: calibration.path) {
                    try fileManager.moveItem(at: calibration, to: previousCalibration)
                }
                try restoredCalibration.write(to: calibration, options: .atomic)
                _ = try ImpressCalibrationLocalStore.validateArchiveData(
                    Data(contentsOf: calibration))
            }
            // Moving staging away atomically prevents unintended repeat
            // recovery when temporary cleanup fails.
            let applied = root.appendingPathComponent(
                "ImpressV3Applied-" + UUID().uuidString, isDirectory: true)
            try fileManager.moveItem(at: pending, to: applied)
            try? fileManager.removeItem(at: applied)
            markDataChanged()
            // The previous live database remains available as an emergency
            // rollback folder, without any automatic deletion of user data.
        } catch {
            if touchedCalibration {
                if fileManager.fileExists(atPath: calibration.path) {
                    try? fileManager.removeItem(at: calibration)
                }
                if fileManager.fileExists(atPath: previousCalibration.path) {
                    try? fileManager.moveItem(at: previousCalibration, to: calibration)
                }
            }
            if installedDB { try? fileManager.removeItem(at: current) }
            let previousJournal = previous.appendingPathComponent("LearningEntry-v1.json")
            if fileManager.fileExists(atPath: previousJournal.path) {
                if fileManager.fileExists(atPath: journal.path) {
                    try? fileManager.removeItem(at: journal)
                }
                try? fileManager.copyItem(at: previousJournal, to: journal)
            } else if installedDB {
                try? fileManager.removeItem(at: journal)
            }
            if let oldPromptData {
                UserDefaults.standard.set(oldPromptData,
                    forKey: ImpressV3PromptLibrary.storageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: ImpressV3PromptLibrary.storageKey)
            }
            for suffix in ["", "-wal", "-shm"] {
                let path = URL(fileURLWithPath: current.path + suffix)
                let old = previous.appendingPathComponent(path.lastPathComponent)
                if fileManager.fileExists(atPath: old.path) {
                    if fileManager.fileExists(atPath: path.path) {
                        try? fileManager.removeItem(at: path)
                    }
                    try? fileManager.moveItem(at: old, to: path)
                }
            }
            throw error
        }
    }
}
