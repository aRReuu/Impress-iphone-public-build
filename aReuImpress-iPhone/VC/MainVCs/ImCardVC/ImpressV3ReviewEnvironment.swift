import Foundation

/// Staged V3 switch. Legacy UI stays the default until the V3 UI and
/// notifications pass simulator and device acceptance. No legacy DB migration.
enum ImpressV3ReviewEnvironment {
    private static let enabledKey = "ImpressV3ReviewPilotEnabled"

    /// Release never silently inherits a persisted Debug pilot switch.
    /// Do not open the V3 default entry until device acceptance completes.
    static var pilotEnabled: Bool {
        get {
            #if DEBUG
            #if IMPRESS_V3_CANDIDATE
            // Unsigned iPhone candidate IPA should launch directly into
            // V3.1 on a fresh installation. An explicitly saved user choice
            // still wins, and Release remains legacy until acceptance.
            return (UserDefaults.standard.object(forKey: enabledKey) as? Bool) ?? true
            #else
            return UserDefaults.standard.bool(forKey: enabledKey)
            #endif
            #else
            return false
            #endif
        }
        set {
            #if DEBUG
            UserDefaults.standard.set(newValue, forKey: enabledKey)
            #endif
        }
    }

    static let databaseResult: Result<ReviewWCDBRepository, Swift.Error> = Result {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let path = root.appendingPathComponent("ImpressV3/ReviewV3.sqlite").path
        return try ReviewWCDBRepository(databasePath: path, calculator: FSRS6ReviewCalculator())
    }

    static func repository() throws -> ReviewWCDBRepository {
        try databaseResult.get()
    }
}
