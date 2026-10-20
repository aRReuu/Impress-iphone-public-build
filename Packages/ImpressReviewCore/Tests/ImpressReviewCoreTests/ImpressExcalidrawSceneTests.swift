import Foundation
import Testing
@testable import ImpressReviewCore

@Suite("Excalidraw offline source envelopes and exact selection")
struct ImpressExcalidrawSceneTests {
    private var rawJSON: String {
        """
        {"type":"excalidraw","version":2,
         "elements":[
          {"id":"f","type":"frame","x":0,"y":0,"width":500,"height":300},
          {"id":"a","type":"rectangle","x":20,"y":30,"width":100,"height":60,
           "strokeColor":"#222222","groupIds":["group-one"],"frameId":"f"},
          {"id":"b","type":"text","x":170,"y":40,"width":200,"height":80,
           "text":"Meaning 🌱","groupIds":["group-one"],"frameId":"f"},
          {"id":"outside","type":"text","x":600,"y":80,"width":200,"height":90,
           "text":"Never in implicit source"}]}
        """
    }

    @Test func plainJSONAndMarkdownWrapperReadSameElements() throws {
        let plain = try ImpressExcalidrawScene.parse(Data(rawJSON.utf8),
            format: .excalidrawJSON)
        let grave = String(Character(UnicodeScalar(96)!))
        let markdown = """
        ---
        excalidraw-plugin: parsed
        ---
        # Text Elements
        Indexed text only

        # Drawing
        \(grave)\(grave)\(grave)json
        \(rawJSON)
        \(grave)\(grave)\(grave)
        """
        let wrapped = try ImpressExcalidrawScene.parse(Data(markdown.utf8),
            format: .excalidrawMarkdown)
        #expect(wrapped.elements == plain.elements)
        #expect(wrapped.elements[1].strokeColor == "#222222")
        #expect(wrapped.elements[2].text == "Meaning 🌱")
        #expect(wrapped.elements[2].frameId == "f")
    }

    @Test func exactSelectionDoesNotLeakOtherElementsOrEmbeddedFiles() throws {
        let model = try ImpressExcalidrawScene.parse(Data(rawJSON.utf8),
            format: .excalidrawJSON)
        let one = try model.selection(ids: ["a"])
        #expect(one.elements.map(\.id) == ["a"])
        let payload = try one.textContextJSON()
        #expect(!payload.contains("Never in implicit source"))
        #expect(!payload.contains("Meaning 🌱"))
        #expect(payload.contains("group-one"))
        #expect(!payload.contains("data:image"))
    }

    @Test func explicitExpansionIncludesGroupPeersAndFrameChildren() throws {
        let model = try ImpressExcalidrawScene.parse(Data(rawJSON.utf8),
            format: .excalidrawJSON)
        let group = try model.selection(ids: ["a"], expandGroups: true)
        #expect(group.elements.map(\.id) == ["a","b"])
        let frame = try model.selection(ids: ["f"], expandGroups: true)
        #expect(frame.elements.map(\.id) == ["f","a","b"])
        #expect(!frame.elementIDs.contains("outside"))
    }

    @Test func compressedPayloadIsNotMisrepresentedAsPlainJSON() throws {
        let grave = String(Character(UnicodeScalar(96)!))
        let markdown = "# Drawing\n" + String(repeating: grave, count: 3) +
            "compressed-json\nabc\n" + String(repeating: grave, count: 3)
        #expect(throws: ImpressExcalidrawReadError.compressedDataUnsupported) {
            try ImpressExcalidrawScene.parse(Data(markdown.utf8),
                format: .excalidrawMarkdown)
        }
    }

    @Test func duplicateIDsAndInvalidGeometryFailClosed() throws {
        let corrupt = """
        {"type":"excalidraw","elements":[
          {"id":"same","type":"text","x":0,"y":0,"width":2,"height":2},
          {"id":"same","type":"text","x":3,"y":3,"width":2,"height":2}]}
        """
        #expect(throws: ImpressExcalidrawReadError.duplicateID) {
            try ImpressExcalidrawScene.parse(Data(corrupt.utf8),
                format: .excalidrawJSON)
        }
        #expect(throws: ImpressExcalidrawReadError.emptySelection) {
            try ImpressExcalidrawScene.parse(Data(rawJSON.utf8),
                format: .excalidrawJSON).selection(ids: ["not-present"])
        }
    }
}

