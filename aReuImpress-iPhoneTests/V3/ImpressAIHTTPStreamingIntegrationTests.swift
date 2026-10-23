import XCTest
import Foundation
import ImpressReviewCore
@testable import aReuImpress_iPhone

/// Zero-network native request/response wire test. No paid model, Key or Vault.
final class ImpressAIHTTPStreamingIntegrationTests: XCTestCase {
    private final class OfflineSSEProtocol: URLProtocol {
        static var body = Data()
        static var code = 200
        static var contentType = "text/event-stream; charset=utf-8"
        static var capturedRequest: URLRequest?
        static var requestCount = 0

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.capturedRequest = request
            Self.requestCount += 1
            let response = HTTPURLResponse(
                url: request.url!, statusCode: Self.code, httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": Self.contentType])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Self.body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    func testFreeModelRequestStreamsAndTerminatesWithoutNetwork() async throws {
        let first = #"{"choices":[{"delta":{"content":"中文 🧠"}}]}"#
        let second = #"{"choices":[{"delta":{"content":"＋证据"},"finish_reason":"stop"}]}"#
        let lines = ["data: " + first, "", "data: " + second, "",
                     "data: [DONE]", "", ""]
        OfflineSSEProtocol.body = Data(lines.joined(separator: "\n").utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineSSEProtocol.self]
        let client = ImpressAIHTTPClient(session: URLSession(configuration: config))
        let connection = ImpressAIOpenCodeFreeQA.connection()
        let model = ImpressAIModel(connectionID: connection.id,
                                  identifier: ImpressAIOpenCodeFreeQA.preferredModelID)
        let route = ImpressAIResolvedRoute(connection: connection, model: model)
        let stream = try await client.converseStream(
            route: route, system: "仅离线测试", turns: [
                ImpressAIChatTurn(role: .user, text: "请解释")
            ])
        var deltas: [ImpressChatPOCOutput] = []
        for try await value in stream { deltas.append(value) }
        XCTAssertEqual(deltas, [.delta("中文 🧠"), .delta("＋证据"), .completed])
        let request = try XCTUnwrap(OfflineSSEProtocol.capturedRequest)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        XCTAssertEqual(request.httpMethod, "POST")
        // URLProtocol may receive a POST body as a non-rewindable stream.
        // Inspect the exact request builder used by converseStream instead.
        let prepared = try await client.debugPreparedStreamRequest(
            route: route, system: "仅离线测试",
            turns: [ImpressAIChatTurn(role: .user, text: "请解释")])
        let data = try XCTUnwrap(prepared.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["model"] as? String,
                       ImpressAIOpenCodeFreeQA.preferredModelID)
    }

    func testUnexpectedEOFMustThrowRatherThanComplete() async throws {
        let partialJSON = #"{"choices":[{"delta":{"content":"未完成"}}]}"#
        OfflineSSEProtocol.body = Data(("data: " + partialJSON + "\n\n").utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineSSEProtocol.self]
        let client = ImpressAIHTTPClient(session: URLSession(configuration: config))
        let connection = ImpressAIOpenCodeFreeQA.connection()
        let model = ImpressAIModel(connectionID: connection.id,
                                  identifier: ImpressAIOpenCodeFreeQA.preferredModelID)
        let stream = try await client.converseStream(
            route: ImpressAIResolvedRoute(connection: connection, model: model),
            system: "只进行本地合成测试",
            turns: [ImpressAIChatTurn(role: .user, text: "测试")])
        do {
            for try await item in stream {
                XCTAssertNotEqual(item, .completed)
            }
            XCTFail("SSE EOF without terminal must fail")
        } catch {
            // The stored reply remains partial; it cannot be approved.
        }
    }

    private func syntheticRoute(provider: ImpressAIProvider,
                                wire: ImpressAIProtocol,
                                modelID: String) -> ImpressAIResolvedRoute {
        // Explicitly fake hostname and no authentication. URLProtocol intercepts
        // before any socket could be opened, so all providers cost zero.
        let connection = ImpressAIConnection(title: "Offline protocol fixture",
            provider: provider, apiProtocol: wire,
            baseURL: URL(string: "https://impress-fixture.invalid/v1")!,
            authentication: .noAuthentication)
        return ImpressAIResolvedRoute(connection: connection,
            model: ImpressAIModel(connectionID: connection.id, identifier: modelID))
    }

