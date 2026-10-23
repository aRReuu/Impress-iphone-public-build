import Foundation
import UIKit
import XCTest
import ImpressReviewCore
@testable import aReuImpress_iPhone

/// POC-02 vertical integration: domain events -> incremental blocks -> UIKit.
@MainActor
final class ImpressChatPOCStreamDriverIntegrationTests: XCTestCase {
    func testInjectedDomainDeltasCompleteOnlyOnTerminal() async throws {
        let vc = ImpressChatPOCViewController()
        vc.loadViewIfNeeded()
        var observedPrompt = ""
        vc.injectOfflineDomainStreamForTest { prompt in
            observedPrompt = prompt
            return AsyncThrowingStream { stream in
                stream.yield(.delta("# 新理解\n\n"))
                stream.yield(.delta("可验证的解释。"))
                stream.yield(.completed)
                stream.finish()
            }
        }
        let input = try XCTUnwrap(subviews(in: vc.view, as: UITextView.self)
            .first(where: { $0.accessibilityIdentifier == "impress.chat.poc.input" }))
        input.text = "测试真实事件适配"
        vc.textViewDidChange(input)
        let send = try XCTUnwrap(subviews(in: vc.view, as: UIButton.self)
            .first(where: { $0.accessibilityIdentifier == "impress.chat.poc.send-stop" }))
        send.sendActions(for: .touchUpInside)
        for _ in 0..<80 where vc.testVisibleStreamPhase != .completed {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(observedPrompt, "测试真实事件适配")
        XCTAssertEqual(vc.testVisibleStreamPhase, .completed)
        XCTAssertEqual(send.accessibilityLabel, "发送")
    }

    func testInjectedStreamUnexpectedEOFKeepsPartialAsFailed() async throws {
        let vc = ImpressChatPOCViewController()
        vc.loadViewIfNeeded()
        vc.injectOfflineDomainStreamForTest { _ in
            AsyncThrowingStream { stream in
                stream.yield(.delta("只生成了部分文本"))
                stream.finish()
            }
        }
        let input = try XCTUnwrap(subviews(in: vc.view, as: UITextView.self)
            .first(where: { $0.accessibilityIdentifier == "impress.chat.poc.input" }))
        input.text = "异常断流"
        vc.textViewDidChange(input)
        let send = try XCTUnwrap(subviews(in: vc.view, as: UIButton.self)
            .first(where: { $0.accessibilityIdentifier == "impress.chat.poc.send-stop" }))
        send.sendActions(for: .touchUpInside)
        for _ in 0..<80 where vc.testVisibleStreamPhase != .failed {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(vc.testVisibleStreamPhase, .failed)
        XCTAssertEqual(send.accessibilityLabel, "重新生成")
    }

    private func subviews<T: UIView>(in root: UIView, as type: T.Type) -> [T] {
        root.subviews.flatMap { child in
            ((child as? T).map { [$0] } ?? []) + subviews(in: child, as: type)
        }
    }
}
