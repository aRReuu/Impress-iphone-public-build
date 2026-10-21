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
