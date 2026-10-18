import XCTest
import UIKit
import UserNotifications
import ImpressReviewCore
@testable import aReuImpress_iPhone

final class ImpressCalibrationIntegrationTests: XCTestCase {
    @MainActor
    func testCalibrationIsDedicatedTabAlongsideFlashcardNotesShortcut() {
        let root = ImTabBarViewController()
        root.loadViewIfNeeded()
        let tabs = root.viewControllers ?? []
        XCTAssertEqual(tabs.count, 3)
        XCTAssertEqual(tabs.compactMap { $0.tabBarItem.title },
                       ["闪卡", "校准", "设置"])
        XCTAssertEqual(tabs.compactMap { ($0 as? UINavigationController)?.viewControllers.first }
                              .compactMap { $0 as? ImpressCalibrationViewController }.count, 1)
        XCTAssertTrue((tabs[0] as? UINavigationController)?.viewControllers.first
                      is ImpressV3ReviewViewController)
        XCTAssertTrue((tabs[2] as? UINavigationController)?.viewControllers.first
                      is ImpressV3SettingsHubViewController)
        let review = (tabs[0] as? UINavigationController)?.viewControllers.first
            as? ImpressV3ReviewViewController
        review?.loadViewIfNeeded()
        XCTAssertEqual(Set(review?.navigationItem.rightBarButtonItems?
            .compactMap(\.accessibilityLabel) ?? []), Set(["笔记", "卡片集"]))
    }

    @MainActor
    func testFlashcardNotesBarActionPushesReadOnlyVaultScreenWithoutNewTab() throws {
        let tabs = ImTabBarViewController()
        tabs.loadViewIfNeeded()
        let navigation = try XCTUnwrap(tabs.viewControllers?[0] as? UINavigationController)
        let review = try XCTUnwrap(navigation.viewControllers.first
            as? ImpressV3ReviewViewController)
        review.loadViewIfNeeded()
        let actions = review.navigationItem.rightBarButtonItems ?? []
        XCTAssertEqual(actions.count, 2)
        let notes = try XCTUnwrap(actions.first(where: {
            $0.accessibilityIdentifier == "impress.review.notes"
        }))
        let collection = try XCTUnwrap(actions.first(where: {
            $0.accessibilityIdentifier == "impress.review.card-collection"
        }))
        XCTAssertEqual(notes.title, "笔记")
        XCTAssertEqual(collection.accessibilityLabel, "卡片集")
        XCTAssertNotEqual(notes.action, collection.action)
        let selector = try XCTUnwrap(notes.action)
        XCTAssertTrue(UIApplication.shared.sendAction(
            selector, to: notes.target, from: notes, for: nil))
        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertTrue(navigation.topViewController is ImpressNoteListTableViewController)
        XCTAssertEqual(tabs.viewControllers?.count, 3)
        XCTAssertTrue(navigation.viewControllers.first === review)
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
        let original = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(original.outcome(for: .sleep), .completed)
        try await store.setGoals(CalibrationGoals(custom: "新的自定义目标"))
        let reload = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(reload.goalsSnapshot.custom, first.goalsSnapshot.custom)
        let all = try await store.history()
        XCTAssertEqual(all.count, 1)
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
