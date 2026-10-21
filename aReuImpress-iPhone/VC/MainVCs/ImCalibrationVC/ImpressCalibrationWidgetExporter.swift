import Foundation
import WidgetKit
import ImpressReviewCore

/// One-way, privacy-reduced export. The app retains sole write authority over checkins-v1.json.
enum ImpressCalibrationWidgetExporter {
    static let groupID = "group.areu.impress"
    static let snapshotName = "calibration-widget-v1.json"
    static let kinds = ["impress.calibration.week",
                        "impress.calibration.month",
                        "impress.calibration.year"]

    static func publishFromAuthoritativeStore() async {
        do {
            // history() reads the validated source ledger. Never use the lossy score-only trend.
            let entries = try await ImpressCalibrationLocalStore.shared.history()
            let snapshot = CalibrationWidgetProjection.snapshot(
                from: entries, at: Date(), calendar: Calendar.current)
            guard snapshot.isValid,
                  let root = FileManager.default.containerURL(
                      forSecurityApplicationGroupIdentifier: groupID) else {
                // App Group can be unavailable with an unsigned / free-provisioned installation.
                // That is a capability limitation, not permission to write outside the sandbox.
                return
            }
            try FileManager.default.createDirectory(
                at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent(snapshotName)
            let data = try JSONEncoder().encode(snapshot)
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path)
            // Never report the update as published until an equal, validated read-back.
            let actual = try JSONDecoder().decode(
                CalibrationWidgetSnapshot.self, from: Data(contentsOf: url))
            guard actual == snapshot && actual.isValid else {
                throw CocoaError(.fileReadCorruptFile)
            }
            for kind in kinds {
                WidgetCenter.shared.reloadTimelines(ofKind: kind)
            }
        } catch {
            // Main calibration save/restore stays durable even if widget capability is absent.
            NSLog("Calibration widget projection unavailable: %@", error.localizedDescription)
        }
    }
}
