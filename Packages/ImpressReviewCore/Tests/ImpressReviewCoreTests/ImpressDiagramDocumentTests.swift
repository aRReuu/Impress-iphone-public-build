import Foundation
import Testing
@testable import ImpressReviewCore

@Suite("Markdown diagrams preserve exact source scope and consent")
struct ImpressDiagramDocumentTests {
    @Test func mermaidUTF8CRLFAndOtherFencesDoNotConfuseParser() throws {
        let backtick = String(Character(UnicodeScalar(96)!))
        let source = "\u{FEFF}Hello 🌱\r\n" + backtick.repeatElement(3) +
            "json\r\n" + backtick.repeatElement(3) + "mermaid ignored\r\n" +
            backtick.repeatElement(3) + "\r\n## Visible\r\n" +
            backtick.repeatElement(4) + "mermaid\r\nflowchart LR\r\n" +
            "A[允许] --> B[确认]\r\nC[不得发送]\r\n" + backtick.repeatElement(4) + "\r\n"
        let blocks = try ImpressDiagramDocument.mermaidBlocks(in: Data(source.utf8))
        #expect(blocks.count == 1)
        let doc = try #require(blocks.first)
        #expect(doc.nodes.count == 2)
        let approved = try doc.selection(ids: [doc.nodes[0].id])
        let payload = try approved.contextJSON()
        #expect(payload.contains("允许"))
        #expect(!payload.contains("不得发送"))
        #expect(String(decoding: Array(source.utf8)[doc.startUTF8..<doc.endUTF8],
            as: UTF8.self).hasPrefix(backtick.repeatElement(4)))
    }
    @Test func duplicateHeadingsStaySeparateAndChildExpansionIsExplicit() throws {
        let doc = try ImpressDiagramDocument.markmap(in:
            Data("# Root\n## Same\nConcrete mechanism\n### Child\n## Same\nUnapproved\n".utf8))
        let same = doc.nodes.filter { $0.title == "Same" }
        #expect(same.count == 2)
        #expect(same[0].id != same[1].id)
        let one = try doc.selection(ids: [same[0].id])
        #expect(!one.ids.contains(doc.nodes[2].id))
        #expect(!((try one.contextJSON()).contains("Unapproved")))
        #expect((try one.contextJSON()).contains("Concrete mechanism"))
        let expanded = try doc.selection(ids: [same[0].id], includeDescendants: true)
        #expect(expanded.ids.contains(doc.nodes[2].id))
        #expect(!expanded.ids.contains(same[1].id))
        #expect(expanded.ancestors.contains(doc.nodes[0].id))
    }
    @Test func forgedNodeAndMalformedBytesFailClosed() throws {
        let doc = try ImpressDiagramDocument.markmap(in: Data("# Hi\n".utf8))
        #expect(throws: ImpressDiagramError.invalidSelection) {
            try doc.selection(ids: ["fabricated"])
        }
        #expect(throws: ImpressDiagramError.invalidDocument) {
            try ImpressDiagramDocument.markmap(in: Data([0xFF,0xFF]))
        }
    }
}
private extension String {
    func repeatElement(_ count: Int) -> String { String(repeating: self, count: count) }
}
