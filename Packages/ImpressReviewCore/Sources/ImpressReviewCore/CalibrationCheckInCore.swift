import Foundation

/// The five fixed indicators shown every day. Mood is observed, not scored.
public enum CalibrationIndicator: String, Codable, CaseIterable, Sendable {
    case sleep, exercise, nutrition, mood, custom
    public static let behaviorIndicators: [Self] = [.sleep, .exercise, .nutrition, .custom]
}

/// User-editable targets. The day's snapshot is preserved after any goal edit.
public struct CalibrationGoals: Codable, Equatable, Sendable {
    public var sleep: String
    public var exercise: String
    public var nutrition: String
    public var custom: String

    public init(sleep: String = "按自己制定的作息计划休息",
                exercise: String = "完成计划中的运动",
                nutrition: String = "遵守今天的饮食安排",
                custom: String = "完成今天的自定义目标") {
        self.sleep = sleep
        self.exercise = exercise
        self.nutrition = nutrition
        self.custom = custom
    }

    public func title(for kind: CalibrationIndicator) -> String {
        switch kind {
        case .sleep: return sleep
        case .exercise: return exercise
        case .nutrition: return nutrition
        case .custom: return custom
        case .mood: return "今日情绪（仅作观察）"
        }
    }

    public func validate() throws {
        for kind in CalibrationIndicator.behaviorIndicators
        where title(for: kind).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw CalibrationCheckInError.emptyGoal
        }
    }
}

public enum CalibrationCheckInError: Error, Equatable, Sendable {
    case invalidIndicator
    case invalidMood
    case emptyGoal
    case invalidManualNote
}

public struct CalibrationDayCheckIn: Codable, Equatable, Sendable {
    public let dayID: String
    public let goalsSnapshot: CalibrationGoals
    /// Four predetermined behavior assessments with stable IDs, even if the user renames goals.
    public private(set) var assessments: [CalibrationTaskAssessment]
    /// Explicit mood assessment is required to close the day, but never affects score.
    public private(set) var moodAssessed: Bool
    public private(set) var moodLevel: Int?
    /// Zero or one manual +1 / -1, each with a concrete reason.
    public private(set) var bonusNote: String?
    public private(set) var deductionNote: String?

    public init(dayID: String, goals: CalibrationGoals) throws {
        try goals.validate()
        self.dayID = dayID
        self.goalsSnapshot = goals
        self.assessments = CalibrationIndicator.behaviorIndicators.map {
            CalibrationTaskAssessment(taskID: $0.rawValue, outcome: .unrecorded)
        }
        self.moodAssessed = false
        self.moodLevel = nil
        self.bonusNote = nil
        self.deductionNote = nil
        _ = try CalibrationScoreCore.summarize(rawRecord)
    }

    public var pendingIndicators: [CalibrationIndicator] {
        var pending = CalibrationIndicator.behaviorIndicators.filter {
            outcome(for: $0) == .unrecorded
        }
        if !moodAssessed { pending.append(.mood) }
        return pending
    }

    public var isComplete: Bool { pendingIndicators.isEmpty }

    public func outcome(for kind: CalibrationIndicator) -> CalibrationTaskOutcome {
        assessments.first(where: { $0.taskID == kind.rawValue })?.outcome ?? .unrecorded
    }

    public mutating func setOutcome(_ outcome: CalibrationTaskOutcome,
                                    for kind: CalibrationIndicator) throws {
        guard kind != .mood,
              let index = assessments.firstIndex(where: { $0.taskID == kind.rawValue })
        else { throw CalibrationCheckInError.invalidIndicator }
        assessments[index] = CalibrationTaskAssessment(taskID: kind.rawValue, outcome: outcome)
    }

    /// nil with assessed=true is an explicit skip; assessed=false is still pending.
    public mutating func setMood(_ level: Int?, assessed: Bool = true) throws {
        if let level, !(1...5).contains(level) { throw CalibrationCheckInError.invalidMood }
        moodLevel = assessed ? level : nil
        moodAssessed = assessed
    }

    public mutating func setManualAdjustment(positive: Bool, reason: String?) throws {
        let trimmed = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmed, trimmed.count > 120 { throw CalibrationCheckInError.invalidManualNote }
        if positive { bonusNote = trimmed?.isEmpty == true ? nil : trimmed }
        else { deductionNote = trimmed?.isEmpty == true ? nil : trimmed }
    }

    public var rawRecord: CalibrationDailyRecord {
        var extra = [CalibrationExtraEvent]()
        if bonusNote != nil {
            extra.append(CalibrationExtraEvent(eventKey: "bonus.unscheduled",
                                               adjustment: .addOne))
        }
        if deductionNote != nil {
            extra.append(CalibrationExtraEvent(eventKey: "deduction.unscheduled",
                                               adjustment: .subtractOne))
        }
        return CalibrationDailyRecord(dayID: dayID, assessments: assessments,
                                      extraEvents: extra, moodLevel: moodLevel)
    }

    /// No total is published while even one of five indicators remains pending.
    /// Fully excused days are completed but may have no score; they are not failures.
    public func finalizedScore() throws -> CalibrationDailySummary {
        let summary = try CalibrationScoreCore.summarize(rawRecord)
        guard !isComplete else { return summary }
        return CalibrationDailySummary(dayID: dayID, netScore: nil,
                                       plannedCount: summary.plannedCount,
                                       completedCount: summary.completedCount,
                                       missedCount: summary.missedCount,
                                       unrecordedCount: summary.unrecordedCount,
                                       extraScore: summary.extraScore,
                                       taskBalance: nil, moodLevel: summary.moodLevel)
    }

    /// Common calendar is selected by the caller. No UTC day inference.
    public static func dayID(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}

/// Pure notification planning; iOS presentation and authorization happen in the app adapter.
/// At most 2 non-repeating alerts/day for 14 days (28 slots), leaving room for FSRS.
public struct CalibrationReminderSlot: Equatable, Sendable {
    public let identifier: String
    public let dayID: String
    public let fireAt: Date
}

public enum CalibrationReminderPlan {
    public static let identifierPrefix = "impress.calibration.v1."
    public static func isManaged(_ id: String) -> Bool { id.hasPrefix(identifierPrefix) }

    public static func make(now: Date, calendar: Calendar = .current,
                            completedDays: Set<String> = [], horizonDays: Int = 14,
                            hours: [Int] = [20, 22]) -> [CalibrationReminderSlot] {
        guard (1...28).contains(horizonDays), !hours.isEmpty,
              hours.allSatisfy({ (0...23).contains($0) }) else { return [] }
        let first = calendar.startOfDay(for: now)
        var result = [CalibrationReminderSlot]()
        for dayOffset in 0..<horizonDays {
            guard let start = calendar.date(byAdding: .day, value: dayOffset, to: first) else { continue }
            let key = CalibrationDayCheckIn.dayID(for: start, calendar: calendar)
            if completedDays.contains(key) { continue }
            for hour in hours.sorted() {
                guard let target = calendar.date(bySettingHour: hour, minute: 0,
                                                 second: 0, of: start),
                      target > now else { continue }
                let id = identifierPrefix + key + "." + String(format: "%02d", hour)
                result.append(CalibrationReminderSlot(identifier: id, dayID: key, fireAt: target))
            }
        }
        return result
    }
}
