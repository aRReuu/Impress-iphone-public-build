import XCTest
import UIKit
import WebKit
import ImpressReviewCore
@testable import aReuImpress_iPhone

/// Native Debug test host, disposable data only. Does not touch user chats.
@MainActor
final class ImpressChatPOCRichRenderingTests: XCTestCase {
    func testCodeHasSelectionAndCopiesActualBodyNotFences() throws {
        let cell = ImpressChatPOCStructuredCell(
            frame: CGRect(x: 0, y: 0, width: 320, height: 240))
        let source = "~~~swift\nlet task = \"学习\"\nprint(task)\n~~~"
        cell.configure(markdown: source, kind: .code, stable: true)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.accessibilityIdentifier, "impress.chat.poc.code")
        let controls = descendants(of: cell, as: UIButton.self)
        let copy = try XCTUnwrap(controls.first {
            $0.accessibilityIdentifier == "impress.chat.poc.content-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "let task = \"学习\"\nprint(task)")
        let editor = try XCTUnwrap(descendants(of: cell, as: UITextView.self).first)
        XCTAssertTrue(editor.isSelectable)
        XCTAssertFalse(editor.isEditable)
        XCTAssertTrue(editor.attributedText.string.contains("print(task)"))
    }

    func testTableUsesRealGridAndHorizontalScroller() throws {
        let cell = ImpressChatPOCStructuredCell(
            frame: CGRect(x: 0, y: 0, width: 300, height: 260))
        let table = "| 较长的标题栏目 | 状态 | 来源 |\n" +
            "| --- | --- | --- |\n" +
            "| Markdown 内容 | 完成 | Offline Fixture |\n" +
            "| GFM 表格 | 已批准 | Local source |"
        cell.configure(markdown: table, kind: .table, stable: true)
        cell.layoutIfNeeded()
        XCTAssertEqual(cell.accessibilityIdentifier, "impress.chat.poc.table")
        let grid = try XCTUnwrap(descendants(of: cell, as: UIStackView.self)
            .first(where: { $0.arrangedSubviews.count == 3 }))
        XCTAssertEqual(grid.arrangedSubviews.count, 3,
                       "GFM delimiter must not become a data row")
        XCTAssertTrue(descendants(of: cell, as: UILabel.self)
            .contains { $0.text == "Offline Fixture" })
        let copy = try XCTUnwrap(descendants(of: cell, as: UIButton.self).first {
            $0.accessibilityIdentifier == "impress.chat.poc.content-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, table)
    }

    func testProductionGFMTableRetainsLongCellsAndLiteralWindowsPaths() throws {
        let cell = ImpressChatPOCStructuredCell(
            frame: CGRect(x: 0, y: 0, width: 310, height: 540))
        let windowsPath = #"C:\Notes\Projects\drawing.md"#
        let longValue = String(repeating: "长内容需要完整显示并支持纵向滚动。", count: 150)
        let source = "| 字段 | 值 |\n| --- | --- |\n" +
            "| 路径 | " + windowsPath + " |\n" +
            "| 管道 | alpha\\|beta |\n" +
            "| 说明 | " + longValue + " |"
        cell.configure(markdown: source, kind: .table, stable: true)
        cell.layoutIfNeeded()
        let labels = descendants(of: cell, as: UILabel.self)
        XCTAssertTrue(labels.contains { $0.text == windowsPath },
            "A literal Windows path must not lose its backslashes")
        XCTAssertTrue(labels.contains { $0.text == "alpha|beta" },
            "Only escaped separators should be unescaped")
        let longLabel = try XCTUnwrap(labels.first { $0.text == longValue })
        XCTAssertEqual(longLabel.numberOfLines, 0,
            "Long GFM table cells must not silently truncate at three lines")
        let scroll = try XCTUnwrap(descendants(of: cell, as: UIScrollView.self).first)
        XCTAssertTrue(scroll.showsVerticalScrollIndicator,
            "Tall cells need a vertical scroll range even with few rows")
        let copy = try XCTUnwrap(descendants(of: cell, as: UIButton.self).first {
            $0.accessibilityIdentifier == "impress.chat.poc.content-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, source,
            "Source copying must preserve all original Markdown escapes")

        // Reused collection cells cannot retain the previous tall-scroll state.
        cell.configure(markdown: "| Key | Value |\n| --- | --- |\n| A | B |",
                       kind: .table, stable: true)
        XCTAssertFalse(scroll.showsVerticalScrollIndicator)
        XCTAssertFalse(descendants(of: cell, as: UILabel.self).contains {
            $0.text == longValue
        })
    }

    func testWindowsCRLFCodeSelectionAndGFMTableProjection() throws {
        let code = ImpressChatPOCStructuredCell(
            frame: CGRect(x: 0, y: 0, width: 310, height: 250))
        code.configure(markdown: "~~~swift\r\nlet x = \"中文\"\r\n~~~",
                       kind: .code, stable: true)
        code.layoutIfNeeded()
        let editor = try XCTUnwrap(descendants(of: code, as: UITextView.self).first)
        XCTAssertEqual(editor.text, "let x = \"中文\"")
        let copy = try XCTUnwrap(descendants(of: code, as: UIButton.self).first {
            $0.accessibilityIdentifier == "impress.chat.poc.content-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, "let x = \"中文\"")

        let grid = ImpressChatPOCStructuredCell(
            frame: CGRect(x: 0, y: 0, width: 300, height: 200))
        let source = "| 条目 | 状态 |\r\n| --- | --- |\r\n| 中文 | 通过 |"
        grid.configure(markdown: source, kind: .table, stable: true)
        grid.layoutIfNeeded()
        XCTAssertTrue(descendants(of: grid, as: UILabel.self).contains {
            $0.text == "通过"
        }, "A CRLF GFM table must render cells, not raw source")
        let gridCopy = try XCTUnwrap(descendants(of: grid, as: UIButton.self).first {
            $0.accessibilityIdentifier == "impress.chat.poc.content-copy"
        })
        gridCopy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, source,
                       "The copy action retains original GFM source line endings")
    }

    func testMathEngineIsOfflineLocalAndHasCopyFallback() throws {
        let resource = try XCTUnwrap(Bundle.main.url(
            forResource: "index", withExtension: "html",
            subdirectory: "MarkdownReader"))
        XCTAssertTrue(resource.isFileURL)
        let cell = ImpressChatPOCMathCell(
            frame: CGRect(x: 0, y: 0, width: 390, height: 210))
        let source = "$$\n\\frac{1}{2} + \\sqrt{4}\n$$"
        cell.configure(source, stable: true)
        cell.layoutIfNeeded()
        let math = try XCTUnwrap(descendants(of: cell, as: WKWebView.self).first)
        XCTAssertEqual(math.accessibilityIdentifier, "impress.chat.poc.math-katex")
        XCTAssertEqual(math.scrollView.isScrollEnabled, false)
        let copy = try XCTUnwrap(descendants(of: cell, as: UIButton.self).first {
            $0.accessibilityIdentifier == "impress.chat.poc.math-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, source)
    }

    func testMathActuallyCreatesOfflineKaTeXDOMBeforeHidingTextFallback() throws {
        let cell = ImpressChatPOCMathCell(
            frame: CGRect(x: 0, y: 0, width: 390, height: 210))
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 220))
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(cell)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let formula = "$$\n\\frac{1}{2}+\\sqrt{4}\n$$"
        cell.configure(formula, stable: false)
        let web = try XCTUnwrap(descendants(of: cell, as: WKWebView.self).first)
        let loaded = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            web.url?.isFileURL == true && !web.isLoading
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [loaded], timeout: 12), .completed,
                       "Offline reader must finish loading before checking provisional state")
        XCTAssertTrue(web.isHidden, "Provisional math must remain selectable source text")
        cell.configure(formula, stable: true)
        let appears = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !web.isHidden
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [appears], timeout: 12), .completed,
                       "Rendered math must be visible only after the offline KaTeX DOM exists")
        let verified = expectation(description: "Real offline KaTeX node")
        web.evaluateJavaScript("document.querySelectorAll('.katex').length") {
            value, error in
            XCTAssertNil(error)
            XCTAssertGreaterThan((value as? NSNumber)?.intValue ?? 0, 0)
            verified.fulfill()
        }
        wait(for: [verified], timeout: 5)
        cell.configure("not a formula", stable: false)
        XCTAssertTrue(web.isHidden,
                      "Cell reuse cannot display a stale mathematical rendering")
        XCTAssertEqual(cell.accessibilityLabel, "公式：not a formula")
    }

    func testProductionTranscriptUsesRealDiffableBlocksAndRetainsPartialState() throws {
        let viewport = ImpressChatProductionTranscript(
            frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let list = try XCTUnwrap(descendants(of: viewport, as: UICollectionView.self).first)
        XCTAssertEqual(list.accessibilityIdentifier, "impress.ai.chat.transcript")
        let userID = UUID()
        let assistantID = UUID()
        let question = WCDBV3ChatMessage(
            messageID: userID, role: .user, text: "解释可验证的假设", status: .completed)
        var answer = WCDBV3ChatMessage(
            messageID: assistantID, role: .assistant,
            text: "# 标题\n\n首段", status: .pending)
        viewport.update([question, answer])
        let started = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in list.numberOfItems(inSection: 0) >= 4 },
            object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [started], timeout: 8), .completed,
            "A real production message must be split into user, Markdown and stream rows")

        answer.text += "\n\n~~~swift\nlet n = 1\n~~~"
        viewport.update([question, answer])
        let appended = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in list.numberOfItems(inSection: 0) >= 5 },
            object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [appended], timeout: 8), .completed)
        answer.status = .failed
        viewport.update([question, answer])
        let retained = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in list.numberOfItems(inSection: 0) >= 5 },
            object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [retained], timeout: 8), .completed,
            "A failed stream retains code and partial text instead of discarding them")
    }

    func testColdRestoredFailedAnswerKeepsUnfinishedGFMTableProvisional() throws {
        let viewport = ImpressChatProductionTranscript(
            frame: CGRect(x: 0, y: 0, width: 390, height: 700))
        let window = UIWindow(frame: viewport.bounds)
        let root = UIViewController()
        window.rootViewController = root
        root.view.addSubview(viewport)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let list = try XCTUnwrap(descendants(of: viewport, as: UICollectionView.self).first)
        let assistant = WCDBV3ChatMessage(
            messageID: UUID(), role: .assistant,
            text: "| Name | Result |\n| --- | --- |\n| Chinese | part",
            status: .failed)
        viewport.update([assistant])
        viewport.layoutIfNeeded()
        let appeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            viewport.layoutIfNeeded()
            return list.visibleCells.contains { $0 is ImpressChatPOCStructuredCell }
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [appeared], timeout: 8), .completed)
        let table = try XCTUnwrap(list.visibleCells
            .compactMap { $0 as? ImpressChatPOCStructuredCell }.first)
        XCTAssertTrue(descendants(of: table, as: UILabel.self)
            .contains { $0.text == "表格 · 生成中" },
            "Cold-restored unfinished Markdown must not masquerade as a complete table")
        XCTAssertFalse(list.visibleCells.contains {
            $0.accessibilityIdentifier == "impress.ai.chat.reply-more"
        }, "Failed replies cannot expose completed-answer operations")
    }

    func testProductionReplyFooterUsesNativeCopyAndExistingReviewMenu() throws {
        let cell = ImpressChatReplyActionsCell(
            frame: CGRect(x: 0, y: 0, width: 390, height: 44))
        let menu = UIMenu(children: [UIAction(title: "Review", handler: { _ in })])
        let response = "最终答复\n含中文和公式"
        cell.configure(messageID: UUID(), text: response, menu: menu)
        cell.layoutIfNeeded()
        let buttons = descendants(of: cell, as: UIButton.self)
        let copy = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.ai.chat.reply-copy"
        })
        copy.sendActions(for: .touchUpInside)
        XCTAssertEqual(UIPasteboard.general.string, response)
        let more = try XCTUnwrap(buttons.first {
            $0.accessibilityIdentifier == "impress.ai.chat.reply-more"
        })
        XCTAssertTrue(more.showsMenuAsPrimaryAction)
        XCTAssertEqual(more.menu?.children.count, 1)
        XCTAssertEqual(copy.bounds.height, 44)
    }

    func testProductionMarkdownRespectsDynamicDarkInkAndSelection() throws {
        let cell = ImpressChatDocumentCell(
            frame: CGRect(x: 0, y: 0, width: 390, height: 180))
        cell.overrideUserInterfaceStyle = .dark
        cell.configure("**中文强调** and plain text", kind: .paragraph,
                       headingLevel: 0, user: false, stable: true)
        let text = try XCTUnwrap(descendants(of: cell, as: UITextView.self).first)
        XCTAssertTrue(text.isSelectable)
        let rendered = try XCTUnwrap(text.attributedText)
        let boldRange = (rendered.string as NSString).range(of: "中文强调")
        let plainRange = (rendered.string as NSString).range(of: "plain text")
        XCTAssertNotEqual(boldRange.location, NSNotFound)
        XCTAssertNotEqual(plainRange.location, NSNotFound)
        let strongFont = try XCTUnwrap(rendered.attribute(.font,
            at: boldRange.location, effectiveRange: nil) as? UIFont)
        let plainFont = try XCTUnwrap(rendered.attribute(.font,
            at: plainRange.location, effectiveRange: nil) as? UIFont)
        XCTAssertGreaterThan(plainFont.pointSize, 12)
        XCTAssertTrue(strongFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        XCTAssertFalse(plainFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        let ink = try XCTUnwrap(rendered.attribute(.foregroundColor,
            at: plainRange.location, effectiveRange: nil) as? UIColor)
        XCTAssertEqual(ink, .label)
        XCTAssertEqual(ink.resolvedColor(with: text.traitCollection),
                       UIColor.label.resolvedColor(with: text.traitCollection))

        // Reuse must not leak assistant strong emphasis into plain/user text.
        cell.configure("普通问题", kind: .paragraph,
                       headingLevel: 0, user: true, stable: true)
        let userText = try XCTUnwrap(text.attributedText)
        let userFont = try XCTUnwrap(userText.attribute(.font,
            at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertFalse(userFont.fontDescriptor.symbolicTraits.contains(.traitBold))
        cell.configure("普通回答", kind: .paragraph,
                       headingLevel: 0, user: false, stable: true)
        let normal = try XCTUnwrap(text.attributedText)
        let normalFont = try XCTUnwrap(normal.attribute(.font,
            at: 0, effectiveRange: nil) as? UIFont)
        XCTAssertFalse(normalFont.fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    private func descendants<T: UIView>(of view: UIView, as type: T.Type) -> [T] {
        view.subviews.flatMap { child -> [T] in
            ((child as? T).map { [$0] } ?? []) +
                descendants(of: child, as: type)
        }
    }
}
