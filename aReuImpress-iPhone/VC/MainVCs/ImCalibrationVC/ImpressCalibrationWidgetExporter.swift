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
            else { return false }
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
