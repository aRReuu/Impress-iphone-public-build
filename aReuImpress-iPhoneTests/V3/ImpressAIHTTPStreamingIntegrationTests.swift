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

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

        override func startLoading() {
            Self.capturedRequest = request
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
        OfflineSSEProtocol.body = Data((
            "data: " +
            #"{"choices":[{"delta":{"content":"中文 🧠"}}]}"# + "\n\n" +
            "data: " +
            #"{"choices":[{"delta":{"content":"＋证据"},"finish_reason":"stop"}]}"# + "\n\n" +
            "data: [DONE]\n\n").utf8)
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
        let data = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertEqual(body["stream"] as? Bool, true)
        XCTAssertEqual(body["model"] as? String,
                       ImpressAIOpenCodeFreeQA.preferredModelID)
    }

    func testUnexpectedEOFMustThrowRatherThanComplete() async throws {
        OfflineSSEProtocol.body = Data((
            "data: " +
            #"{"choices":[{"delta":{"content":"未完成"}}]}"# + "\n\n").utf8)
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
}
