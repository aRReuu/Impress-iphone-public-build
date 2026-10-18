import Foundation
import XCTest
@testable import ImpressReviewCore

final class ImpressAIContractsTests: XCTestCase {
    private let safeURL = URL(string: "https://api.example.test/v1")!
    private func fixture() throws -> (ImpressAIRegistry, ImpressAIConnection, ImpressAIModel) {
        let c = ImpressAIConnection(title: "API A", provider: .deepSeek,
                                    apiProtocol: .chatCompletions, baseURL: safeURL,
                                    credentialID: UUID())
        let m = ImpressAIModel(connectionID: c.id, identifier: "model-A", jsonVerified: true)
        let cfg = try ImpressAIRegistry(connections: [c], models: [m],
                         routes: [ImpressAIRoute(task: .questionGeneration, primaryModelID: m.id)])
        return (cfg, c, m)
    }

    func testIndependentProvidersModelsAndRoutes() throws {
        let (_, c1, m1) = try fixture()
        let c2 = ImpressAIConnection(title: "Another key same service", provider: .deepSeek,
                                     apiProtocol: .chatCompletions, baseURL: safeURL,
                                     credentialID: UUID())
        let m2 = ImpressAIModel(connectionID: c2.id, identifier: m1.identifier, jsonVerified: true)
        let cfg = try ImpressAIRegistry(connections: [c1, c2], models: [m1, m2],
                         routes: [
                           .init(task: .questionGeneration, primaryModelID: m1.id),
                           .init(task: .conversation, primaryModelID: m2.id)
                         ])
        XCTAssertEqual(try cfg.resolve(.questionGeneration).connection.id, c1.id)
        XCTAssertEqual(try cfg.resolve(.conversation).model.id, m2.id)
    }

    func testSecretsNotSerializedAsValues() throws {
        let (cfg, _, _) = try fixture()
        let dump = String(decoding: try JSONEncoder().encode(cfg), as: UTF8.self)
        XCTAssertTrue(dump.contains("credentialID"))
        XCTAssertFalse(dump.contains("API_KEY_VALUE"))
        XCTAssertFalse(dump.contains("Bearer"))
    }

    func testUnsafeEndpointsRejected() {
        for string in ["http://example.com/v1", "https://user:pass@example.com/v1",
                       "https://example.com/v1?key=hidden", "https://example.com:444/v1"] {
            let c = ImpressAIConnection(title: "Bad", provider: .custom,
                   apiProtocol: .chatCompletions, baseURL: URL(string: string)!)
            XCTAssertThrowsError(try ImpressAIRegistry(connections: [c]))
        }
    }

    func testProviderWireProtocolMustMatch() throws {
        let bad = ImpressAIConnection(title: "Bad", provider: .anthropic,
                                      apiProtocol: .chatCompletions, baseURL: safeURL)
        XCTAssertThrowsError(try ImpressAIRegistry(connections: [bad]))
        let ok = ImpressAIConnection(title: "Custom", provider: .custom,
                                     apiProtocol: .chatCompletions, baseURL: safeURL)
        XCTAssertNoThrow(try ImpressAIRegistry(connections: [ok]))
    }

    func testNoAutomaticCrossProviderFallback() throws {
        let (_, c1, m1) = try fixture()
        let c2 = ImpressAIConnection(title: "OpenAI", provider: .openAI,
                                     apiProtocol: .responses, baseURL: safeURL, credentialID: UUID())
        let m2 = ImpressAIModel(connectionID: c2.id, identifier: "model-2", jsonVerified: true)
        let route = ImpressAIRoute(task: .questionGeneration, primaryModelID: m1.id,
                                   fallbackModelID: m2.id)
        XCTAssertThrowsError(try ImpressAIRegistry(connections: [c1,c2], models: [m1,m2], routes: [route]))
        let explicit = ImpressAIRoute(task: .questionGeneration, primaryModelID: m1.id,
                            fallbackModelID: m2.id, crossProviderAuthorized: true)
        XCTAssertNoThrow(try ImpressAIRegistry(connections: [c1,c2], models: [m1,m2], routes: [explicit]))
    }

    func testUnverifiedModelCannotReadPrivateNotes() throws {
        let (_, c, m) = try fixture()
        var failed = m
        failed.jsonVerified = false
        let r = try ImpressAIRegistry(connections: [c], models: [failed],
                             routes: [.init(task: .questionGeneration, primaryModelID: failed.id)])
        XCTAssertThrowsError(try r.resolve(.questionGeneration))
        XCTAssertThrowsError(try r.resolve(.questionGeneration))
    }

