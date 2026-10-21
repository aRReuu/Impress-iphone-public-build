import Foundation

public enum ImpressDiagramKind: String, Codable, Sendable { case mermaid, markmap }
public enum ImpressDiagramError: Error, Equatable { case invalidDocument, tooLarge, invalidSelection, empty }
public struct ImpressDiagramNode: Codable, Sendable, Equatable {
    public let id: String
    public let title: String
    /// Only this node's source text, excluding unselected sibling branches.
    /// The complete Markdown remains authoritative solely in the Vault.
    public let ownSourceText: String
    public let parentID: String?
    public let startUTF8: Int
    public let endUTF8: Int
}
public struct ImpressDiagramSelection: Sendable {
    public let ids: [String]
    public let ancestors: [String]
    public let nodes: [ImpressDiagramNode]
    public let kind: ImpressDiagramKind
    public let scopeStartUTF8: Int
    public let scopeEndUTF8: Int
    public func contextJSON() throws -> String {
        struct Payload: Encodable {
            let kind: String
            let selectedNodeIDs: [String]
            let requiredAncestorIDs: [String]
            let scopeStartUTF8: Int
            let scopeEndUTF8: Int
            let nodes: [ImpressDiagramNode]
        }
        let payload = Payload(kind: kind.rawValue, selectedNodeIDs: ids,
            requiredAncestorIDs: ancestors, scopeStartUTF8: scopeStartUTF8,
            scopeEndUTF8: scopeEndUTF8, nodes: nodes)
        let coder = JSONEncoder()
        coder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let bytes = try coder.encode(payload)
        guard bytes.count <= 40_000, let text = String(data: bytes, encoding: .utf8)
        else { throw ImpressDiagramError.tooLarge }
        return text
    }
}

/// Portable projection; displays never become a source of writable bytes.
/// Reader input is the actual authorized Vault byte buffer, including BOM.
public struct ImpressDiagramDocument: Sendable {
    public let kind: ImpressDiagramKind
    public let startUTF8: Int
    public let endUTF8: Int
    public let rendererText: String
    public let nodes: [ImpressDiagramNode]

    private struct Line { let start: Int; let end: Int; let text: String }
    private static func lines(_ bytes: [UInt8]) -> [Line] {
        var output: [Line] = []
        var position = 0
        while position < bytes.count {
            let start = position
            while position < bytes.count && bytes[position] != 10 && bytes[position] != 13 {
                position += 1
            }
            let body = String(decoding: bytes[start..<position], as: UTF8.self)
            if position < bytes.count {
                let isCR = bytes[position] == 13
                position += 1
                if isCR && position < bytes.count && bytes[position] == 10 { position += 1 }
            }
            output.append(Line(start: start, end: position, text: body))
        }
        return output
    }
    private struct Fence { let character: Character; let width: Int; let language: String }
    private static func open(_ text: String) -> Fence? {
        let spaces = text.prefix(while: { $0 == " " }).count
        guard spaces <= 3 else { return nil }
        let line = text.dropFirst(spaces)
        guard let mark = line.first,
              mark == "~" || mark == Character(UnicodeScalar(96)!) else { return nil }
        let width = line.prefix(while: { $0 == mark }).count
        guard width >= 3 else { return nil }
        return Fence(character: mark, width: width,
            language: line.dropFirst(width).trimmingCharacters(in: .whitespaces).lowercased())
    }
    private static func closes(_ text: String, _ fence: Fence) -> Bool {
        let line = text.trimmingCharacters(in: .whitespaces)
        return line.prefix(while: { $0 == fence.character }).count >= fence.width &&
            line.drop(while: { $0 == fence.character }).isEmpty
    }

