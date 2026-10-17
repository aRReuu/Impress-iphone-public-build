import XCTest
@testable import ImpressReviewCore

final class ImpressBatchParserTests: XCTestCase {
    func testUnicodeAndMultilineLabeledQuestions() {
        let rows = ImpressBatchParser.parse("Q: 光合作用的机理？\nA: 光能转化为\n化学能。\n\n问题：为什么回忆？\n答案：检索会巩固记忆。", as: .text)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy(\.isValid))
        XCTAssertEqual(rows[0].answer, "光能转化为\n化学能。")
        XCTAssertEqual(rows[1].line, 5)
    }

    func testCSVQuotedCommaNewlineAndEscapedQuote() {
        let csv = "question,answer\n\"What, exactly?\",\"He said \"\"yes\"\".\nThen stopped.\"\n"
        let rows = ImpressBatchParser.parse(csv, as: .csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].isValid)
        XCTAssertEqual(rows[0].question, "What, exactly?")
        XCTAssertEqual(rows[0].answer, "He said \"yes\".\nThen stopped.")
    }

    func testTSVChoicesRequireExplicitCorrectIndices() {
        let tsv = "question\ttype\toptions\tcorrect\n选哪个？\tchoice\tA|B|C\t1,3\n未标记？\tchoice\tA|B\t\n"
        let rows = ImpressBatchParser.parse(tsv, as: .tsv)
        XCTAssertTrue(rows[0].isValid)
        XCTAssertEqual(rows[0].correctIndices, [0, 2])
        XCTAssertFalse(rows[1].isValid)
        XCTAssertEqual(rows[1].raw.contains("未标记？"), true)
    }

    func testInvalidInputNeverInventsAnswer() {
        let rows = ImpressBatchParser.parse("## 模糊标题\n没有显式的问答结构", as: .markdown)
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].answer, "")
        XCTAssertFalse(rows[0].isValid)
        XCTAssertFalse(rows[0].raw.isEmpty)
    }

    func testInvalidCSVQuoteIsNotSilentlySaved() {
        let rows = ImpressBatchParser.parse("question,answer\n\"Q\"garbage,A", as: .csv)
        XCTAssertEqual(rows.count, 1)
        XCTAssertFalse(rows[0].isValid)
        XCTAssertTrue(rows[0].issues.contains(where: { $0.contains("引号") }))
    }

    func testMarkdownExplicitFieldsAndNoNetwork() {
        let rows = ImpressBatchParser.parse("## Q: 为什么？\n**A:** 因为有机制。", as: .markdown)
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows[0].isValid)
    }

    func testEmptyAndOversizedInputIsRejectedSafely() {
        XCTAssertTrue(ImpressBatchParser.parse("", as: .text).isEmpty)
        let result = ImpressBatchParser.parse(String(repeating: "A", count: ImpressBatchParser.maximumBytes + 1),
            as: .text)
        XCTAssertEqual(result.count, 1)
        XCTAssertFalse(result[0].isValid)
    }
}


extension ImpressBatchParserTests {
    func testVaultIdentityRoundTripAndLegacySafety() throws {
        let key = try ImVaultFileIdentity(vaultID: "vault-alpha", relativePath: "Folder/复习.md")
        let stored = try ImpressBatchSourceKey.encode(key)
        XCTAssertEqual(try ImpressBatchSourceKey.decode(stored), key)
        XCTAssertNil(try ImpressBatchSourceKey.decode("Old/path.md"))
        XCTAssertThrowsError(try ImpressBatchSourceKey.decode("obsidian+v1:invalid$$"))
    }
}
