import XCTest
@testable import ImpressReviewCore

final class ImpressChatPOCStreamTests: XCTestCase {
    private var example: String {
        ["# 对话", "", "文字 **粗体**、*斜体* 与 [链接](https://example.org)。", "",
         "## 问题", "", "- 列表", "  - 嵌套", "2. 第二项", "",
         "> 引用 🧠", "", "~~~swift", "let s = \"中文 👩‍💻\"", "~~~", "",
         "| 条目 | 状态 |", "| --- | ---: |", "| 中文 | 42 |", "",
         "$$", "E=mc^2", "$$", "", "组合 e\u{301} 与 👩‍👩‍👧‍👦"].joined(separator: "\n")
    }
    func testDifferentUnicodeScalarChunkSizesAreOneShotEquivalent() {
        let scalars = Array(example.unicodeScalars)
        let reference = ImpressChatPOCStream.parseOnce(example)
        for seed in 1...31 {
            var engine = ImpressChatPOCStream(), position = 0, random = UInt64(seed)
            engine.start()
            while position < scalars.count {
                random = random &* 2862933555777941757 &+ 3037000493
                let n = min(Int(random % 11) + 1, scalars.count - position)
                engine.append(scalars[position..<(position+n)].map { String($0) }.joined())
                position += n
            }
            engine.finish()
            XCTAssertEqual(engine.source, example)
            XCTAssertEqual(engine.blocks, reference, "seed \(seed)")
            XCTAssertTrue(engine.blocks.allSatisfy(\.stable))
        }
    }
    func testProvisionalAndCommittedBlocks() {
        var e = ImpressChatPOCStream()
        e.start()
        e.append("已完成。\n\n| A | B |\n| --- | --- |\n| 中")
        XCTAssertTrue(e.blocks.first!.stable)
        XCTAssertFalse(e.blocks.last!.stable)
        e.append("文 | 🧠 |\n\n")
        XCTAssertEqual(e.blocks.first!.id, 0)
        XCTAssertTrue(e.blocks.last!.stable)
        e.finish()
        XCTAssertEqual(e.blocks, ImpressChatPOCStream.parseOnce(e.source))
        let kinds = ImpressChatPOCStream.parseOnce(example).map(\.kind)
        for kind in [ImpressChatPOCBlock.Kind.heading, .paragraph, .list, .quote,
                     .code, .table, .math] { XCTAssertTrue(kinds.contains(kind)) }
    }
    func testCancelAndFailNeverComplete() {
        var e = ImpressChatPOCStream()
        e.start(); e.append("~~~swift\nlet x = "); e.stop()
        e.append("42"); e.finish()
        XCTAssertEqual(e.phase, .stopped)
        XCTAssertFalse(e.blocks.last!.stable)
        XCTAssertFalse(e.source.contains("42"))
        var failure = ImpressChatPOCStream()
        failure.start(); failure.append("$$\npartial"); failure.fail()
        XCTAssertEqual(failure.phase, .failed)
    }
    func testStableIDsAndDirtyTailCost() {
        var e = ImpressChatPOCStream()
        e.start(); e.append("# 标题\n\n")
        let prefix = e.blocks[0]
        for i in 0..<200 { e.append("内容 \(i)\n\n") }
        XCTAssertEqual(e.blocks.first, prefix)
        XCTAssertEqual(e.blocks.map(\.id), Array(0..<e.blocks.count))
        XCTAssertLessThan(e.lastReparsedUTF8Count, 100)
        e.finish()
        XCTAssertEqual(e.blocks, ImpressChatPOCStream.parseOnce(e.source))
    }
}
