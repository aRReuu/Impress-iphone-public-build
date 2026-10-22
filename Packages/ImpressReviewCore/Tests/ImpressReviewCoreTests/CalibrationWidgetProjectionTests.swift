import Foundation
import XCTest
@testable import ImpressReviewCore

final class CalibrationWidgetProjectionTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func entry(_ key: String, outcome: CalibrationTaskOutcome? = nil,
                       allExcused: Bool = false, mood: Bool = false) throws -> CalibrationDayCheckIn {
        var value = try CalibrationDayCheckIn(dayID: key, goals: CalibrationGoals())
        if allExcused {
            for item in CalibrationIndicator.behaviorIndicators {
                try value.setOutcome(.excused, for: item)
            }
        } else if let outcome {
            try value.setOutcome(outcome, for: .sleep)
        }
        if mood { try value.setMood(nil, assessed: true) }
        return value
    }

    func testNoRecordsAreGapsAndCalendarWindowsIncludeToday() throws {
        let now = date(2024, 3, 1)
        let snapshot = CalibrationWidgetProjection.snapshot(from: [], at: now, calendar: calendar)
        XCTAssertTrue(snapshot.isValid)
        let view = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snapshot, at: now, calendar: calendar))
        XCTAssertEqual(view.weekDays.count, 7)
        XCTAssertEqual(view.weekDays.first?.dayID, "2024-02-24")
        XCTAssertEqual(view.weekDays.last?.dayID, "2024-03-01")
        XCTAssertEqual(view.monthDays.count, 30)
        XCTAssertEqual(view.monthDays.first?.dayID, "2024-02-01")
        XCTAssertEqual(view.yearMonths.count, 12)
        XCTAssertEqual(view.yearMonths[0].elapsedDays, 31)
        XCTAssertEqual(view.yearMonths[1].elapsedDays, 29)
        XCTAssertEqual(view.yearMonths[2].elapsedDays, 1)
        XCTAssertEqual(view.yearMonths[3].elapsedDays, 0)
        XCTAssertEqual(CalibrationWidgetOverview.assessedDays(view.weekDays), 0)
        XCTAssertTrue(view.weekDays.allSatisfy { $0.netScore == nil })
    }

    func testOnlyFourBehaviorInputsCountTowardsWidgetCoverage() throws {
        let now = date(2026, 10, 21)
        let partial = try entry("2026-10-20", outcome: .missed)
        let moodOnly = try entry("2026-10-21", mood: true)
        let snap = CalibrationWidgetProjection.snapshot(
            from: [partial, moodOnly], at: now, calendar: calendar)
        let view = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snap, at: now, calendar: calendar))
        XCTAssertEqual(view.weekDays[5].assessedCount, 1)
        XCTAssertEqual(view.weekDays[5].state, .partial)
        XCTAssertNil(view.weekDays[5].netScore)
        XCTAssertEqual(view.weekDays[6].assessedCount, 0)
        XCTAssertEqual(view.weekDays[6].state, .unrecorded)
        XCTAssertEqual(CalibrationWidgetOverview.assessedDays(view.weekDays), 1)
        XCTAssertEqual(CalibrationWidgetOverview.finalizedDays(view.weekDays), 0)
    }

    func testAllExcusedIsFinalizedWithoutInventingZeroScore() throws {
        let now = date(2026, 10, 21)
        let completed = try entry("2026-10-21", allExcused: true, mood: true)
        XCTAssertTrue(completed.isComplete)
        XCTAssertNil(try completed.finalizedScore().netScore)
        let snap = CalibrationWidgetProjection.snapshot(
            from: [completed], at: now, calendar: calendar)
        let view = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snap, at: now, calendar: calendar))
        XCTAssertEqual(view.weekDays.last?.state, .finalized)
        XCTAssertEqual(view.weekDays.last?.assessedCount, 4)
        XCTAssertNil(view.weekDays.last?.netScore)
        XCTAssertEqual(view.yearMonths[9].assessedDays, 1)
        XCTAssertEqual(view.yearMonths[9].finalizedDays, 1)
        XCTAssertEqual(view.yearMonths[10].elapsedDays, 0)
    }

    func testFutureRowsAndOldHistoryCannotFakeCurrentCoverage() throws {
        let now = date(2026, 1, 1)
        let future = try entry("2026-02-15", allExcused: true, mood: true)
        let prior = try entry("2025-12-31", outcome: .completed)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [future, prior], at: now, calendar: calendar)
        XCTAssertFalse(snapshot.days.contains { $0.dayID == "2026-02-15" })
        let view = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snapshot, at: now, calendar: calendar))
        XCTAssertEqual(view.weekDays[5].state, .partial)
        XCTAssertEqual(view.yearMonths[0].elapsedDays, 1)
        XCTAssertEqual(view.yearMonths[1].elapsedDays, 0)
    }

    func testInvalidSnapshotOrTimezoneMismatchSafelyRefusesDisplay() throws {
        let now = date(2026, 10, 21)
        let first = CalibrationWidgetProjection.snapshot(from: [
            try entry("2026-10-21", allExcused: true, mood: true)
        ], at: now, calendar: calendar)
        var changedZone = calendar
        changedZone.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertNil(CalibrationWidgetProjection.overview(
            from: first, at: now, calendar: changedZone))
        let corrupt = CalibrationWidgetSnapshot(
            schemaVersion: CalibrationWidgetSnapshot.currentVersion,
            generatedAt: first.generatedAt, timeZoneID: first.timeZoneID,
            calendarID: first.calendarID, days: first.days + first.days)
        XCTAssertFalse(corrupt.isValid)
        XCTAssertNil(CalibrationWidgetProjection.overview(
            from: corrupt, at: now, calendar: calendar))
    }

    func testPublishedSnapshotExcludesPrivateGoalTextAndReason() throws {
        let now = date(2026, 10, 21)
        let privateText = "DO-NOT-SHARE-PRIVATE-GOAL"
        let privateGoals = CalibrationGoals(sleep: privateText)
        var record = try CalibrationDayCheckIn(dayID: "2026-10-21", goals: privateGoals)
        try record.setOutcome(.completed, for: .sleep)
        try record.setManualAdjustment(positive: true, reason: "DO-NOT-SHARE-REASON")
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [record], at: now, calendar: calendar)
        let json = String(data: try JSONEncoder().encode(snapshot), encoding: .utf8)!
        XCTAssertFalse(json.contains(privateText))
        XCTAssertFalse(json.contains("DO-NOT-SHARE-REASON"))
        XCTAssertEqual(snapshot.days.first?.assessedCount, 1)
        XCTAssertNil(snapshot.days.first?.netScore)
    }
    func testDSTBoundariesUseConsecutiveCivilDays() throws {
        var local = Calendar(identifier: .gregorian)
        local.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = try XCTUnwrap(local.date(from: DateComponents(
            year: 2026, month: 3, day: 9, hour: 12)))
        let yesterday = try entry("2026-03-08", allExcused: true, mood: true)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [yesterday], at: now, calendar: local)
        let overview = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snapshot, at: now, calendar: local))
        XCTAssertEqual(overview.weekDays.map(\.dayID), [
            "2026-03-03", "2026-03-04", "2026-03-05", "2026-03-06",
            "2026-03-07", "2026-03-08", "2026-03-09"
        ])
        XCTAssertEqual(CalibrationWidgetOverview.finalizedDays(overview.weekDays), 1)
    }

    func testInvalidCivilDateInSharedSnapshotSafelyRejects() throws {
        let now = date(2026, 10, 21)
        let base = CalibrationWidgetProjection.snapshot(from: [], at: now, calendar: calendar)
        let fake = CalibrationWidgetDay(
            dayID: "2026-02-30", assessedCount: 5,
            state: .finalized, netScore: 1)
        let malformed = CalibrationWidgetSnapshot(
            schemaVersion: base.schemaVersion, generatedAt: base.generatedAt,
            timeZoneID: base.timeZoneID, calendarID: base.calendarID,
            days: [fake])
        XCTAssertFalse(malformed.isValid)
        XCTAssertNil(CalibrationWidgetProjection.overview(
            from: malformed, at: now, calendar: calendar))
    }


    func testCartesianWeekAndMonthUseRealScoresAndExactTrailingSevenCivilDays() throws {
        let now = date(2026, 10, 21)
        var positive = try entry("2026-10-20", allExcused: true, mood: true)
        try positive.setOutcome(.completed, for: .sleep)
        var negative = try entry("2026-10-21", allExcused: true, mood: true)
        try negative.setOutcome(.missed, for: .sleep)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [positive, negative], at: now, calendar: calendar)
        let week = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .week, at: now, calendar: calendar))
        XCTAssertEqual(week.values.count, 7)
        XCTAssertEqual(week.values[5], 1)
        XCTAssertEqual(week.values[6], -1)
        XCTAssertEqual(week.smooth[5], 1)
        XCTAssertEqual(week.smooth[6], 0, "0 is a real mean, not an invented missed-day score")
        XCTAssertNil(week.values[4])
        XCTAssertNil(week.smooth[4], "Blank dates must break both line segments")
        XCTAssertEqual(week.tickLabels[6], "10-21")

        let month = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .month, at: now, calendar: calendar))
        XCTAssertEqual(month.values.count, 30)
        XCTAssertEqual(month.values.suffix(2).compactMap { $0 }, [1, -1])
        XCTAssertNil(month.values[0])
    }

    func testCartesianYearUsesExistingMonthlyNetAverageAndThreeMonthMean() throws {
        let now = date(2026, 10, 21)
        var january = try entry("2026-01-15", allExcused: true, mood: true)
        try january.setOutcome(.completed, for: .sleep)
        var february = try entry("2026-02-15", allExcused: true, mood: true)
        try february.setOutcome(.missed, for: .sleep)
        let march = try entry("2026-03-15", allExcused: true, mood: true)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [january, february, march], at: now, calendar: calendar)
        let year = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .year, at: now, calendar: calendar))
        XCTAssertEqual(year.values.count, 12)
        XCTAssertEqual(year.values[0], 1)
        XCTAssertEqual(year.values[1], -1)
        XCTAssertEqual(year.smooth[0], 1)
        XCTAssertEqual(year.smooth[1], 0)
        XCTAssertNil(year.values[2], "All excused is assessed but not a numerical zero")
        XCTAssertNil(year.smooth[2])
        XCTAssertNil(year.values[11], "Future months are gaps, not recorded negatives")
        XCTAssertEqual(year.tickLabels.first, "1月")
    }

    func testPlausibleSharedSnapshotCannotDrawFutureCalendarScores() throws {
        let now = date(2026, 10, 21)
        let empty = CalibrationWidgetProjection.snapshot(from: [], at: now, calendar: calendar)
        // A malformed producer could leave structurally valid future scores
        // in shared cache; a Widget must not reveal them as completed history.
        let future = [
            CalibrationWidgetDay(dayID: "2026-10-22", assessedCount: 5,
                                 state: .finalized, netScore: 19),
            CalibrationWidgetDay(dayID: "2026-12-01", assessedCount: 5,
                                 state: .finalized, netScore: -4)
        ]
        let snapshot = CalibrationWidgetSnapshot(
            schemaVersion: empty.schemaVersion, generatedAt: empty.generatedAt,
            timeZoneID: empty.timeZoneID, calendarID: empty.calendarID,
            days: future)
        XCTAssertTrue(snapshot.isValid, "Date syntax alone cannot prove a past assessment")
        let year = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .year, at: now, calendar: calendar))
        XCTAssertNil(year.values[9], "Future days in the current month are invalid")
        XCTAssertNil(year.values[11], "Future months must be empty, not scored")
        XCTAssertNil(year.smooth[9])
        XCTAssertNil(year.smooth[11])
        let coverage = try XCTUnwrap(CalibrationWidgetProjection.overview(
            from: snapshot, at: now, calendar: calendar))
        XCTAssertEqual(coverage.yearMonths[9].assessedDays, 0)
        XCTAssertEqual(coverage.yearMonths[11].elapsedDays, 0)
    }

    func testCartesianEmptyAndInvalidSnapshotsNeverFabricateScorePoints() throws {
        let now = date(2026, 10, 21)
        let recordedWithoutScore = try entry("2026-10-21", allExcused: true, mood: true)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: [recordedWithoutScore], at: now, calendar: calendar)
        for period in CalibrationWidgetPeriod.allCases {
            let plot = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
                from: snapshot, period: period, at: now, calendar: calendar))
            XCTAssertTrue(plot.values.allSatisfy { $0 == nil })
            XCTAssertTrue(plot.smooth.allSatisfy { $0 == nil })
        }
        var invalidZone = calendar
        invalidZone.timeZone = TimeZone(secondsFromGMT: 3600)!
        XCTAssertNil(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .week, at: now, calendar: invalidZone))
    }

    func testCartesianMatchesExactAppScoreCoreDailyAndMonthlySeries() throws {
        let now = date(2026, 10, 21)
        var records = [CalibrationDayCheckIn]()
        var october19 = try entry("2026-10-19", allExcused: true, mood: true)
        try october19.setOutcome(.completed, for: .sleep)
        try october19.setManualAdjustment(positive: true, reason: "synthetic test")
        records.append(october19)
        let october20 = try entry("2026-10-20", outcome: .missed)
        records.append(october20)
        var october21 = try entry("2026-10-21", allExcused: true, mood: true)
        try october21.setOutcome(.missed, for: .exercise)
        records.append(october21)
        var september = try entry("2026-09-12", allExcused: true, mood: true)
        try september.setOutcome(.completed, for: .reading)
        records.append(september)
        let scoreRecords = records.map(\.rawRecord)
        let snapshot = CalibrationWidgetProjection.snapshot(
            from: records, at: now, calendar: calendar)

        let week = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .week, at: now, calendar: calendar))
        let coreWeek = try CalibrationScoreCore.dailyTrend(
            scoreRecords, from: "2026-10-15", through: "2026-10-21")
        XCTAssertEqual(week.values, coreWeek.map { $0.netScore.map(Double.init) })
        XCTAssertEqual(week.smooth, coreWeek.map(\.trailingSevenDayMean),
            "The widget must retain the App's exact gap-aware seven-day mean")

        let month = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .month, at: now, calendar: calendar))
        let coreMonth = try CalibrationScoreCore.dailyTrend(
            scoreRecords, from: "2026-09-22", through: "2026-10-21")
        XCTAssertEqual(month.values, coreMonth.map { $0.netScore.map(Double.init) })
        XCTAssertEqual(month.smooth, coreMonth.map(\.trailingSevenDayMean))

        let year = try XCTUnwrap(CalibrationWidgetProjection.cartesianPlot(
            from: snapshot, period: .year, at: now, calendar: calendar))
        let coreYear = try CalibrationScoreCore.monthlyTrend(scoreRecords, year: 2026)
        XCTAssertEqual(year.values, coreYear.map(\.averageDailyScore))
        let originalAppSmoothing: [Double?] = year.values.indices.map { index in
            guard year.values[index] != nil else { return nil }
            let recent = year.values[max(0, index - 2)...index].compactMap { $0 }
            return recent.reduce(0, +) / Double(recent.count)
        }
        XCTAssertEqual(year.smooth, originalAppSmoothing)
        XCTAssertEqual(CalibrationWidgetOverview.assessedDays(
            try XCTUnwrap(CalibrationWidgetProjection.overview(
                from: snapshot, at: now, calendar: calendar)).weekDays), 3,
            "B scheme assessment coverage must remain separate from scored points")
    }


}
