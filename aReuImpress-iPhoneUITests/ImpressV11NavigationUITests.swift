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

    /// Open the real installed app through its registered URL scheme. This
    /// tests the external WidgetKit tap route without a test-only navigation hook.
    func testWidgetWeekMonthYearDeepLinksReusePrimaryCalibrationController() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-AppleLanguages", "(zh-Hans)"]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 25))
        let periods: [(String, Int)] = [
            ("week", 0), ("month", 1), ("year", 2)
        ]
        for (key, segmentIndex) in periods {
            let url = try XCTUnwrap(URL(string: "impress://calibration/" + key))
            app.open(url)
            // Use the agreed four-Tab order, not localized title strings.
            let tab = app.tabBars.buttons.element(boundBy: 2)
            XCTAssertTrue(tab.waitForExistence(timeout: 20))
            XCTAssertTrue(tab.isSelected,
                "Widget link must navigate to existing calibration Tab for " + key)
            let selector = app.segmentedControls["impress.calibration.period"]
            XCTAssertTrue(selector.waitForExistence(timeout: 15))
            XCTAssertTrue(selector.buttons.element(boundBy: segmentIndex).isSelected,
                "Widget period identity must survive deep-link routing")
        }
    }

    /// U06/U07: actual visible folder disclosure, collapsed descendants and
    /// document-title projection. This is a real UIKit interaction in the
    /// disposable scoped Vault, not an inspector shortcut or service-only test.
    func testNativeVaultOutlineFoldAndDocumentTitleWithoutPathBanner() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressV11SyntheticVault",
                                "-AppleLanguages", "(zh-Hans)"]
        app.launchEnvironment["IMPRESS_V11_FIXTURE_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 30))
        app.tabBars.buttons.element(boundBy: 1).tap()
        let folder = app.cells.matching(identifier: "impress.notes.folder-row")
            .matching(NSPredicate(format: "label == %@", "Study")).firstMatch
        let graph = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", "Graph")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 25))
        XCTAssertEqual(folder.value as? String, "已折叠")
        XCTAssertFalse(graph.exists, "The initial folder must not leak descendants")

        folder.tap()
        XCTAssertTrue(graph.waitForExistence(timeout: 15))
        XCTAssertEqual(folder.value as? String, "已展开")
        let expanded = XCTAttachment(screenshot: app.screenshot())
        expanded.name = "Impress-V1.1-native-outline-expanded"
        expanded.lifetime = .keepAlways
        add(expanded)

        folder.tap()
        let hidden = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"), object: graph)
        XCTAssertEqual(XCTWaiter.wait(for: [hidden], timeout: 10), .completed,
            "UITableView collapse must actually remove hidden child rows")
        XCTAssertEqual(folder.value as? String, "已折叠")
        folder.tap()
        XCTAssertTrue(graph.waitForExistence(timeout: 15))
        graph.tap()
        let heading = app.staticTexts["impress.notes.document-title"]
        XCTAssertTrue(heading.waitForExistence(timeout: 30))
        XCTAssertEqual(heading.label, "Graph",
            "The source file name, not an Obsidian path or guessed title, leads the reader")
        XCTAssertFalse(app.staticTexts["impress.notes.source-path"].exists,
            "Do not restore the redundant full-path banner")
        XCTAssertLessThan(heading.frame.height, 125,
            "A bounded large title must leave room for Canvas and rich Markdown")
        let readable = XCTAttachment(screenshot: app.screenshot())
        readable.name = "Impress-V1.1-document-heading-no-path-banner"
        readable.lifetime = .keepAlways
        add(readable)
    }

    /// RDR-01/RDR-03/RDR-05: real application process, synthetic Vault only.
    /// These checks do not claim private Obsidian screenshot parity or device QA.
    func testNativeTypedPropertiesAndInlineReaderDiagrams() throws {
        let app = openSyntheticFile("Reader-Properties")
        let toggle = app.buttons["impress.notes.properties-toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 20))
        XCTAssertEqual(toggle.value as? String, "已展开")
        let date = app.staticTexts["impress.notes.property-value.Date"]
        XCTAssertTrue(date.waitForExistence(timeout: 10))
        XCTAssertEqual(date.label, "2026-01-31")
        XCTAssertTrue(app.staticTexts["impress.notes.property-value.Status"].exists)
        let readable = app.webViews["impress.notes.markdown-webview"]
        XCTAssertTrue(readable.waitForExistence(timeout: 20))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready:g=0/0:m=0"), object: readable)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 30), .completed)
        let snapshot = XCTAttachment(screenshot: app.screenshot())
        snapshot.name = "Impress-reader-native-properties"
        snapshot.lifetime = .keepAlways
        add(snapshot)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "已折叠")
        XCTAssertFalse(date.isHittable)
    }

    /// RDR-01: KaTeX must render inside the same offline note reading surface.
    func testMathMarkdownUsesBundledOfflineReader() throws {
        let app = openSyntheticFile("Reader-Math")
        let reader = app.webViews["impress.notes.markdown-webview"]
        XCTAssertTrue(reader.waitForExistence(timeout: 25))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready:g=0/0:m=2"), object: reader)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed)
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Impress-reader-inline-KaTeX"
        image.lifetime = .keepAlways
        add(image)
    }

    /// RDR-05: a genuine Markmap code fence renders without the extra menu.
    func testInlineMarkmapFenceRendersInReadingPosition() throws {
        let app = openSyntheticFile("Reader-Markmap")
        let web = app.webViews["impress.notes.markdown-webview"]
        XCTAssertTrue(web.waitForExistence(timeout: 25))
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready:g=1/1:m=0"), object: web)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 35), .completed)
        let snapshot = XCTAttachment(screenshot: app.screenshot())
        snapshot.name = "Impress-reader-inline-Markmap"
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }

    /// RDR-06: two bounded local composites render inside Markdown without
    /// opening their independent native readers or remote asset requests.
    func testInlineCanvasAndExcalidrawUseAuthorizedSyntheticVault() throws {
        let app = openSyntheticFile("Reader-Composite")
        let reader = app.webViews["impress.notes.markdown-webview"]
        XCTAssertTrue(reader.waitForExistence(timeout: 25))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready:g=2/2:m=0"), object: reader)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed,
            "Both embedded geometric documents must render within the offline reader")
        let snapshot = XCTAttachment(screenshot: app.screenshot())
        snapshot.name = "Impress-reader-inline-Canvas-Excalidraw"
        snapshot.lifetime = .keepAlways
        add(snapshot)
    }

    func testMarkdownMermaidRendersInlineWithoutEnteringSeparateReader() throws {
        let app = openSyntheticFile("Graph")
        let rendered = app.webViews["impress.notes.markdown-webview"]
        XCTAssertTrue(rendered.waitForExistence(timeout: 25))
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready:g=1/1:m=0"), object: rendered)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed,
                       "The inline Markdown Mermaid must render from bundled JS")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Impress-reader-inline-Mermaid"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["更多笔记操作"].tap()
        XCTAssertTrue(app.buttons["阅读 Mermaid 图形"].waitForExistence(timeout: 10),
            "The existing independently selectable source-scoped diagram must survive")
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
        XCTAssertTrue(app.staticTexts["impress.notes.document-title"]
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

    func testMarkmapOfflineListBranchAndChatUsesOnlyApprovedSubtree() throws {
        let app = openSyntheticFile("Graph")
        app.buttons["更多笔记操作"].tap()
        let markmap = app.buttons["阅读 Markmap 思维导图"]
        XCTAssertTrue(markmap.waitForExistence(timeout: 12))
        markmap.tap()
        assertOfflineDiagramReady(app)
        let table = app.tables["impress.diagram.source-selection"]
        XCTAssertTrue(table.waitForExistence(timeout: 12))
        let search = app.searchFields["impress.diagram.node-search"]
        XCTAssertTrue(search.waitForExistence(timeout: 12))
        search.tap()
        search.typeText("经过审核的子节点\n")
        let branch = table.cells.matching(
            NSPredicate(format: "label CONTAINS %@", "经过审核的子节点")).firstMatch
        XCTAssertTrue(branch.waitForExistence(timeout: 12),
            "A real matching Markmap node must be selectable in the source tree")
        XCTAssertTrue(branch.isHittable)
        branch.tap()
        app.buttons["impress.diagram.preview-material"].tap()
        let material = app.textViews["impress.diagram.material-preview"]
        XCTAssertTrue(material.waitForExistence(timeout: 12))
        let scope = String(describing: material.value ?? "")
        XCTAssertTrue(scope.contains("经过审核的子节点"))
        XCTAssertFalse(scope.contains("未获批准的兄弟分支"),
            "Markmap selection must never include an unapproved sibling")
        app.buttons["impress.diagram.confirm-material"].tap()
        sendSyntheticChatAndVerifyReply(app, message: "Explain the selected subtree only.")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Markmap-offline-approved-subtree-to-Chat"
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testNativeJSONCanvasOnlySelectedNodeMovesIntoChat() throws {
        let app = openSyntheticFile("Diagram")
        // The source label must hug its two lines rather than consuming the
        // entire reader viewport and hiding native canvas controls.
        let sourcePath = app.staticTexts["impress.notes.document-title"]
        XCTAssertLessThan(sourcePath.frame.height, 120, "Canvas viewport layout is collapsed")
        // Require an actual rendered, interactable node rather than the
        // accessibility *type* of a UIScrollView (UIKit may flatten it).
        let node = app.buttons["impress.canvas.node.a"]
        XCTAssertTrue(node.waitForExistence(timeout: 18),
            "Canvas node missing in native tree: " + app.debugDescription)
        XCTAssertTrue(node.isHittable)
        node.tap()
        XCTAssertEqual(node.value as? String, "已选择")
        app.buttons["更多笔记操作"].tap()
        app.buttons["所选画布节点预览并加入 Chat"].tap()
        let material = app.textViews["impress.canvas.material-preview"]
        XCTAssertTrue(material.waitForExistence(timeout: 12))
        XCTAssertTrue(String(describing: material.value ?? "").contains("a"))
        app.buttons["impress.canvas.confirm-material"].tap()
        sendSyntheticChatAndVerifyReply(app, message: "Analyze the approved Canvas node.")
    }

    func testExcalidrawNativeReadSelectionAndChatRejectsUnselectedElement() throws {
        let app = openSyntheticFile("Drawing")
        let sourcePath = app.staticTexts["impress.notes.document-title"]
        XCTAssertLessThan(sourcePath.frame.height, 120, "Excalidraw viewport layout is collapsed")
        let rectangle = app.buttons["impress.excalidraw.element.a"]
        XCTAssertTrue(rectangle.waitForExistence(timeout: 18),
            "Excalidraw shape missing in native tree: " + app.debugDescription)
        XCTAssertTrue(rectangle.isHittable)
        rectangle.tap()
        XCTAssertEqual(rectangle.value as? String, "已选择")
        app.buttons["更多笔记操作"].tap()
        app.buttons["所选绘图元素预览并加入 Chat"].tap()
        let material = app.textViews["impress.excalidraw.material-preview"]
        XCTAssertTrue(material.waitForExistence(timeout: 12))
        XCTAssertFalse(String(describing: material.value ?? "").contains("Unapproved"))
        app.buttons["impress.excalidraw.confirm-material"].tap()
        sendSyntheticChatAndVerifyReply(app, message: "Analyze only the approved rectangle.")
    }

    private func openSyntheticFile(_ title: String) -> XCUIApplication {
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
        let file = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(file.waitForExistence(timeout: 25))
        file.tap()
        XCTAssertTrue(app.staticTexts["impress.notes.document-title"]
            .waitForExistence(timeout: 20))
        return app
    }

    private func assertOfflineDiagramReady(_ app: XCUIApplication) {
        XCTAssertTrue(app.webViews["impress.diagram.offline-graph"]
            .waitForExistence(timeout: 20))
        let state = app.staticTexts["impress.diagram.render-state"]
        XCTAssertTrue(state.waitForExistence(timeout: 15))
        let didRender = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "ready"), object: state)
        XCTAssertEqual(XCTWaiter.wait(for: [didRender], timeout: 30), .completed)
    }

    private func sendSyntheticChatAndVerifyReply(_ app: XCUIApplication,
                                                 message: String) {
        let input = app.textViews["impress.ai.chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 25))
        let guide = app.alerts["关于讨论"]
        if guide.waitForExistence(timeout: 2) { guide.buttons["知道了"].tap() }
        input.tap()
        input.typeText(message)
        let send = app.buttons["impress.ai.chat.send"]
        XCTAssertTrue(send.isEnabled)
        send.tap()
        let permission = app.alerts["是否附带当前笔记材料？"]
        if permission.waitForExistence(timeout: 10) {
            permission.buttons["附带本次笔记材料"].tap()
        }
        let assistant = app.textViews.matching(
            identifier: "impress.ai.chat.message-body").matching(
                NSPredicate(format: "value CONTAINS %@", "合成模型回复")).firstMatch
        XCTAssertTrue(assistant.waitForExistence(timeout: 35))
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Composite-Selected-Material-Chat-RoundTrip"
        shot.lifetime = .keepAlways
        add(shot)
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

    /// One *continuous* visible UI path using one fixed disposable Vault and
    /// the actual WCDB, Chat, draft, approval and guarded Debug QA writer.
    /// The synthetic model only returns a fixed message after normal consent
    /// and source revision checks. No business operation is auto-completed by
    /// a test-only button or by a direct Swift repository call.
    func testContinuousSourceCardChatDoubleTargetApprovalAndRestart() throws {
        let app = XCUIApplication()
        app.launchArguments += ["-ImpressV11SyntheticVault",
                                "-AppleLanguages", "(zh-Hans)"]
        let id = UUID().uuidString
        app.launchEnvironment["IMPRESS_V11_FIXTURE_ID"] = id
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        tabs.buttons.element(boundBy: 1).tap()
        let folder = app.cells.matching(identifier: "impress.notes.folder-row")
            .matching(NSPredicate(format: "label == %@", "Study")).firstMatch
        XCTAssertTrue(folder.waitForExistence(timeout: 30))
        folder.tap()
        let note = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", "Impress_E2E_Proof")).firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 20))
        note.tap()
        // A cold Xcode 27 simulator can stall coordinated source reads while
        // its full-Vault scan and accessibility bootstrap settle. Keep the
        // actual source/identity assertion (never skip or inject a document).
        let actualSourcePath = app.staticTexts["impress.notes.document-title"]
        XCTAssertTrue(actualSourcePath.waitForExistence(timeout: 40),
            "The real selected note must open through its authorized Vault reader")
        XCTAssertEqual(actualSourcePath.label, "Impress_E2E_Proof",
            "The authorized reader must show the real document title")

        // Real chapter picker -> review a deterministic AI candidate, reject
        // the second candidate, and explicitly commit one original card.
        app.buttons["更多笔记操作"].tap()
        app.buttons["根据笔记生成卡片"].tap()
        XCTAssertTrue(app.navigationBars["生成综合问题"].waitForExistence(timeout: 15))
        app.navigationBars.buttons["生成"].tap()
        let generateConsent = app.alerts["模拟器合成出题"]
        XCTAssertTrue(generateConsent.waitForExistence(timeout: 12))
        generateConsent.buttons["生成"].tap()
        XCTAssertTrue(app.navigationBars["问题候选池"].waitForExistence(timeout: 20))
        let candidates = app.tables.cells
        XCTAssertGreaterThanOrEqual(candidates.count, 2)
        candidates.element(boundBy: 1).tap()
        let importButton = app.navigationBars.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "加入")).firstMatch
        XCTAssertTrue(importButton.isEnabled)
        importButton.tap()
        let saveCard = app.alerts["加入卡片集？"]
        XCTAssertTrue(saveCard.waitForExistence(timeout: 12))
        saveCard.buttons["确认加入"].tap()
        let saved = app.alerts["卡片已添加"]
        XCTAssertTrue(saved.waitForExistence(timeout: 30))
        saved.buttons["完成"].tap()

        // UI re-entry to the exact card and its verified source. No alternate
        // database, title matching, or source inference is used.
        tabs.buttons.element(boundBy: 0).tap()
        let discuss = app.buttons["impress.review.ai-discussion"]
        XCTAssertFalse(discuss.exists, "Discussion is intentionally hidden before answer reveal")
        let reveal = app.buttons["impress.review.reveal-answer"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 20))
        reveal.tap()
        XCTAssertTrue(discuss.waitForExistence(timeout: 15))
        // Real accessibility tree must show all four strong, separate rating
        // indicators after revealing the card; they are not hidden gray text.
        for key in ["hard", "good", "easy", "again"] {
            let label = app.staticTexts["impress.review.rating-hint." + key]
            XCTAssertTrue(label.waitForExistence(timeout: 15),
                "Swipe rating guidance must be legible for " + key)
        }
        let ratingEvidence = XCTAttachment(screenshot: app.screenshot())
        ratingEvidence.name = "Impress-V1.1-four-visible-rating-directions"
        ratingEvidence.lifetime = .keepAlways
        add(ratingEvidence)
        let source = app.buttons["impress.review.source-note"]
        XCTAssertTrue(source.waitForExistence(timeout: 20))
        source.tap()
        XCTAssertTrue(app.staticTexts["impress.notes.document-title"]
            .waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(discuss.waitForExistence(timeout: 15))
        discuss.tap()

        let input = app.textViews["impress.ai.chat.input"]
        XCTAssertTrue(input.waitForExistence(timeout: 20))
        let guide = app.alerts["关于讨论"]
        if guide.waitForExistence(timeout: 2) { guide.buttons["知道了"].tap() }
        input.tap()
        input.typeText("请根据所选来源明确推导、反例与下一步可检验的假设。")
        let send = app.buttons["impress.ai.chat.send"]
        XCTAssertTrue(send.isEnabled)
        send.tap()
        let context = app.alerts["是否附带当前卡片？"]
        if context.waitForExistence(timeout: 8) {
            context.buttons["附带当前卡片"].tap()
        }
        let completedText = app.textViews.matching(
            identifier: "impress.ai.chat.message-body").matching(
                NSPredicate(format: "value CONTAINS %@", "合成模型回复")).firstMatch
        XCTAssertTrue(completedText.waitForExistence(timeout: 30))
        let completedCell = app.cells["impress.ai.chat.completed-assistant"]
        XCTAssertTrue(completedCell.waitForExistence(timeout: 15))
        completedCell.press(forDuration: 1.1)
        let change = app.buttons["统一预览笔记与原卡修订"]
        XCTAssertTrue(change.waitForExistence(timeout: 12))
        change.tap()

        let answer = app.textViews["impress.duplex.answer"]
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        let adopt = app.buttons["impress.duplex.use-suggestion"]
        XCTAssertTrue(adopt.waitForExistence(timeout: 15))
        tapVisible(adopt, in: app)
        let editNote = app.buttons["impress.duplex.edit-note"]
        XCTAssertTrue(editNote.waitForExistence(timeout: 15))
        tapVisible(editNote, in: app)
        let kind = app.buttons["指定原章节并编辑 AI 建议"]
        XCTAssertTrue(kind.waitForExistence(timeout: 12))
        kind.tap()
        let sectionList = app.tables["impress.duplex.note-section-picker"]
        XCTAssertTrue(sectionList.waitForExistence(timeout: 15))
        XCTAssertGreaterThanOrEqual(sectionList.cells.count, 2)
        sectionList.cells.element(boundBy: 1).tap()
        let replacement = app.textViews["impress.duplex.section-replacement"]
        XCTAssertTrue(replacement.waitForExistence(timeout: 15))
        replacement.tap()
        replacement.typeText("\n## 观察\n（经人工核查）这是一条可检验的解释。")
        app.buttons["impress.duplex.save-section-draft"].tap()

        // The actual existing proposal and Approval screens are both used.
        // Switching target choices is non-destructive; neither target is
        // written until the explicit confirmation alert.
        XCTAssertTrue(answer.waitForExistence(timeout: 20))
        let reviewProposal = app.buttons["impress.duplex.preview"]
        tapVisible(reviewProposal, in: app)
        let fullDiff = app.textViews["impress.duplex.full-diff"]
        XCTAssertTrue(fullDiff.waitForExistence(timeout: 20))
        XCTAssertTrue(String(describing: fullDiff.value ?? "").contains("Vault ID:"))
        let noteToggle = app.switches["impress.duplex.select-note"]
        let cardToggle = app.switches["impress.duplex.select-card"]
        XCTAssertTrue(noteToggle.exists && cardToggle.exists)
        let approve = app.buttons["impress.duplex.confirm"]
        XCTAssertTrue(approve.isEnabled)
        approve.tap()
        let finalConsent = app.alerts["确认这两个目标的所选修改？"]
        XCTAssertTrue(finalConsent.waitForExistence(timeout: 12))
        finalConsent.buttons["确认执行"].tap()
        let applied = app.alerts["所选修改已处理"]
        XCTAssertTrue(applied.waitForExistence(timeout: 30),
            "Both source and original card must be verified before a success receipt")
        applied.buttons["确定"].tap()
        let receipt = String(describing: fullDiff.value ?? "")
        XCTAssertTrue(receipt.contains("applied"))
        // Keep the actual inverse-review route available, without silently
        // undoing a user-approved write or conflating an offer with an undo.
        let safeUndo = app.navigationBars.buttons["安全撤销"]
        XCTAssertTrue(safeUndo.waitForExistence(timeout: 12))
        XCTAssertTrue(safeUndo.isEnabled)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Impress-V1.1-continuous-double-target-CAS-approval"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        // F08: actual human-controlled inverse of the already-applied CARD,
        // through the same visible approval controller (never direct WCDB).
        safeUndo.tap()
        let undoCard = app.buttons["撤销原卡改动"]
        XCTAssertTrue(undoCard.waitForExistence(timeout: 12),
            "Applied card must offer an independently authorized inverse")
        undoCard.tap()
        let undoPreview = app.textViews["impress.duplex.undo.full-diff"]
        XCTAssertTrue(undoPreview.waitForExistence(timeout: 20))
        XCTAssertTrue(String(describing: undoPreview.value ?? "").contains("cardID:"),
            "Undo must show the exact original card ID, not a generic confirmation")
        let undoConfirm = app.buttons["impress.duplex.undo.confirm"]
        XCTAssertTrue(undoConfirm.isEnabled)
        undoConfirm.tap()
        let inverseConsent = app.alerts["确认撤销这个目标？"]
        XCTAssertTrue(inverseConsent.waitForExistence(timeout: 12))
        inverseConsent.buttons["确认撤销"].tap()
        let inverseReceipt = app.alerts["撤销结果已保存"]
        XCTAssertTrue(inverseReceipt.waitForExistence(timeout: 30),
            "CAS-approved inverse must save its receipt; failure is not success")
        inverseReceipt.buttons["确定"].tap()
        let afterInverse = String(describing: fullDiff.value ?? "")
        XCTAssertTrue(afterInverse.contains("reverted"),
            "Card inverse status must persist independently of the note target")
        XCTAssertTrue(afterInverse.contains("applied"),
            "Undoing the card must not silently undo the approved Markdown")
        let inverseProof = XCTAttachment(screenshot: app.screenshot())
        inverseProof.name = "Impress-V1.1-approved-card-actual-safe-undo"
        inverseProof.lifetime = .keepAlways
        add(inverseProof)

        // This process boundary must not replace the existing WCDB or Vault.
        app.terminate()
        app.launch()
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        tabs.buttons.element(boundBy: 1).tap()
        XCTAssertTrue(folder.waitForExistence(timeout: 25))
        folder.tap()
        let reopened = app.cells.matching(identifier: "impress.notes.file-row")
            .matching(NSPredicate(format: "label == %@", "Impress_E2E_Proof")).firstMatch
        XCTAssertTrue(reopened.waitForExistence(timeout: 20))
        reopened.tap()
        let persistedSource = app.staticTexts["impress.notes.document-title"]
        XCTAssertTrue(persistedSource.waitForExistence(timeout: 15))
        // Verify the actual QA Markdown byte change after a true process boundary,
        // not merely that the folder shell can open again.
        app.buttons["更多笔记操作"].tap()
        app.buttons["查看 Markdown 源码"].tap()
        let savedNote = app.textViews.matching(
            NSPredicate(format: "value CONTAINS %@", "经人工核查")).firstMatch
        XCTAssertTrue(savedNote.waitForExistence(timeout: 15),
            "Approved source edits must survive cold launch in the same disposable Vault")
        // The reverse note -> original-card check is a real visible action.
        // A changed relevant section must offer an explicit human decision,
        // not silently rewrite the original card after a source edit.
        app.buttons["更多笔记操作"].tap()
        app.buttons["核查笔记更新是否影响原卡"].tap()
        let impactSheet = app.sheets["核查关联原卡"]
        XCTAssertTrue(impactSheet.waitForExistence(timeout: 20),
            "A changed note section must produce a real original-card review")
        impactSheet.buttons.element(boundBy: 0).tap()
        let impact = app.textViews["impress.notes.source-impact.full-text"]
        XCTAssertTrue(impact.waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["impress.notes.source-impact.edit-original"]
            .waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["impress.notes.source-impact.unaffected"]
            .waitForExistence(timeout: 15))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        // The real session (and its receipt history) must remain discoverable;
        // opening the source is not permission to upload another message.
        app.buttons["impress.notes.ai-discussion"].tap()
        let features = app.buttons["impress.ai.chat.features"]
        XCTAssertTrue(features.waitForExistence(timeout: 15))
        features.tap()
        // Native pop-up menu, not a pushed feature-list controller.
        let history = app.buttons["历史讨论"]
        XCTAssertTrue(history.waitForExistence(timeout: 15))
        history.tap()
        let sessions = app.tables["impress.ai.chat.history-list"]
        XCTAssertTrue(sessions.waitForExistence(timeout: 15))
        let persistedSession = sessions.cells["impress.ai.chat.history-row"].firstMatch
        XCTAssertTrue(persistedSession.waitForExistence(timeout: 20),
            "Completed discussion must remain in persisted local history")

        // P0-B step 13/18: return from the same persisted Chat session to the
        // same reviewed original card (after approved note edit + card undo).
        // A swipe is the only normal route to an FSRS event, and MUST require
        // a fresh answer reveal. We never grade by calling repository methods.
        // Chat history is several native pushes below the notes root.
        // ImNavigationViewController intentionally hides the TabBar when
        // pushing a secondary screen. Return through REAL visible back
        // controls; do not tap a nonexistent bar or bypass persisted UI state.
        var backSteps = 0
        while !tabs.exists && backSteps < 5 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            XCTAssertTrue(back.waitForExistence(timeout: 12),
                "History / Chat / document must provide a native return path")
            back.tap()
            backSteps += 1
        }
        XCTAssertTrue(tabs.waitForExistence(timeout: 15),
            "Navigating back to the primary notes screen must restore four Tabs")
        tabs.buttons.element(boundBy: 0).tap()
        let newReveal = app.buttons["impress.review.reveal-answer"]
        XCTAssertTrue(newReveal.waitForExistence(timeout: 30),
            "Original restored card must remain in the actual due queue")
        let guardedActions = app.buttons["impress.review.ai-discussion"]
        XCTAssertFalse(guardedActions.exists,
            "An old Chat/undo cannot silently expose the answer on return")
        newReveal.tap()
        XCTAssertTrue(guardedActions.waitForExistence(timeout: 12),
            "Only an explicitly revealed current answer may enable grading")
        let stack = app.otherElements["impress.review.swipe-stack"]
        XCTAssertTrue(stack.waitForExistence(timeout: 15))
        // Horizontal rating avoids scrolling the revealed long answer.
        stack.swipeRight()
        let completed = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "本轮复习完成")).firstMatch
        XCTAssertTrue(completed.waitForExistence(timeout: 30),
            "One visible Tinder swipe must produce a completed FSRS review")
        let rated = XCTAttachment(screenshot: app.screenshot())
        rated.name = "Impress-V1.1-original-card-restored-then-FSRS-scored"
        rated.lifetime = .keepAlways
        add(rated)

        // Restart again without recreating or resetting the same WCDB:
        // graded new card should not be due for a second immediate review.
        app.terminate()
        app.launch()
        XCTAssertTrue(tabs.waitForExistence(timeout: 30))
        tabs.buttons.element(boundBy: 0).tap()
        let noDue = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "暂无到期卡片")).firstMatch
        XCTAssertTrue(noDue.waitForExistence(timeout: 30),
            "A restarted session must not re-grade a just-scheduled card")
    }

    private func tapVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["impress.duplex.change-scroll"]
        for _ in 0..<8 where !element.isHittable {
            if scroll.exists { scroll.swipeUp() } else { app.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
        element.tap()
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
