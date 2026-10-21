import Foundation
import WidgetKit
import ImpressReviewCore

/// A strictly one-way, privacy-reduced status export.
/// Only the canonical App actor writes checkins-v1.json; WidgetKit reads a derivative cache.
enum ImpressCalibrationWidgetExporter {
    static let groupID = "group.areu.impress"
    static let snapshotName = "calibration-widget-v1.json"
    static let kinds = ["impress.calibration.week",
                        "impress.calibration.month",
                        "impress.calibration.year"]
    private static let publisher = SnapshotPublisher()

    enum Availability: Equatable {
        case ready, missingAppGroup, missingSnapshot, invalidSnapshot
    }

    /// Shared App Group is a signing entitlement, not a mere source-code flag.
    /// An unsigned / improperly re-signed app cannot repair this in Swift.
    static func availability() -> Availability {
        guard let root = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupID) else { return .missingAppGroup }
        guard let bytes = try? Data(contentsOf: root.appendingPathComponent(snapshotName))
        else { return .missingSnapshot }
        guard let snapshot = try? JSONDecoder().decode(CalibrationWidgetSnapshot.self, from: bytes),
              CalibrationWidgetProjection.overview(from: snapshot, at: Date(),
                calendar: Calendar.current) != nil else { return .invalidSnapshot }
        return .ready
    }

    static func publishFromAuthoritativeStore() async {
        do {
            let entries = try await ImpressCalibrationLocalStore.shared.history()
            let snapshot = CalibrationWidgetProjection.snapshot(
                from: entries, at: Date(), calendar: Calendar.current)
            guard snapshot.isValid else { return }
            // Serialize the shared-file check and atomic write across coalesced App updates;
            // a slow older publish must never overwrite a newer validated snapshot.
            if try await publisher.publishIfNewer(snapshot) {
                for kind in kinds { WidgetCenter.shared.reloadTimelines(ofKind: kind) }
            }
        } catch {
            // App data is already durably saved. An absent App Group on an unsigned
            // or free-profile install cannot grant Widget write access to the source.
            NSLog("Calibration widget projection unavailable: %@", error.localizedDescription)
        }
    }

    /// Serializes all producer tasks in this process, without touching the source ledger.
    private actor SnapshotPublisher {
        func publishIfNewer(_ snapshot: CalibrationWidgetSnapshot) throws -> Bool {
            guard let root = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: ImpressCalibrationWidgetExporter.groupID)
            else {
                throw NSError(domain: "ImpressWidgetAppGroup", code: 1,
                    userInfo: [NSLocalizedDescriptionKey:
                        "App Group group.areu.impress is unavailable to this signed process"])
            }
            try FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent(
                ImpressCalibrationWidgetExporter.snapshotName)
            if let oldBytes = try? Data(contentsOf: url),
               let prior = try? JSONDecoder().decode(
                   CalibrationWidgetSnapshot.self, from: oldBytes),
               prior.isValid,
               prior.generatedAt > snapshot.generatedAt {
                return false
            }
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path)
            let checked = try JSONDecoder().decode(
                CalibrationWidgetSnapshot.self, from: Data(contentsOf: url))
            guard checked == snapshot && checked.isValid else {
                throw CocoaError(.fileReadCorruptFile)
            }
            return true
        }
    }
}
