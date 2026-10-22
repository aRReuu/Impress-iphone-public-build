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
        try await store.setGoals(CalibrationGoals(reading: "新的阅读目标"))
        let reload = try await store.checkIn(on: timestamp, calendar: calendar)
        XCTAssertEqual(reload.goalsSnapshot.reading, first.goalsSnapshot.reading)
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
        try day.setOutcome(.missed, for: .reading)
        try await store.save(day)
        try await store.setGoals(CalibrationGoals(reading: "更新后需要重新确认的阅读计划"))
        let updated = try await store.checkIn(on: today)
        XCTAssertEqual(updated.goalsSnapshot.reading, "更新后需要重新确认的阅读计划")
        XCTAssertEqual(updated.outcome(for: .sleep), .completed,
                       "An unchanged confirmed goal must be retained")
        XCTAssertEqual(updated.outcome(for: .reading), .unrecorded,
                       "The changed goal must be reassessed")
        XCTAssertFalse(updated.isComplete)
        XCTAssertNil(try updated.finalizedScore().netScore)
        let history = try await store.history()
        XCTAssertEqual(history.count, 1)
    }

    func testClosedDayRejectsDifferentLedgerWritesAndPreservesDurability() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("cal-closed-" + UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let ledger = ImpressCalibrationLocalStore(
            storageURL: directory.appendingPathComponent("ledger.json"))
        var day = try await ledger.checkIn()
        for kind in CalibrationIndicator.behaviorIndicators {
            try day.setOutcome(.completed, for: kind)
        }
        try day.setManualAdjustment(positive: true, reason: "计划外运动")
        try await ledger.save(day)
        XCTAssertTrue(day.isComplete)
        let before = try await ledger.archiveData()
        // Repeated button taps are truly idempotent, not a second write.
        try await ledger.save(day)
        let retriedBytes = try await ledger.archiveData()
        XCTAssertEqual(before, retriedBytes)

        var changed = day
        try changed.setOutcome(.missed, for: .reading)
        do {
            try await ledger.save(changed)
            XCTFail("CLOSED daily record must reject direct actor overwrite")
        } catch ImpressCalibrationStoreError.closedDayImmutable {
            // Expected.
        }
        var changedExtra = day
        try changedExtra.setManualAdjustment(positive: false, reason: "冲动修改")
        do {
            try await ledger.save(changedExtra)
            XCTFail("CLOSED extra score must be immutable")
        } catch ImpressCalibrationStoreError.closedDayImmutable {
            // Expected.
        }
        let finalBytes = try await ledger.archiveData()
        let finalHistory = try await ledger.history()
        XCTAssertEqual(before, finalBytes)
        XCTAssertEqual(finalHistory, [day])
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

    /// Both presentation hosts invoke exactly the same CoreGraphics painter.
    /// Snapshot parity is proven here; SpringBoard placement and device scale
    /// still require a separate WidgetKit/physical-device acceptance record.
    @MainActor
    func testCartesianRendererHasIdenticalUIKitAndWidgetImagePaths() throws {
        let size = CGSize(width: 168, height: 94)
        let values: [Double?] = [nil, 2, nil, -1, nil, 0, 1]
        let average: [Double?] = [nil, 2, nil, 0.5, nil, 0.3, 0.5]
        let dates = ["10-15", "10-16", "10-17", "10-18", "10-19", "10-20", "10-21"]
        let font = ImpressV3Appearance.Typography.micro
        let palette = CalibrationCartesianPalette(
            axis: ImpressV3Appearance.divider,
            secondary: ImpressV3Appearance.secondaryText,
            accent: ImpressV3Appearance.accent)
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            let widgetBitmap = CalibrationCartesianTrendRenderer.image(
                size: size, values: values, smooth: average,
                tickLabels: dates, palette: palette, font: font,
                traitCollection: traits)
            let nativeBitmap = UIGraphicsImageRenderer(size: size).image { canvas in
                CalibrationCartesianTrendRenderer.draw(
                    in: CGRect(origin: .zero, size: size),
                    context: canvas.cgContext,
                    values: values, smooth: average, tickLabels: dates,
                    palette: palette, font: font, traitCollection: traits)
            }
            XCTAssertEqual(widgetBitmap.size, nativeBitmap.size)
            XCTAssertEqual(widgetBitmap.pngData(), nativeBitmap.pngData(),
                "Identical render inputs must have identical pixel geometry")
            let emptyImage = CalibrationCartesianTrendRenderer.image(
                size: size, values: Array(repeating: nil, count: 7),
                smooth: Array(repeating: nil, count: 7),
                tickLabels: dates, palette: palette, font: font,
                traitCollection: traits)
            XCTAssertNotEqual(widgetBitmap.pngData(), emptyImage.pngData(),
                "A real scored point must be visible; missing points stay empty")
            let proof = XCTAttachment(image: widgetBitmap)
            proof.name = style == .light
                ? "Calibration-Shared-Cartesian-Light-168x94"
                : "Calibration-Shared-Cartesian-Dark-168x94"
            proof.lifetime = .keepAlways
            add(proof)
        }
    }



    /// CoreGraphics screenshot evidence, not physical SpringBoard Widget QA.
    /// Anchors lock the scale: a missing isolated point cannot hide behind
    /// a merely changed y-axis when comparing rendered bitmaps.
    @MainActor
    func testCartesianGappedMultiIsolatesAreVisibleInSixWidgetCanvases() throws {
        let cases: [(String, Int, CGSize)] = [
            ("week-small", 7, CGSize(width: 142, height: 76)),
            ("week-medium", 7, CGSize(width: 300, height: 104)),
            ("month-small", 30, CGSize(width: 142, height: 76)),
            ("month-medium", 30, CGSize(width: 300, height: 104)),
            ("year-small", 12, CGSize(width: 142, height: 76)),
            ("year-medium", 12, CGSize(width: 300, height: 104))
        ]
        for (name, count, size) in cases {
            var scores = Array<Double?>(repeating: nil, count: count)
            scores[1] = 2
            scores[count / 2] = -1
            scores[count - 2] = 1
            var means = Array<Double?>(repeating: nil, count: count)
            means[1] = 1
            means[count / 2] = 0.5
            means[count - 2] = 0
            let gaps = Array<Double?>(repeating: nil, count: count)
            var anchor = gaps
            anchor[0] = 2
            anchor[1] = 2
            let labels = (0..<count).map { String($0) }
            for style in [UIUserInterfaceStyle.light, .dark] {
                let traits = UITraitCollection(userInterfaceStyle: style)
                func render(_ values: [Double?], _ smooth: [Double?]) -> UIImage {
                    CalibrationCartesianTrendRenderer.image(
                        size: size, values: values, smooth: smooth,
                        tickLabels: labels, palette: .semantic,
                        font: UIFont.preferredFont(forTextStyle: .caption2),
                        traitCollection: traits)
                }
                let grayBaseline = render(gaps, anchor)
                let blueBaseline = render(anchor, gaps)
                let grayIsolates = render(scores, anchor)
                let blueIsolates = render(anchor, means)
                XCTAssertNotEqual(grayIsolates.pngData(), grayBaseline.pngData(),
                    "\(name): separated gray score points must be visible")
                XCTAssertNotEqual(blueIsolates.pngData(), blueBaseline.pngData(),
                    "\(name): separated blue mean points must be visible")
                let joined = render(scores, means)
                let native = UIGraphicsImageRenderer(size: size).image { canvas in
                    CalibrationCartesianTrendRenderer.draw(
                        in: CGRect(origin: .zero, size: size),
                        context: canvas.cgContext, values: scores, smooth: means,
                        tickLabels: labels, palette: .semantic,
                        font: UIFont.preferredFont(forTextStyle: .caption2),
                        traitCollection: traits)
                }
                XCTAssertEqual(joined.pngData(), native.pngData(),
                    "\(name): App and Widget must share pixel geometry")
                let proof = XCTAttachment(image: joined)
                proof.name = "Calibration-Cartesian-Canvas-\(name)-\(style == .dark ? "dark" : "light")"
                proof.lifetime = .keepAlways
                add(proof)
            }
        }
    }
}
