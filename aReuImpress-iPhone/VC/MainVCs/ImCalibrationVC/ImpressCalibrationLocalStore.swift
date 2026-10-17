import Foundation
import ImpressReviewCore

enum ImpressCalibrationStoreError: Error {
    case conflictingDaySnapshot
    case unsupportedVersion
    case durabilityFailure
}

/// Actor-backed, private, atomic JSON ledger. This never writes Obsidian or FSRS.
actor ImpressCalibrationLocalStore {
    static let shared = ImpressCalibrationLocalStore()

    private struct Ledger: Codable {
        var version: Int = 1
        var goals: CalibrationGoals = CalibrationGoals()
        var days: [String: CalibrationDayCheckIn] = [:]
    }

    private let storageURL: URL

    init(storageURL: URL? = nil) {
        if let storageURL {
            self.storageURL = storageURL
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                in: .userDomainMask).first!
            self.storageURL = base.appendingPathComponent("ImpressCalibration", isDirectory: true)
                                  .appendingPathComponent("checkins-v1.json")
        }
    }

    func goals() throws -> CalibrationGoals { try load().goals }

    func setGoals(_ value: CalibrationGoals) throws {
        try value.validate()
        var state = try load()
        state.goals = value
        let todayID = CalibrationDayCheckIn.dayID(for: Date(), calendar: Calendar.current)
        if var today = state.days[todayID], !today.isComplete {
            try today.replaceGoalsForOpenDay(value)
            state.days[todayID] = today
        }
        try persist(state)
    }

    /// Absence of a row is never interpreted as a failure. Draft created only in memory.
    func checkIn(on date: Date = Date(),
                 calendar: Calendar = .current) throws -> CalibrationDayCheckIn {
        let state = try load()
        let dayID = CalibrationDayCheckIn.dayID(for: date, calendar: calendar)
        return try state.days[dayID] ?? CalibrationDayCheckIn(dayID: dayID, goals: state.goals)
    }

    func save(_ checkIn: CalibrationDayCheckIn) throws {
        // Validation rejects malformed dates, duplicate outcomes, and invalid moods.
        _ = try checkIn.finalizedScore()
        var state = try load()
        if let old = state.days[checkIn.dayID],
           old.goalsSnapshot != checkIn.goalsSnapshot {
            throw ImpressCalibrationStoreError.conflictingDaySnapshot
        }
        state.days[checkIn.dayID] = checkIn
        try persist(state)
    }

    func completedDayIDs() throws -> Set<String> {
        Set(try load().days.values.filter { $0.isComplete }.map(\.dayID))
    }

    func history() throws -> [CalibrationDayCheckIn] {
        try load().days.values.sorted { $0.dayID < $1.dayID }
    }

    /// Non-finalized days must NOT acquire a numeric Y-value merely because
    /// their four behavior rows happened to be filled before mood was assessed.
    func trendRecords() throws -> [CalibrationDailyRecord] {
        try history().map { entry in
            if entry.isComplete { return entry.rawRecord }
            return CalibrationDailyRecord(
                dayID: entry.dayID,
                assessments: [CalibrationTaskAssessment(
                    taskID: "pending.checkin", outcome: .unrecorded)])
        }
    }

    private func load() throws -> Ledger {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return Ledger() }
        let data = try Data(contentsOf: storageURL)
        let state = try JSONDecoder().decode(Ledger.self, from: data)
        guard state.version == 1 else { throw ImpressCalibrationStoreError.unsupportedVersion }
        return state
    }

    private func persist(_ state: Ledger) throws {
        try FileManager.default.createDirectory(
            at: storageURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(state)
        try data.write(to: storageURL, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: storageURL.path)
        // Report a successful update only after a valid, equal round-trip.
        let verified = try JSONDecoder().decode(
            Ledger.self, from: Data(contentsOf: storageURL))
        guard verified.version == state.version,
              verified.goals == state.goals,
              verified.days == state.days else {
            throw ImpressCalibrationStoreError.durabilityFailure
        }
    }
}
