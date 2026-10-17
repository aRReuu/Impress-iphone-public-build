import XCTest
import UIKit
import UserNotifications
import ImpressReviewCore
@testable import aReuImpress_iPhone

final class ImpressCalibrationIntegrationTests: XCTestCase {
    @MainActor
    func testCalibrationIsDedicatedTabWithoutReplacingExistingTabs() {
        let root = ImTabBarViewController()
        root.loadViewIfNeeded()
        let tabs = root.viewControllers ?? []
        XCTAssertEqual(tabs.count, 4)
        XCTAssertEqual(tabs.compactMap { ($0 as? UINavigationController)?.viewControllers.first }
                              .compactMap { $0 as? ImpressCalibrationViewController }.count, 1)
        XCTAssertTrue((tabs[0] as? UINavigationController)?.viewControllers.first
                      is ImpressV3ReviewViewController)
        XCTAssertTrue((tabs[2] as? UINavigationController)?.viewControllers.first
                      is ImpressNoteListTableViewController)
    }

    @MainActor
    func testCalibrationNotificationRoutesToExistingTab() {
        let tab = ImTabBarViewController()
        tab.loadViewIfNeeded()
        let inbox = ImpressCalibrationNotificationRouteInbox.shared
        inbox.enqueue()
        XCTAssertTrue(inbox.deliverIfPossible(in: tab))
        XCTAssertEqual(tab.selectedIndex, 1)
        XCTAssertFalse(inbox.pending)
        XCTAssertFalse(inbox.deliverIfPossible(in: tab))
    }

    func testStorePersistsDayGoalsAndNeverRewritesHistory() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("calibration-test-" + UUID().uuidString)
            .appendingPathComponent("private.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ImpressCalibrationLocalStore(storageURL: url)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let timestamp = calendar.date(from: DateComponents(year: 2026, month: 10, day: 18))!
        var first = try await store.checkIn(on: timestamp, calendar: calendar)
        try first.setOutcome(.completed, for: .sleep)
        try await store.save(first)
        await XCTAssertNoThrowAsync {
            let original = try await store.checkIn(on: timestamp, calendar: calendar)
            XCTAssertEqual(original.outcome(for: .sleep), .completed)
        }
        try await store.setGoals(CalibrationGoals(custom: "新的自定义目标"))
        let reload = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(reload.goalsSnapshot.custom, first.goalsSnapshot.custom)
        XCTAssertEqual(try await store.history().count, 1)
    }
}

// Lightweight async helper: exceptions become XCTest failures without global test fixtures.
private func XCTAssertNoThrowAsync(_ body: () async throws -> Void,
                                  file: StaticString = #filePath, line: UInt = #line) async {
    do { try await body() } catch { XCTFail("Unexpected error: \(error)", file: file, line: line) }
}
