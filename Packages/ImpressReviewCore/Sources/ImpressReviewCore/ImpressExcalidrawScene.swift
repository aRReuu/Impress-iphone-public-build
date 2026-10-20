import Foundation

/// Read-only Excalidraw scene adapter. Source bytes remain owned by the
/// authorized Vault; no Obsidian plugin scripts or file embeds are executed.
/// Plain .excalidraw JSON and uncompressed Drawing json fenced blocks from
/// .excalidraw.md use the same immutable parser.
public enum ImpressExcalidrawReadError: Error, Equatable {
    case invalidScene, missingDrawing, compressedDataUnsupported,
         duplicateID, invalidGeometry, tooLarge, emptySelection
}

public struct ImpressExcalidrawElement: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let angle: Double?
    public let strokeColor: String?
    public let backgroundColor: String?
    public let strokeWidth: Double?
    public let opacity: Double?
    public let text: String?
    public let points: [[Double]]?
    public let groupIds: [String]?
    public let frameId: String?
    public let fileId: String?
    public let isDeleted: Bool?

    public var isActive: Bool { isDeleted != true }
}

public struct ImpressExcalidrawSelection: Sendable {
    public let elementIDs: Set<String>
    public let elements: [ImpressExcalidrawElement]

    /// Model context can describe explicitly chosen structures. Image
    /// pixels, binary attachments and other unselected objects are excluded.
    public func textContextJSON() throws -> String {
        struct Payload: Encodable {
            let elementIDs: [String]
            let elements: [ImpressExcalidrawElement]
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let data = try encoder.encode(Payload(
            elementIDs: elementIDs.sorted(), elements: elements))
        guard data.count <= 40_000,
              let output = String(data: data, encoding: .utf8) else {
            throw ImpressExcalidrawReadError.tooLarge
        }
        return output
    }
}

public struct ImpressExcalidrawScene: Decodable, Sendable {
    public let type: String?
    public let version: Int?
    public let elements: [ImpressExcalidrawElement]

    private static let fence = String(Character(UnicodeScalar(96)!))

    /// Parsing never evaluates SVG/HTML, fetches external images, performs
    /// writes or decompresses untrusted payloads through a network service.
    public static func parse(_ bytes: Data,
                             format: ImVaultDocumentFormat) throws -> Self {
        guard bytes.count <= 8 * 1024 * 1024,
              let text = String(data: bytes, encoding: .utf8) else {
            throw ImpressExcalidrawReadError.tooLarge
        }
        let json: String
        switch format {
        case .excalidrawJSON:
            json = text
        case .excalidrawMarkdown:
            let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
                .components(separatedBy: "\n")
            var inDrawing = false
            var collecting = false
            var captured: [String] = []
            var found = false
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !collecting {
                    if trimmed.hasPrefix("#") &&
                       trimmed.drop(while: { $0 == "#" })
                        .trimmingCharacters(in: .whitespaces) == "Drawing" {
                        inDrawing = true
                        continue
                    }
                    if !inDrawing { continue }
                    if trimmed == Self.fence.repeatElement(3) + "compressed-json" {
                        throw ImpressExcalidrawReadError.compressedDataUnsupported
                    }
                    if trimmed == Self.fence.repeatElement(3) + "json" {
                        collecting = true
                        captured = []
                    }
                    continue
                }
                if trimmed == Self.fence.repeatElement(3) {
                    found = true
                    break
                }
                captured.append(line)
            }
            guard found else { throw ImpressExcalidrawReadError.missingDrawing }
            json = captured.joined(separator: "\n")
        default:
            throw ImpressExcalidrawReadError.invalidScene
        }
        guard let data = json.data(using: .utf8) else {
            throw ImpressExcalidrawReadError.invalidScene
        }
        let parsed: Self
        do { parsed = try JSONDecoder().decode(Self.self, from: data) }
        catch { throw ImpressExcalidrawReadError.invalidScene }
        guard parsed.type == nil || parsed.type == "excalidraw",
              parsed.elements.count <= 5_000 else {
            throw ImpressExcalidrawReadError.tooLarge
        }
        let ids = parsed.elements.map(\.id)
        guard ids.allSatisfy({ !$0.isEmpty && $0.utf8.count <= 256 }),
              Set(ids).count == ids.count else {
            throw ImpressExcalidrawReadError.duplicateID
        }
        for element in parsed.elements {
            guard element.x.isFinite, element.y.isFinite,
                  element.width.isFinite, element.height.isFinite,
                  (-10_000_000.0...10_000_000.0).contains(element.x),
                  (-10_000_000.0...10_000_000.0).contains(element.y),
                  (0.0...1_000_000.0).contains(element.width),
                  (0.0...1_000_000.0).contains(element.height),
                  element.text.map({ $0.utf8.count <= 400_000 }) ?? true,
                  element.points.map({ $0.count <= 20_000 &&
                    $0.allSatisfy { point in
                        point.count >= 2 && point[0].isFinite &&
                        point[1].isFinite }
                  }) ?? true else {
                throw ImpressExcalidrawReadError.invalidGeometry
            }
        }
        return parsed
    }

    /// Exact element selection is the default. Frame members and grouped
    /// elements only enter context after a separate visible user approval.
    public func selection(ids: Set<String>, expandGroups: Bool = false)
        throws -> ImpressExcalidrawSelection {
        let active = elements.filter(\.isActive)
        let chosen = active.filter { ids.contains($0.id) }
        guard !chosen.isEmpty, chosen.count == ids.count else {
            throw ImpressExcalidrawReadError.emptySelection
        }
        var effective = Set(chosen.map(\.id))
        if expandGroups {
            let groups = Set(chosen.flatMap { $0.groupIds ?? [] })
            let selectedFrames = Set(chosen.filter { $0.type == "frame" }.map(\.id))
            for element in active {
                if !(groups.isDisjoint(with: element.groupIds ?? [])) ||
                   (element.frameId.map { selectedFrames.contains($0) } ?? false) {
                    effective.insert(element.id)
                }
            }
        }
        return ImpressExcalidrawSelection(elementIDs: effective,
            elements: active.filter { effective.contains($0.id) })
    }
}

private extension String {
    func repeatElement(_ count: Int) -> String {
        String(repeating: self, count: count)
    }
}