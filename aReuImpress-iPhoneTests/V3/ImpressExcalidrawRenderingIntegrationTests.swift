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
    @MainActor
    func testNativeExcalidrawOpacityAffectsStrokeFillAndTextWithoutHidingSelection() throws {
        let json = """
        {"type":"excalidraw","appState":{"viewBackgroundColor":"#ffffff"},
         "elements":[
          {"id":"panel","type":"rectangle","x":0,"y":0,"width":160,"height":90,
           "opacity":35,"strokeColor":"#111111","backgroundColor":"#999999"},
          {"id":"caption","type":"text","x":10,"y":10,"width":120,"height":50,
           "opacity":60,"fontSize":20,"strokeColor":"#222222","text":"透明文字"}]}
        """
        let scene = try ImpressExcalidrawScene.parse(Data(json.utf8),
            format: .excalidrawJSON)
        let reader = try ImpressExcalidrawNativeView(source: scene)
        let controls = reader.subviews.flatMap(\.subviews)
            .compactMap { $0 as? UIButton }
        let panel = try XCTUnwrap(controls.first {
            $0.accessibilityIdentifier == "impress.excalidraw.element.panel"
        })
        let shape = try XCTUnwrap(panel.layer.sublayers?
            .compactMap { $0 as? CAShapeLayer }.first)
        XCTAssertEqual(shape.opacity, 0.35, accuracy: 0.001,
            "The outline and the fill must share Excalidraw opacity")
        XCTAssertEqual(panel.alpha, 1, accuracy: 0.001,
            "Selection border must remain visible even when artwork is translucent")
        let caption = try XCTUnwrap(controls.first {
            $0.accessibilityIdentifier == "impress.excalidraw.element.caption"
        })
        let label = try XCTUnwrap(caption.subviews
            .compactMap { $0 as? UILabel }.first)
        XCTAssertEqual(label.alpha, 0.60, accuracy: 0.001)
    }

    @MainActor
    func testBoundTextKeepsSourceOcclusionAndActualVerticalCenter() throws {
        let drawing = """
        {"type":"excalidraw","elements":[
          {"id":"base","type":"rectangle","x":0,"y":0,"width":320,"height":210,
           "backgroundColor":"#dddddd"},
          {"id":"bound","type":"text","x":15,"y":15,"width":290,"height":180,
           "containerId":"base","fontSize":26,"lineHeight":1.6,
           "verticalAlign":"middle","text":"先复习再验证"},
          {"id":"front","type":"ellipse","x":10,"y":10,"width":100,"height":90,
           "backgroundColor":"#ffffff"}]}
        """
        let scene = try ImpressExcalidrawScene.parse(Data(drawing.utf8),
            format: .excalidrawJSON)
        let reader = try ImpressExcalidrawNativeView(source: scene)
        reader.frame = CGRect(x: 0, y: 0, width: 390, height: 430)
        reader.layoutIfNeeded()
        let buttons = reader.subviews.flatMap(\.subviews)
            .compactMap { $0 as? UIButton }
        func node(_ name: String) throws -> UIButton {
            try XCTUnwrap(buttons.first {
                $0.accessibilityIdentifier == "impress.excalidraw.element." + name
            })
        }
        let container = try node("base")
        let textNode = try node("bound")
        let occluder = try node("front")
        XCTAssertGreaterThan(textNode.layer.zPosition, container.layer.zPosition)
        XCTAssertLessThan(textNode.layer.zPosition, occluder.layer.zPosition,
            "Later Excalidraw shapes must still cover earlier bound text")
        let label = try XCTUnwrap(textNode.subviews.compactMap { $0 as? UILabel }
            .first(where: { $0.text == "先复习再验证" }),
            "Inspect the authored Excalidraw glyph label, not UIButton.titleLabel")
        XCTAssertGreaterThan(label.frame.minY, 12,
            "Middle-aligned text must use measured glyph height, not full box height")
        let style = try XCTUnwrap(label.attributedText?.attribute(.paragraphStyle,
            at: 0, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(style.minimumLineHeight, 26 * 1.6, accuracy: 0.5)
    }

}
