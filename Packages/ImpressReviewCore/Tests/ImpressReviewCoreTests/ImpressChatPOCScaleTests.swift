import XCTest
@testable import ImpressReviewCore

final class ImpressChatPOCScaleTests: XCTestCase {
    func testResponseSizesRemainSemanticallyEquivalentAcrossChunkings() {
        for bytes in [1_024, 16_384, 65_536] {
            let phrase = "中文🧠 **证据**：逐层解释。"
            let paragraph = String(repeating: phrase, count: max(1, bytes / phrase.utf8.count))
            let markdown = "# 压力测试\n\n" + paragraph + "\n\n" +
                "~~~swift\nlet observation = true\n~~~\n\n" +
                "| 格式 | 结果 |\n| --- | --- |\n| GFM | 可解析 |\n\n" +
                "$$\nE=mc^2\n$$"
            let expected = ImpressChatPOCStream.parseOnce(markdown)
            let scalars = Array(markdown.unicodeScalars)
            for eventSize in [1, 17, 257] {
                var engine = ImpressChatPOCStream()
                engine.start()
                for index in stride(from: 0, to: scalars.count, by: eventSize) {
                    engine.append(scalars[index..<min(scalars.count, index+eventSize)]
                        .map(String.init).joined())
                }
                engine.finish()
                XCTAssertEqual(engine.blocks, expected,
                    "\(bytes) bytes, \(eventSize)-scalar fragments")
                XCTAssertEqual(engine.phase, .completed)
            }
        }
    }

    func testUnclosedLargeCodeBlockNeverFabricatesCompletedAnswer() {
        var engine = ImpressChatPOCStream()
        engine.start()
        engine.append("~~~swift\n")
        for index in 0..<1_000 {
            engine.append("let item\(index) = \"中文🧠\"\n")
        }
        XCTAssertEqual(engine.blocks.count, 1)
        XCTAssertEqual(engine.blocks[0].kind, .code)
        XCTAssertFalse(engine.blocks[0].stable)
        XCTAssertEqual(engine.phase, .streaming)
        engine.stop()
        engine.finish()
        XCTAssertEqual(engine.phase, .stopped)
        XCTAssertFalse(engine.blocks[0].stable)
    }
}
