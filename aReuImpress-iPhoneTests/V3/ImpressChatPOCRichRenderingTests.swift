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

    private func descendants<T: UIView>(of view: UIView, as type: T.Type) -> [T] {
        view.subviews.flatMap { child -> [T] in
            ((child as? T).map { [$0] } ?? []) +
                descendants(of: child, as: type)
        }
    }
}