    public static func mermaidBlocks(in bytes: Data) throws -> [Self] {
        guard !bytes.isEmpty, bytes.count <= 8 * 1_024 * 1_024,
              String(data: bytes, encoding: .utf8) != nil else {
            throw ImpressDiagramError.invalidDocument
        }
        let raw = Array(bytes), rows = lines(raw)
        var blocks: [Self] = []
        var fence: Fence?
        var openingAt = 0, contentsAt = 0
        var frontmatter = rows.first?.text.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespaces) == "---"
        for (index, row) in rows.enumerated() {
            if frontmatter {
                if index > 0 && row.text.trimmingCharacters(in: .whitespaces) == "---" {
                    frontmatter = false
                }
                continue
            }
            if let active = fence {
                if closes(row.text, active) {
                    if active.language == "mermaid" {
                        let end = row.start
                        let value = String(decoding: raw[contentsAt..<end], as: UTF8.self)
                        let nodes = mermaidNodes(value, start: contentsAt)
                        blocks.append(Self(kind: .mermaid, startUTF8: openingAt,
                            endUTF8: row.end, rendererText: value, nodes: nodes))
                    }
                    fence = nil
                }
            } else if let next = open(row.text) {
                fence = next
                openingAt = row.start
                contentsAt = row.end
            }
        }
        return blocks
    }
    private static func mermaidNodes(_ text: String, start: Int) -> [ImpressDiagramNode] {
        var result: [ImpressDiagramNode] = []
        var stack: [(Int, String)] = []
        for line in lines(Array(text.utf8)) {
            let trimmed = line.text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("%%"),
                  !trimmed.hasPrefix("flowchart "), !trimmed.hasPrefix("graph "),
                  trimmed != "mindmap", !trimmed.hasPrefix("direction "),
                  trimmed != "end", !trimmed.hasPrefix("click "),
                  !trimmed.hasPrefix("classDef "), !trimmed.hasPrefix("style "),
                  !trimmed.hasPrefix("linkStyle ") else { continue }
            let indent = line.text.prefix(while: { $0 == " " || $0 == "\t" })
                .reduce(0) { $0 + ($1 == "\t" ? 4 : 1) }
            while let previous = stack.last, previous.0 >= indent { stack.removeLast() }
            let id = "m:" + String(start + line.start)
            result.append(ImpressDiagramNode(id: id, title: String(trimmed.prefix(500)),
                ownSourceText: trimmed, parentID: stack.last?.1, startUTF8: start + line.start,
                endUTF8: start + line.end))
            stack.append((indent, id))
            if result.count == 512 { break }
        }
        return result
    }
    public static func markmap(in bytes: Data) throws -> Self {
        guard !bytes.isEmpty, bytes.count <= 8 * 1_024 * 1_024,
              String(data: bytes, encoding: .utf8) != nil else {
            throw ImpressDiagramError.invalidDocument
        }
        let source = String(decoding: bytes, as: UTF8.self)
        let sections = ImpressMarkdownStructure.sections(in: source)
        let lookup = Dictionary(uniqueKeysWithValues: sections.map {
            ($0.id, "h:" + String($0.startUTF8))
        })
        let original = Array(bytes)
        let nodes = sections.prefix(512).map { section in
            // A parent section's endUTF8 includes all children. A node's
            // own material ends BEFORE its first direct child, so choosing
            // that parent alone cannot leak the entire unselected subtree.
            let childStart = sections.filter { $0.parentID == section.id }
                .map(\.startUTF8).min() ?? section.endUTF8
            let own = String(decoding: original[section.startUTF8..<childStart],
                as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            return ImpressDiagramNode(
                id: lookup[section.id] ?? "h:" + String(section.startUTF8),
                title: section.heading, ownSourceText: own,
                parentID: section.parentID.flatMap { lookup[$0] },
                startUTF8: section.startUTF8, endUTF8: section.endUTF8)
        }
        guard !nodes.isEmpty else { throw ImpressDiagramError.empty }
        return Self(kind: .markmap, startUTF8: 0, endUTF8: bytes.count,
            rendererText: source.hasPrefix("\u{FEFF}") ? String(source.dropFirst()) : source,
            nodes: nodes)
    }
    public func selection(ids: Set<String>, includeDescendants: Bool = false)
        throws -> ImpressDiagramSelection {
        let lookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        guard !ids.isEmpty, ids.allSatisfy({ lookup[$0] != nil }) else {
            throw ImpressDiagramError.invalidSelection
        }
        var selected = ids
        if includeDescendants {
            for _ in 0..<nodes.count {
                let before = selected.count
                for node in nodes where node.parentID.map({ selected.contains($0) }) ?? false {
                    selected.insert(node.id)
                }
                if selected.count == before { break }
            }
        }
        var ancestors = Set<String>()
        for id in selected {
            var parent = lookup[id]?.parentID
            var visited = Set<String>()
            while let key = parent, visited.insert(key).inserted, let value = lookup[key] {
                if !selected.contains(key) { ancestors.insert(key) }
                parent = value.parentID
            }
        }
        let included = selected.union(ancestors)
        return ImpressDiagramSelection(ids: selected.sorted(), ancestors: ancestors.sorted(),
            nodes: nodes.filter { included.contains($0.id) }, kind: kind,
            scopeStartUTF8: startUTF8, scopeEndUTF8: endUTF8)
    }
}
