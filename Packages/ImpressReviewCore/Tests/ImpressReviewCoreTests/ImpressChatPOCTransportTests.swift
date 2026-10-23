import Foundation
import XCTest
@testable import ImpressReviewCore

final class ImpressChatPOCTransportTests: XCTestCase {
    private func replay(_ string: String, provider: ImpressChatPOCProviderProtocol,
                        cuts: [Int]) throws -> (outputs: [ImpressChatPOCOutput], complete: Bool) {
        let bytes = Array(string.utf8)
        var state = ImpressChatPOCReplay(provider: provider)
        var results: [ImpressChatPOCOutput] = []
        var cursor = 0, i = 0
        while cursor < bytes.count {
            let amount = min(cuts[i % cuts.count], bytes.count - cursor)
            results += try state.append(Data(bytes[cursor..<(cursor + amount)]))
            cursor += amount
            i += 1
        }
        results += try state.finish()
        return (results, state.normalizer.isCompleted)
    }

    func testOpenAIByteFracturesPreserveUnicodeAndTerminal() throws {
        let wire = [
            ": heartbeat",
            "data: {\"choices\":[{\"delta\":{\"content\":\"你好🌱\"}}]}",
            "",
            "data: {\"choices\":[{\"delta\":{\"content\":\"👩‍💻 e\u{301}\"}}]}",
            "",
            "data: [DONE]",
            ""
        ].joined(separator: "\r\n") + "\r\n"
        let expected: [ImpressChatPOCOutput] = [.delta("你好🌱"), .delta("👩‍💻 e\u{301}"),
                                                .completed]
        for cuts in [[1], [2, 5, 1, 3, 7], [4096]] {
            let result = try replay(wire, provider: .openAIChat, cuts: cuts)
            XCTAssertEqual(result.outputs, expected)
            XCTAssertTrue(result.complete)
        }
    }

    func testAnthropicAndResponsesProtocolsNormalizeWithoutFalseFinish() throws {
        let anthropic = "event: content_block_delta\n" +
            "data: {\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"拆解\"}}\n\n" +
            "event: message_stop\n" + "data: {\"type\":\"message_stop\"}\n\n"
        let a = try replay(anthropic, provider: .anthropicMessages, cuts: [1, 7, 3])
        XCTAssertEqual(a.outputs, [.delta("拆解"), .completed])
        XCTAssertTrue(a.complete)
        let response = "event: response.output_text.delta\r" +
            "data: {\"delta\":\"first\"}\r\r" +
            "event: response.completed\r" +
            "data: {\"type\":\"response.completed\"}\r\r"
        let b = try replay(response, provider: .openAIResponses, cuts: [1, 2])
        XCTAssertEqual(b.outputs, [.delta("first"), .completed])
        XCTAssertTrue(b.complete)
    }

    func testGeminiChunkDeltasFollowOfficialStreamingSemantics() throws {
        let a = #"data: {"candidates":[{"content":{"parts":[{"text":"中文"}]}}]}"#
        let b = #"data: {"candidates":[{"content":{"parts":[{"text":"🌱"}]},"finishReason":"STOP"}]}"#
        let result = try replay(a + "\n\n" + b + "\n\n",
                                provider: .geminiGenerateContent, cuts: [1, 19, 2])
        XCTAssertEqual(result.outputs, [.delta("中文"), .delta("🌱"), .completed])
    }

    func testTruncatedOrSafetyStopNeverMarksAnswerCompleted() throws {
        let truncated = "data: " +
            #"{"choices":[{"delta":{"content":"partial"},"finish_reason":"length"}]}"# +
            "\n\n"
        let one = try replay(truncated, provider: .openAIChat, cuts: [2])
        XCTAssertEqual(one.outputs, [.delta("partial"), .failed])
        XCTAssertFalse(one.complete)

        let anthropic = "event: message_delta\n" +
            #"data: {"type":"message_delta","delta":{"stop_reason":"max_tokens"}}"# +
            "\n\nevent: message_stop\n" +
            #"data: {"type":"message_stop"}"# + "\n\n"
        let two = try replay(anthropic, provider: .anthropicMessages, cuts: [9])
        XCTAssertEqual(two.outputs, [.failed])
        XCTAssertFalse(two.complete)

        let gemini = "data: " +
            #"{"candidates":[{"content":{"parts":[{"text":"partial"}]},"finishReason":"MAX_TOKENS"}]}"# +
            "\n\n"
        let three = try replay(gemini, provider: .geminiGenerateContent, cuts: [15])
        XCTAssertEqual(three.outputs, [.delta("partial"), .failed])
        XCTAssertFalse(three.complete)
    }

    func testUnterminatedNetworkStreamNeverCompletesAIMessage() throws {
        let incomplete = "data: {\"choices\":[{\"delta\":{\"content\":\"partial\"}}]}\n\n"
        let result = try replay(incomplete, provider: .openAIChat, cuts: [1])
        XCTAssertEqual(result.outputs, [.delta("partial")])
        XCTAssertFalse(result.complete)
    }

    func testMultilineDataAndCommentsRespectSSEBoundary() throws {
        var wire = ImpressChatPOCSSEDecoder()
        let bytes = Data(": keepalive\nid: 91\nevent: custom\n".utf8) +
                    Data("data: hello\ndata: world\n\n".utf8)
        let events = try wire.append(bytes)
        XCTAssertEqual(events, [ImpressChatPOCSSEEvent(event: "custom", id: "91",
                                                       data: "hello\nworld")])
        XCTAssertEqual(wire.dispatchedCount, 1)
    }

    func testMalformedAndOversizedFramesFailClosed() throws {
        var broken = ImpressChatPOCSSEDecoder()
        XCTAssertThrowsError(try broken.append(Data([0xff, 0x0a]))) { error in
            XCTAssertEqual(error as? ImpressChatPOCTransportError, .invalidUTF8)
        }
        var oversized = ImpressChatPOCSSEDecoder()
        let huge = Data(repeating: 97, count: ImpressChatPOCSSEDecoder.maximumBufferBytes + 1)
        XCTAssertThrowsError(try oversized.append(huge)) { error in
            XCTAssertEqual(error as? ImpressChatPOCTransportError, .tooLarge)
        }
        var normalized = ImpressChatPOCEventNormalizer(provider: .openAIChat)
        XCTAssertThrowsError(try normalized.consume(
            ImpressChatPOCSSEEvent(event: nil, id: nil, data: "{bad")))
        XCTAssertEqual(try normalized.consume(
            ImpressChatPOCSSEEvent(event: nil, id: nil, data: "[DONE]")), [.completed])
        XCTAssertThrowsError(try normalized.consume(
            ImpressChatPOCSSEEvent(event: nil, id: nil, data:
                #"{"choices":[{"delta":{"content":"late"}}]}"#)))
    }

    func testProviderErrorKeepsUnfinishedStatus() throws {
        var model = ImpressChatPOCEventNormalizer(provider: .anthropicMessages)
        XCTAssertEqual(try model.consume(ImpressChatPOCSSEEvent(
            event: "error", id: nil, data: #"{"error":{"message":"private"}} "#)),
            [.failed])
        XCTAssertFalse(model.isCompleted)
        XCTAssertTrue(model.isFailed)
    }
}