    private func zeroNetworkReplay(_ wire: String,
                                   route: ImpressAIResolvedRoute) async throws
        -> ([ImpressChatPOCOutput], URLRequest) {
        OfflineSSEProtocol.body = Data(wire.utf8)
        OfflineSSEProtocol.code = 200
        OfflineSSEProtocol.contentType = "text/event-stream"
        OfflineSSEProtocol.capturedRequest = nil
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineSSEProtocol.self]
        let client = ImpressAIHTTPClient(session: URLSession(configuration: config))
        let stream = try await client.converseStream(route: route,
            system: "合成 system", turns: [
                ImpressAIChatTurn(role: .user, text: "合成 user")])
        var events: [ImpressChatPOCOutput] = []
        for try await event in stream { events.append(event) }
        let request = try XCTUnwrap(OfflineSSEProtocol.capturedRequest)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "text/event-stream")
        return (events, try await client.debugPreparedStreamRequest(
            route: route, system: "合成 system",
            turns: [ImpressAIChatTurn(role: .user, text: "合成 user")]))
    }

    func testNativeOpenAIResponsesRequiresExplicitCompleteStatus() async throws {
        let route = syntheticRoute(provider: .openAI, wire: .responses,
                                   modelID: "synthetic-responses")
        let data = [
            "event: response.output_text.delta",
            #"data: {"type":"response.output_text.delta","delta":"第一段"}"#, "",
            "event: response.completed",
            #"data: {"type":"response.completed","response":{"status":"completed"}}"#, "", ""
        ].joined(separator: "\n")
        let (events, prepared) = try await zeroNetworkReplay(data, route: route)
        XCTAssertEqual(events, [.delta("第一段"), .completed])
        XCTAssertEqual(prepared.url?.lastPathComponent, "responses")
        let body = try XCTUnwrap(prepared.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["store"] as? Bool, false)
        XCTAssertNotNil(json["input"])
        XCTAssertNil(json["messages"])
    }

    func testNativeAnthropicMessagesRequiresMessageStopAndEndTurn() async throws {
        let route = syntheticRoute(provider: .anthropic, wire: .anthropicMessages,
                                   modelID: "synthetic-anthropic")
        let data = [
            "event: content_block_delta",
            #"data: {"type":"content_block_delta","delta":{"type":"text_delta","text":"文本 🧠"}}"#, "",
            "event: message_delta",
            #"data: {"type":"message_delta","delta":{"stop_reason":"end_turn"}}"#, "",
            "event: message_stop", #"data: {"type":"message_stop"}"#, "", ""
        ].joined(separator: "\n")
        let (events, request) = try await zeroNetworkReplay(data, route: route)
        XCTAssertEqual(events, [.delta("文本 🧠"), .completed])
        XCTAssertEqual(request.url?.lastPathComponent, "messages")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"),
                       "2023-06-01")
        let json = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try XCTUnwrap(request.httpBody)) as? [String: Any])
        XCTAssertEqual(json["stream"] as? Bool, true)
        XCTAssertEqual(json["model"] as? String, "synthetic-anthropic")
        XCTAssertNotNil(json["system"])
    }

    func testNativeGeminiSSEUsesAltSSEAndModelRole() async throws {
        let route = syntheticRoute(provider: .gemini, wire: .geminiGenerateContent,
                                   modelID: "synthetic-gemini")
        let data = [
            #"data: {"candidates":[{"content":{"parts":[{"text":"中文"}]}}]}"#, "",
            #"data: {"candidates":[{"content":{"parts":[{"text":"🌱"}]},"finishReason":"STOP"}]}"#, "", ""
        ].joined(separator: "\n")
        let (events, request) = try await zeroNetworkReplay(data, route: route)
        XCTAssertEqual(events, [.delta("中文"), .delta("🌱"), .completed])
        XCTAssertTrue(request.url?.path.contains("streamGenerateContent") == true)
        let query = URLComponents(url: try XCTUnwrap(request.url),
                                  resolvingAgainstBaseURL: false)
        XCTAssertEqual(query?.queryItems?.first(where: { $0.name == "alt" })?.value,
                       "sse")
        let body = try XCTUnwrap(request.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertNotNil(json["contents"])
        XCTAssertNil(json["messages"])
    }

    func testNativeDeepSeekGLMAndCustomUseCorrectChatCompletionsWire() async throws {
        for provider in [ImpressAIProvider.deepSeek, .zhipu, .custom] {
            let route = syntheticRoute(provider: provider,
                wire: .chatCompletions, modelID: "synthetic-compatible")
            let data = [
                #"data: {"choices":[{"delta":{"content":"合成答复"}}]}"#, "",
                #"data: {"choices":[{"finish_reason":"stop"}]}"#, "",
                "data: [DONE]", "", ""
            ].joined(separator: "\n")
            let (events, request) = try await zeroNetworkReplay(data, route: route)
            XCTAssertEqual(events, [.delta("合成答复"), .completed])
            XCTAssertEqual(request.url?.lastPathComponent, "completions")
            let json = try XCTUnwrap(JSONSerialization.jsonObject(
                with: try XCTUnwrap(request.httpBody)) as? [String: Any])
            XCTAssertEqual(json["stream"] as? Bool, true)
            XCTAssertNotNil(json["messages"])
            XCTAssertNil(json["input"])
        }
    }

    func testNativeHTTPRateLimitAndNonSSEFailWithoutAutomaticSecondRequest() async throws {
        let connection = ImpressAIOpenCodeFreeQA.connection()
        let model = ImpressAIModel(connectionID: connection.id,
                                  identifier: ImpressAIOpenCodeFreeQA.preferredModelID)
        let route = ImpressAIResolvedRoute(connection: connection, model: model)
        defer {
            OfflineSSEProtocol.code = 200
            OfflineSSEProtocol.contentType = "text/event-stream; charset=utf-8"
        }
        for (statusCode, contentType) in [
            (429, "text/event-stream"), (200, "application/json")
        ] {
            OfflineSSEProtocol.code = statusCode
            OfflineSSEProtocol.contentType = contentType
            OfflineSSEProtocol.requestCount = 0
            OfflineSSEProtocol.body = Data(
                #"{"choices":[{"delta":{"content":"should-not-emit"}}]}"#.utf8)
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [OfflineSSEProtocol.self]
            let client = ImpressAIHTTPClient(session: URLSession(configuration: config))
            let stream = try await client.converseStream(route: route,
                system: "offline only", turns: [
                    ImpressAIChatTurn(role: .user, text: "test")])
            var outputs: [ImpressChatPOCOutput] = []
            var didThrow = false
            do {
                for try await value in stream { outputs.append(value) }
            } catch {
                didThrow = true
            }
            XCTAssertTrue(didThrow)
            XCTAssertTrue(outputs.isEmpty,
                "An HTTP error or non-SSE response cannot become visible model text")
            XCTAssertEqual(OfflineSSEProtocol.requestCount, 1,
                "A failed HTTP attempt must never silently retry or incur more requests")
        }
    }

    func testNativeResponsesIncompleteRetainsDeltaAndThrowsNotCompleted() async throws {
        let route = syntheticRoute(provider: .openAI, wire: .responses,
                                   modelID: "synthetic-incomplete")
        OfflineSSEProtocol.body = Data([
            "event: response.output_text.delta",
            #"data: {"type":"response.output_text.delta","delta":"保留片段"}"#, "",
            "event: response.incomplete",
            #"data: {"type":"response.incomplete","response":{"status":"incomplete"}}"#, "", ""
        ].joined(separator: "\n").utf8)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [OfflineSSEProtocol.self]
        let client = ImpressAIHTTPClient(session: URLSession(configuration: config))
        let stream = try await client.converseStream(route: route,
            system: "合成前提", turns: [
                ImpressAIChatTurn(role: .user, text: "合成提问")])
        var outputs: [ImpressChatPOCOutput] = []
        var didThrow = false
        do {
            for try await result in stream { outputs.append(result) }
        } catch {
            didThrow = true
        }
        XCTAssertTrue(didThrow, "Incomplete response cannot be accepted as completed")
        XCTAssertEqual(outputs, [.delta("保留片段")],
            "The already delivered partial response must remain visible")
    }

}
