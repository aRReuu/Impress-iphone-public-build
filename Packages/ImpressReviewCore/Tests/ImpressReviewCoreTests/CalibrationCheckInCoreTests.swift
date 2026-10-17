import XCTest
@testable import ImpressReviewCore

final class CalibrationCheckInCoreTests: XCTestCase {
    private func newDay(_ day: String = "2026-10-18") throws -> CalibrationDayCheckIn {
        try CalibrationDayCheckIn(dayID: day, goals: CalibrationGoals())
    }

    func testFiveIndicatorsMustBeReviewedButMoodNeverPunished() throws {
        var review = try newDay()
        XCTAssertEqual(review.pendingIndicators.count, 5)
        for kind in CalibrationIndicator.behaviorIndicators {
            try review.setOutcome(.completed, for: kind)
        }
        XCTAssertEqual(review.pendingIndicators, [.mood])
        XCTAssertNil(try review.finalizedScore().netScore)
        try review.setMood(1) // Very bad day, yet no automatic penalty.
        XCTAssertTrue(review.isComplete)
        XCTAssertEqual(try review.finalizedScore().netScore, 4)
        try review.setMood(5)
        XCTAssertEqual(try review.finalizedScore().netScore, 4)
    }

    func testExplicitMoodSkipCountsAsEvaluatedNotFailure() throws {
        var review = try newDay()
        for kind in CalibrationIndicator.behaviorIndicators {
            try review.setOutcome(.excused, for: kind)
        }
        try review.setMood(nil, assessed: true)
        XCTAssertTrue(review.isComplete)
        XCTAssertNil(try review.finalizedScore().netScore) // No work scheduled is not zero.
    }

    func testUnrecordedDayCannotObtainAFinalScore() throws {
        var review = try newDay()
        try review.setOutcome(.completed, for: .sleep)
        try review.setMood(3)
        XCTAssertFalse(review.isComplete)
        XCTAssertNil(try review.finalizedScore().netScore)
        XCTAssertEqual(review.pendingIndicators.count, 3)
    }

    func testCustomGoalSnapshotAndFourTasksHaveStableIdentifiers() throws {
        let goal = CalibrationGoals(custom: "写下一个小步骤")
        var prior = try CalibrationDayCheckIn(dayID: "2026-10-17", goals: goal)
        try prior.setOutcome(.completed, for: .custom)
        XCTAssertEqual(prior.goalsSnapshot.custom, "写下一个小步骤")
        XCTAssertEqual(prior.outcome(for: .custom), .completed)
        XCTAssertEqual(Set(prior.assessments.map(\.taskID)).count, 4)
        XCTAssertNotEqual(prior.goalsSnapshot.custom, CalibrationGoals(custom: "新目标").custom)
    }

    func testBonusAndPenaltyRequireSpecificReasonAndRemainBounded() throws {
        var review = try newDay()
        for kind in CalibrationIndicator.behaviorIndicators {
            try review.setOutcome(.missed, for: kind)
        }
        try review.setMood(2)
        try review.setManualAdjustment(positive: true, reason: "  帮助别人解决问题 ")
        try review.setManualAdjustment(positive: false, reason: "多吃了不在计划内的零食")
        XCTAssertEqual(review.bonusNote, "帮助别人解决问题")
        XCTAssertEqual(try review.finalizedScore().netScore, -4) // -4 + 1 - 1
        try review.setManualAdjustment(positive: true, reason: nil)
        XCTAssertEqual(try review.finalizedScore().netScore, -5)
        XCTAssertThrowsError(try review.setManualAdjustment(
            positive: true, reason: String(repeating: "a", count: 121)))
    }

    func testReminderPlanStopsForDoneTodayButContinuesTomorrow() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let comps = DateComponents(timeZone: cal.timeZone, year: 2026, month: 10, day: 18, hour: 19, minute: 0)
        let now = cal.date(from: comps)!
        let today = CalibrationDayCheckIn.dayID(for: now, calendar: cal)
        let all = CalibrationReminderPlan.make(now: now, calendar: cal, horizonDays: 14)
        XCTAssertEqual(all.count, 28)
        XCTAssertEqual(all.filter { $0.dayID == today }.count, 2)
        let afterDone = CalibrationReminderPlan.make(now: now, calendar: cal,
                                                     completedDays: [today], horizonDays: 14)
        XCTAssertEqual(afterDone.count, 26)
        XCTAssertFalse(afterDone.contains(where: { $0.dayID == today }))
        XCTAssertEqual(afterDone.filter { $0.dayID == "2026-10-19" }.count, 2)
    }

    func testReminderPlanDoesNotScheduleExpiredTimesOrExceedCapacity() throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: 21))!
        let future = CalibrationReminderPlan.make(now: now, calendar: cal, horizonDays: 14)
        XCTAssertEqual(future.count, 27)
        XCTAssertTrue(future.allSatisfy { $0.fireAt > now })
        XCTAssertEqual(Set(future.map(\.identifier)).count, future.count)
        XCTAssertEqual(CalibrationReminderPlan.make(now: now, horizonDays: 100).count, 0)
        XCTAssertTrue(CalibrationReminderPlan.isManaged(future[0].identifier))
        XCTAssertFalse(CalibrationReminderPlan.isManaged("impress.v3.smart.123"))
    }

    func testChangingOpenDayGoalInvalidatesOnlyChangedItem() throws {
        var review = try newDay()
        try review.setOutcome(.completed, for: .sleep)
        try review.setOutcome(.missed, for: .custom)
        try review.replaceGoalsForOpenDay(
            CalibrationGoals(custom: "完成一次明确的个人计划"))
        XCTAssertEqual(review.outcome(for: .sleep), .completed)
        XCTAssertEqual(review.outcome(for: .custom), .unrecorded)
        XCTAssertFalse(review.isComplete)
        XCTAssertEqual(review.goalsSnapshot.custom, "完成一次明确的个人计划")
    }

    func testCompletedDayGoalSnapshotCannotBeRewritten() throws {
        var review = try newDay()
        for kind in CalibrationIndicator.behaviorIndicators {
            try review.setOutcome(.completed, for: kind)
        }
        try review.setMood(3)
        let previous = review.goalsSnapshot
        try review.replaceGoalsForOpenDay(
            CalibrationGoals(custom: "尝试覆盖历史目标"))
        XCTAssertEqual(review.goalsSnapshot, previous)
        XCTAssertEqual(try review.finalizedScore().netScore, 4)
    }

    func testInvalidMoodOrEmptyGoalsAreRejected() throws {
        var review = try newDay()
        XCTAssertThrowsError(try review.setMood(7))
        XCTAssertThrowsError(try review.setOutcome(.completed, for: .mood))
        XCTAssertThrowsError(try CalibrationDayCheckIn(dayID: "2026-10-18",
                            goals: CalibrationGoals(custom: "   ")))
    }
}
