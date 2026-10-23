import XCTest

/// Actual Debug Simulator input/stream/scroll/stop, using synthetic text only.
final class ImpressChatPOCInteractionUITests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testOfflineChatRendererSendStreamHistoryAndStop() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressChatPOC", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        let transcript = app.collectionViews["impress.chat.poc.transcript"]
        XCTAssertTrue(transcript.waitForExistence(timeout: 30))
        let input = app.textViews["impress.chat.poc.input"]
        XCTAssertTrue(input.exists)
        input.tap()
        input.typeText("Explain incremental blocks")
        let control = app.buttons["impress.chat.poc.send-stop"]
        control.tap()
        XCTAssertTrue(transcript.cells.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["impress.chat.poc.send-stop"].waitForExistence(timeout: 10))
        transcript.swipeDown()
        control.tap() // While the long offline fixture is still streaming.
        XCTAssertEqual(control.label, "重新生成",
                       "A stopped answer must be retained and explicitly retryable")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "chat-poc-after-stop"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(transcript.exists)
    }    
    func testStopRetainsPartialAndAllowsExplicitRegeneration() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressChatPOC", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        let input = app.textViews["impress.chat.poc.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 25))
        input.tap()
        input.typeText("Retry scenario")
        let action = app.buttons["impress.chat.poc.send-stop"]
        action.tap()
        XCTAssertTrue(action.waitForExistence(timeout: 10))
        action.tap()
        XCTAssertEqual(action.label, "重新生成")
        action.tap()
        XCTAssertEqual(action.label, "停止生成")
    }

    func testFullOfflineSSEReplayMustReachExplicitCompletion() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressChatPOC", "-AppleLanguages", "(zh-Hans)"]
        app.launch()
        let input = app.textViews["impress.chat.poc.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 25))
        input.tap()
        input.typeText("Explain")
        let control = app.buttons["impress.chat.poc.send-stop"]
        control.tap()
        XCTAssertTrue(app.textViews.matching(
            NSPredicate(format: "label CONTAINS %@", "已完成")).firstMatch
            .waitForExistence(timeout: 60),
                      "A successful full stream needs an actual SSE terminal")
        XCTAssertEqual(control.label, "发送")
        XCTAssertTrue(app.collectionViews["impress.chat.poc.transcript"].exists)
    }
}
