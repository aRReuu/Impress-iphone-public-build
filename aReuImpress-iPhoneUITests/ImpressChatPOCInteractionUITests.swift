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
        XCTAssertEqual(control.label, "发送",
                       "Cancellation must immediately restore the Send state")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "chat-poc-after-stop"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(transcript.exists)
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
        XCTAssertTrue(app.staticTexts["已完成"].waitForExistence(timeout: 60),
                      "A successful full stream needs an actual SSE terminal")
        XCTAssertEqual(control.label, "发送")
        XCTAssertTrue(app.collectionViews["impress.chat.poc.transcript"].exists)
    }
}
