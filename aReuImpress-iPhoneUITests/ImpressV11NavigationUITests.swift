import XCTest

/// Real-process XCUITest, not controller instantiation or a service-level
/// contract. Uses only accessibility events against the running Simulator app.
/// This establishes the UI test target and navigation smoke evidence; it does
/// NOT claim the separate 18-step Vault/Chat/duplex end-to-end matrix passes.
final class ImpressV11NavigationUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testFourPrimaryDestinationsAndColdRestart() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)",
                                "-AppleLocale", "zh_CN"]
        app.launch()
        try validateNativeTabNavigation(in: app, capture: true)

        // Exercise an actual termination/relaunch boundary through SpringBoard.
        // This catches stale tab routing and startup failures in the real app.
        app.terminate()
        app.launch()
        try validateNativeTabNavigation(in: app, capture: false)
    }

    /// Real UIKit navigation from a disposable Vault into an offline diagram,
    /// a user-selected node, full source preview and the normal Chat screen.
    /// No fake completion button, repository shortcut or network model call.
    func testTemporaryVaultDiagramToChatWithColdLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressV11SyntheticVault",
                                "-AppleLanguages", "(zh-Hans)"]
        app.launchEnvironment["IMPRESS_V11_FIXTURE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 1).tap()
        let folder = app.cells.matching(identifier: "impress.notes.folder-row")
            .matching(NSPredicate(format: "label == %@", "Study")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 30))
        folder.tap()
        let note = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", "Graph")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        note.tap()
        XCTAssertTrue(app.staticTexts["impress.notes.source-path"]
            .waitForExistence(timeout: 15))
        app.buttons["更多笔记操作"].tap()
        let action = app.buttons["阅读 Mermaid 图形"]
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertTrue(app.webViews["impress.diagram.offline-graph"]
            .waitForExistence(timeout: 20))
        let renderState = app.staticTexts["impress.diagram.render-state"]
        XCTAssertTrue(renderState.waitForExistence(timeout: 20))
        let rendered = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready"),
            object: renderState)
        XCTAssertEqual(XCTWaiter.wait(for: [rendered], timeout: 30), .completed,
            "An actual offline Mermaid SVG must render, not merely a WKWebView shell")
        let options = app.tables["impress.diagram.source-selection"]
        XCTAssertTrue(options.waitForExistence(timeout: 15))
        XCTAssertGreaterThan(options.cells.count, 0)
        options.cells.element(boundBy: 0).tap()
        let preview = app.buttons["impress.diagram.preview-material"]
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(preview.isEnabled)
        preview.tap()
        XCTAssertTrue(app.textViews["impress.diagram.material-preview"]
            .waitForExistence(timeout: 15))
        app.buttons["impress.diagram.confirm-material"].tap()
        let input = app.textViews["impress.ai.chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        let introduction = app.alerts["关于讨论"]
        if introduction.waitForExistence(timeout: 3) {
            introduction.buttons["知道了"].tap()
        }
        input.tap()
        input.typeText("Please explain the approved Mermaid branch.")
        let send = app.buttons["impress.ai.chat.send"]
        XCTAssertTrue(send.isEnabled)
        send.tap()
        let scope = app.alerts["是否附带当前笔记材料？"]
        if scope.waitForExistence(timeout: 10) {
            scope.buttons["附带本次笔记材料"].tap()
        }
        let assistant = app.textViews.matching(
            identifier: "impress.ai.chat.message-body").matching(
                NSPredicate(format: "value CONTAINS %@", "合成模型回复")).firstMatch
        XCTAssertTrue(assistant.waitForExistence(timeout: 30),
            "The isolated synthetic provider must persist a real completed Chat message")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Impress-V1.1-Scoped-Diagram-Chat"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(folder.waitForExistence(timeout: 20))
    }

    /// Candidate review and WCDB card creation happen through genuine UI
    /// controls, with an explicit fixed synthetic provider for this fixture.
    func testSyntheticQuestionPoolReviewAndNativeFlashcard() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressV11SyntheticVault",
                                "-AppleLanguages", "(zh-Hans)"]
        app.launchEnvironment["IMPRESS_V11_FIXTURE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 1).tap()
        let folder = app.cells.matching(identifier: "impress.notes.folder-row")
            .matching(NSPredicate(format: "label == %@", "Study")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 30))
        folder.tap()
        let note = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", "Impress_E2E_Proof")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 15))
        note.tap()
        app.buttons["更多笔记操作"].tap()
        app.buttons["根据笔记生成卡片"].tap()
        XCTAssertTrue(app.navigationBars["生成综合问题"].waitForExistence(timeout: 15))
        app.navigationBars.buttons["生成"].tap()
        let consent = app.alerts["模拟器合成出题"]
        XCTAssertTrue(consent.waitForExistence(timeout: 10))
        consent.buttons["生成"].tap()
        XCTAssertTrue(app.navigationBars["问题候选池"].waitForExistence(timeout: 20))
        let candidates = app.tables.cells
        XCTAssertGreaterThanOrEqual(candidates.count, 2)
        candidates.element(boundBy: 1).tap()  // exclude the unwanted candidate
        let importButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "加入")).firstMatch
        XCTAssertTrue(importButton.isEnabled)
        importButton.tap()
        let approval = app.alerts["加入卡片集？"]
        XCTAssertTrue(approval.waitForExistence(timeout: 10))
        approval.buttons["确认加入"].tap()
        let done = app.alerts["卡片已添加"]
        XCTAssertTrue(done.waitForExistence(timeout: 20))
        done.buttons["完成"].tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Impress-V1.1-Real-Reviewed-Card"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
    }

    private func validateNativeTabNavigation(in app: XCUIApplication,
                                              capture: Bool) throws {
        let bar = app.tabBars.firstMatch
        XCTAssertTrue(bar.waitForExistence(timeout: 30),
            "App should show the native four-tab shell, not a database error")
        XCTAssertEqual(bar.buttons.count, 4,
            "The agreed primary tabs are Flashcard, Notes, Calibration and Settings")
        for index in 0..<4 {
            let destination = bar.buttons.element(boundBy: index)
            XCTAssertTrue(destination.isHittable, "Tab \(index) must be tappable")
            destination.tap()
            XCTAssertTrue(bar.exists, "Tab bar must remain visible after navigation")
            if capture {
                let screenshot = XCTAttachment(screenshot: app.screenshot())
                screenshot.name = "Impress-V1.1-primary-tab-\(index)"
                screenshot.lifetime = .keepAlways
                add(screenshot)
            }
        }
    }
}
