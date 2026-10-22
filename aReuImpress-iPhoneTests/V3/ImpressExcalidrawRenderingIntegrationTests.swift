import XCTest
import UIKit
import ImpressReviewCore
@testable import aReuImpress_iPhone

/// RDR native glyph fidelity: synthetic read-only Excalidraw, not user Vault.
final class ImpressExcalidrawRenderingIntegrationTests: XCTestCase {
    @MainActor
    func testBoundChineseTextHasRealUIKitLabelAndDocumentFontSize() throws {
        let json = """
        {"type":"excalidraw","appState":{"viewBackgroundColor":"#ffffff"},
         "elements":[
          {"id":"panel","type":"rectangle","x":0,"y":0,"width":400,"height":240,
           "backgroundColor":"#f9f9f9","strokeColor":"#111111"},
          {"id":"task","type":"text","x":24,"y":24,"width":330,"height":130,
           "containerId":"panel","fontSize":32,"fontFamily":2,
           "textAlign":"left","strokeColor":"#202020",
           "text":"任务文字：复习及理解 🧠"}]}
        """
        let model = try ImpressExcalidrawScene.parse(Data(json.utf8),
            format: .excalidrawJSON)
        let reader = try ImpressExcalidrawNativeView(source: model)
        reader.frame = CGRect(x: 0, y: 0, width: 390, height: 430)
        reader.layoutIfNeeded()
        let labels = reader.subviews.flatMap(\.subviews)
            .flatMap(\.subviews).compactMap { $0 as? UILabel }
        let task = try XCTUnwrap(labels.first { $0.text?.contains("复习及理解") == true })
        XCTAssertEqual(task.font.pointSize, 32, accuracy: 0.1)
        XCTAssertEqual(task.textAlignment, .left)
        XCTAssertFalse(task.isHidden)
        XCTAssertGreaterThan(task.frame.height, 30)
    }
}
