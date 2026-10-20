import XCTest
import UIKit
import UserNotifications
import ImpressReviewCore
@testable import aReuImpress_iPhone

final class ImpressCalibrationIntegrationTests: XCTestCase {
    @MainActor
    func testFourTabsOpenExistingCalibrationWithoutRewritingScores() throws {
        let root = ImTabBarViewController()
        root.loadViewIfNeeded()
        let tabs = try XCTUnwrap(root.viewControllers)
        XCTAssertEqual(tabs.count, 4)
        XCTAssertEqual(tabs.compactMap { $0.tabBarItem.title },
                       ["闪卡", "笔记", "校准器", "设置"])
        XCTAssertTrue((tabs[0] as? UINavigationController)?.viewControllers.first
                      is ImpressV3ReviewViewController)
        XCTAssertTrue((tabs[1] as? UINavigationController)?.viewControllers.first
                      is ImpressNoteListTableViewController)
        XCTAssertTrue((tabs[2] as? UINavigationController)?.viewControllers.first
                      is ImpressCalibrationViewController)
        XCTAssertTrue((tabs[3] as? UINavigationController)?.viewControllers.first
                      is ImpressV3SettingsHubViewController)
        let review = try XCTUnwrap((tabs[0] as? UINavigationController)?
            .viewControllers.first as? ImpressV3ReviewViewController)
        review.loadViewIfNeeded()
        XCTAssertEqual(review.navigationItem.leftBarButtonItem?.accessibilityLabel,
                       "新增卡片")
        XCTAssertEqual(review.navigationItem.rightBarButtonItems?
            .compactMap(\.accessibilityIdentifier), ["impress.review.card-collection"])
        XCTAssertFalse(review.navigationItem.rightBarButtonItems?
            .contains(where: { $0.accessibilityIdentifier == "impress.review.notes" }) ?? true)
    }

    @MainActor
    func testNotesKeepsOwnNativeRootAndReviewNavigation() throws {
        let tabs = ImTabBarViewController()
        tabs.loadViewIfNeeded()
        let cardNav = try XCTUnwrap(tabs.viewControllers?[0] as? UINavigationController)
        let notesNav = try XCTUnwrap(tabs.viewControllers?[1] as? UINavigationController)
        let review = try XCTUnwrap(cardNav.viewControllers.first as? ImpressV3ReviewViewController)
        let notes = try XCTUnwrap(notesNav.viewControllers.first as? ImpressNoteListTableViewController)
        review.loadViewIfNeeded()
        notes.loadViewIfNeeded()
        XCTAssertEqual(tabs.viewControllers?.count, 4)
        XCTAssertEqual(cardNav.viewControllers.count, 1)
        XCTAssertEqual(notesNav.viewControllers.count, 1)
    }

    @MainActor
    func testCalibrationNotificationRoutesToPrimaryCalibration() throws {
        let tab = ImTabBarViewController()
        tab.loadViewIfNeeded()
        let inbox = ImpressCalibrationNotificationRouteInbox.shared
        inbox.enqueue()
        XCTAssertTrue(inbox.deliverIfPossible(in: tab))
        XCTAssertEqual(tab.selectedIndex, 2)
        let calibration = try XCTUnwrap(tab.viewControllers?[2] as? UINavigationController)
        XCTAssertTrue(calibration.viewControllers.first is ImpressCalibrationViewController)
        XCTAssertTrue(calibration.topViewController is ImpressCalibrationViewController)
        XCTAssertEqual(calibration.viewControllers.count, 1)
        XCTAssertFalse(inbox.pending)
        XCTAssertFalse(inbox.deliverIfPossible(in: tab))
    }