    private func source() -> ImpressAISource {
        ImpressAISource(vaultID: "v1", relativePath: "学习/原理.md",
                        documentSHA256: String(repeating: "a", count: 64), heading: "应用")
    }

    func testFiveQuestionRequestAndReadOnlySourceEvidence() throws {
        let s = source()
        let e = ImpressAIExcerpt(id: "fragment-01", source: s, text: "已有资料解释机制")
        let c = ImpressAIQuestionCandidate(question: "在什么时候采用?", answer: "当条件满足时使用。",
                    dimension: .application, evidenceIDs: ["fragment-01"])
        let p = ImpressAIQuestionPool(source: s, excerpts: [e], requestedCount: 5,
                                    modelProfileID: UUID(), candidates: [c])
        let audit = ImpressAIQuestionValidator.audit(p)
        XCTAssertEqual(audit.candidates[0].issues, [])
        XCTAssertEqual(try ImpressAIQuestionValidator.validatedSelection(audit).count, 1)
    }

    func testFabricatedEvidenceBlocked() throws {
        let s = source()
        let e = ImpressAIExcerpt(id: "1", source: s, text: "x")
        let candidate = ImpressAIQuestionCandidate(question: "问题", answer: "答案", dimension: .mechanism,
                                                   evidenceIDs: ["does-not-exist"])
        let p = ImpressAIQuestionPool(source: s, excerpts: [e],
                modelProfileID: UUID(), candidates: [candidate])
        XCTAssertFalse(ImpressAIQuestionValidator.audit(p).candidates[0].issues.isEmpty)
        XCTAssertThrowsError(try ImpressAIQuestionValidator.validatedSelection(p))
    }

    func testDuplicateCandidatesAndExistingCardsBlocked() {
        let s = source()
        let e = ImpressAIExcerpt(id: "x", source: s, text: "source text")
        let a = ImpressAIQuestionCandidate(question: "为什么？", answer: "答案", dimension: .mechanism,
                                         evidenceIDs: ["x"])
        var b = a
        b.id = UUID()
        let p = ImpressAIQuestionPool(source: s, excerpts: [e],
                modelProfileID: UUID(), candidates: [a,b])
        let audit = ImpressAIQuestionValidator.audit(p, existingQuestions: ["为什么？"])
        XCTAssertFalse(audit.candidates[0].issues.isEmpty)
        XCTAssertFalse(audit.candidates[1].issues.isEmpty)
    }

    func testSelectionsRejectBlankAndOverCount() throws {
        let s = source()
        let e = ImpressAIExcerpt(id: "x", source: s, text: "source")
        let blank = ImpressAIQuestionCandidate(question: "  ", answer: "answer",
                          dimension: .comparison, evidenceIDs: ["x"])
        let p = ImpressAIQuestionPool(source: s, excerpts: [e], requestedCount: 1,
                             modelProfileID: UUID(), candidates: [blank])
        XCTAssertThrowsError(try ImpressAIQuestionValidator.validatedSelection(p))
        var excluded = p
        excluded.candidates[0].question = "ok"
        excluded.candidates[0].selected = false
        XCTAssertThrowsError(try ImpressAIQuestionValidator.validatedSelection(excluded))
    }

    func testStrictJSONRejectsMarkdownFencesAndFakeNarrative() throws {
        XCTAssertThrowsError(try ImpressAIQuestionPrompt.decode("Here are your questions: {}"))
        XCTAssertThrowsError(try ImpressAIQuestionPrompt.decode("```json\n{}\n```"))
        let json = """
        {"questions":[{"question":"解释原因？","answer":"有明确机制。",
        "dimension":"mechanism","evidenceIDs":["e1"]}]}
        """
        XCTAssertEqual(try ImpressAIQuestionPrompt.decode(json).count, 1)
    }

    func testNoBlindUploadLargeContext() throws {
        let s = source()
        let e = ImpressAIExcerpt(id: "x", source: s, text: String(repeating: "a", count: 512))
        XCTAssertThrowsError(try ImpressAIQuestionPrompt.input([e], maxBytes: 120))
        XCTAssertTrue(try ImpressAIQuestionPrompt.input([e]).contains("fragment") == false)
    }
}
