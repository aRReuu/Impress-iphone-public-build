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

    func testPartialExplicitMissAndMoodSkipCountAsAssessmentsNotFailures() throws {
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
        XCTAssertEqual(view.weekDays[6].assessedCount, 1)
        XCTAssertEqual(view.weekDays[6].state, .partial)
        XCTAssertEqual(CalibrationWidgetOverview.assessedDays(view.weekDays), 2)
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
        XCTAssertEqual(view.weekDays.last?.assessedCount, 5)
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
}