    @MainActor
    func testReviewExcludesLargeCalibrationChartAndSettingsRetainsDetailRoute() throws {
        let tabs = ImTabBarViewController()
        tabs.loadViewIfNeeded()
        let flashcardNav = try XCTUnwrap(tabs.viewControllers?[0] as? UINavigationController)
        let review = try XCTUnwrap(flashcardNav.viewControllers.first
                                   as? ImpressV3ReviewViewController)
        review.loadViewIfNeeded()
        XCTAssertNil(review.view.subviews.first {
            $0.accessibilityIdentifier == "impress.review.calibration-week"
        })
        XCTAssertEqual(flashcardNav.viewControllers.count, 1)
        let settingsNav = try XCTUnwrap(tabs.viewControllers?[3] as? UINavigationController)
        let settings = try XCTUnwrap(settingsNav.viewControllers.first
                                    as? ImpressV3SettingsHubViewController)
        settings.loadViewIfNeeded()
        settings.tableView(settings.tableView,
                           didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertTrue(settingsNav.topViewController is ImpressCalibrationViewController)
        XCTAssertTrue(flashcardNav.topViewController === review)
    }

    @MainActor
    func testSettingsDailyCalibrationUsesSameFullDetailClass() throws {
        let tabs = ImTabBarViewController()
        tabs.loadViewIfNeeded()
        let settingsNav = try XCTUnwrap(tabs.viewControllers?[3] as? UINavigationController)
        let hub = try XCTUnwrap(settingsNav.viewControllers.first
                                as? ImpressV3SettingsHubViewController)
        hub.loadViewIfNeeded()
        hub.tableView(hub.tableView,
                      didSelectRowAt: IndexPath(row: 0, section: 1))
        XCTAssertTrue(settingsNav.topViewController is ImpressCalibrationViewController)
        XCTAssertEqual(tabs.selectedIndex, 0) // no forced primary navigation
        XCTAssertTrue(settingsNav.viewControllers.first === hub)
    }

    @MainActor
    func testCalibrationEntryIsAvailableUnderLearningRhythm() throws {
        let tabs = ImTabBarViewController()
        tabs.loadViewIfNeeded()
        let settings = try XCTUnwrap(tabs.viewControllers?[3] as? UINavigationController)
        let hub = try XCTUnwrap(settings.viewControllers.first as? ImpressV3SettingsHubViewController)
        hub.loadViewIfNeeded()
        let cell = hub.tableView(hub.tableView,
                                 cellForRowAt: IndexPath(row: 0, section: 1))
        let title = (cell.contentConfiguration as? UIListContentConfiguration)?.text
        XCTAssertEqual(title, "每日校准")
    }

    func testStorePersistsDayGoalsAndNeverRewritesHistory() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("calibration-test-" + UUID().uuidString)
            .appendingPathComponent("private.json")
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let store = ImpressCalibrationLocalStore(storageURL: url)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let timestamp = calendar.date(from: DateComponents(year: 2025, month: 10, day: 18))!
        var first = try await store.checkIn(on: timestamp, calendar: calendar)
        try first.setOutcome(.completed, for: .sleep)
        try await store.save(first)
        let original = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(original.outcome(for: .sleep), .completed)
        try await store.setGoals(CalibrationGoals(custom: "新的自定义目标"))
        let reload = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(reload.goalsSnapshot.custom, first.goalsSnapshot.custom)
        XCTAssertEqual(reload.outcome(for: .sleep), .completed)
        let all = try await store.history()
        XCTAssertEqual(all.count, 1)
    }

    func testEditingOpenTodayResetsOnlyChangedGoalAssessments() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("calibration-edit-today-" + UUID().uuidString,
                                    isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let store = ImpressCalibrationLocalStore(
            storageURL: folder.appendingPathComponent("checkins.json"))
        let today = Date()
        var day = try await store.checkIn(on: today)
        try day.setOutcome(.completed, for: .sleep)
        try day.setOutcome(.missed, for: .custom)
        try await store.save(day)
        try await store.setGoals(CalibrationGoals(custom: "更新后需要重新确认的目标"))
        let updated = try await store.checkIn(on: today)
        XCTAssertEqual(updated.goalsSnapshot.custom, "更新后需要重新确认的目标")
        XCTAssertEqual(updated.outcome(for: .sleep), .completed,
                       "An unchanged confirmed goal must be retained")
        XCTAssertEqual(updated.outcome(for: .custom), .unrecorded,
                       "The changed goal must be reassessed")
        XCTAssertFalse(updated.isComplete)
        XCTAssertNil(try updated.finalizedScore().netScore)
        let history = try await store.history()
        XCTAssertEqual(history.count, 1)
    }

    func testCalibrationArchiveRoundTripAndCorruptionRejection() async throws {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("cal-archive-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let original = ImpressCalibrationLocalStore(
            storageURL: folder.appendingPathComponent("original.json"))
        var day = try await original.checkIn()
        for kind in CalibrationIndicator.behaviorIndicators {
            try day.setOutcome(.completed, for: kind)
        }
        try day.setMood(1)
        try day.setManualAdjustment(positive: false, reason: "额外自评")
        try await original.save(day)
        let bytes = try await original.archiveData()
        XCTAssertEqual(try ImpressCalibrationLocalStore.validateArchiveData(bytes), 1)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let restoredURL = folder.appendingPathComponent("restored.json")
        try bytes.write(to: restoredURL, options: .atomic)
        let restored = ImpressCalibrationLocalStore(storageURL: restoredURL)
        let all = try await restored.history()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(try all[0].finalizedScore().netScore, 3)
        XCTAssertThrowsError(try ImpressCalibrationLocalStore.validateArchiveData(
            Data("damaged".utf8)))
    }

}
