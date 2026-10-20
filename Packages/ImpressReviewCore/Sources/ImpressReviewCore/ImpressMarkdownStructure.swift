import Foundation

/// Byte-preserving structure of one already-authorized Markdown source.
/// rawUTF8 is an exact substring; trimmed text is not a writable replacement.
public struct ImpressMarkdownSection: Sendable, Equatable {
    public let id: String
    public let heading: String
    public let level: Int
    public let parentID: String?
    public let startUTF8: Int
    public let endUTF8: Int
    public let text: String
    public let rawUTF8: String

    public var byteCount: Int { endUTF8 - startUTF8 }
}

public enum ImpressMarkdownStructure {
    private struct Line {
        let start: Int
        let end: Int
        let body: String
    }
    private struct Marker {
        let start: Int
        let heading: String
        let level: Int
    }
    private struct Fence {
        let marker: Character
        let width: Int
    }

    /// Split raw LF, CRLF or CR; never normalize the source or UTF-8 offsets.
    private static func lines(in bytes: [UInt8]) -> [Line] {
        guard !bytes.isEmpty else { return [] }
        var result: [Line] = []
        var index = 0
        while index < bytes.count {
            let start = index
            while index < bytes.count && bytes[index] != 10 && bytes[index] != 13 {
                index += 1
            }
            let body = String(decoding: bytes[start..<index], as: UTF8.self)
            if index < bytes.count {
                let first = bytes[index]
                index += 1
                if first == 13 && index < bytes.count && bytes[index] == 10 {
                    index += 1
                }
            }
            result.append(Line(start: start, end: index, body: body))
        }
        return result
    }

    private static func rootContent(_ line: String) -> String? {
        let spaces = line.prefix(while: { $0 == " " }).count
        guard spaces <= 3 else { return nil }
        return String(line.dropFirst(spaces))
    }

    private static func atx(_ line: String) -> (Int, String)? {
        guard let root = rootContent(line), root.first == "#" else { return nil }
        let hashes = root.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(hashes) else { return nil }
        let remainder = root.dropFirst(hashes)
        guard remainder.isEmpty || remainder.first == " " ||
              remainder.first == "\t" else { return nil }
        var label = String(remainder).trimmingCharacters(in: .whitespaces)
        // Optional closing sequence: whitespace followed by one or more hashes.
        if let hash = label.lastIndex(of: "#") {
            let suffix = label[hash...]
            if suffix.allSatisfy({ $0 == "#" }) {
                let front = label[..<hash]
                if front.last == " " || front.last == "\t" {
                    label = String(front).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return (hashes, label)
    }

    private static func setext(_ line: String) -> Int? {
        guard let root = rootContent(line) else { return nil }
        let text = root.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        if text.allSatisfy({ $0 == "=" }) { return 1 }
        if text.allSatisfy({ $0 == "-" }) { return 2 }
        return nil
    }

    private static func fenceOpen(_ line: String) -> Fence? {
        let backtick = Character(UnicodeScalar(96)!)
        guard let root = rootContent(line), let marker = root.first,
              marker == backtick || marker == "~" else { return nil }
        let width = root.prefix(while: { $0 == marker }).count
        guard width >= 3 else { return nil }
        if marker == backtick && root.dropFirst(width).contains(backtick) { return nil }
        return Fence(marker: marker, width: width)
    }

    private static func fenceCloses(_ line: String, opener: Fence) -> Bool {
        guard let root = rootContent(line), root.first == opener.marker else { return false }
        let width = root.prefix(while: { $0 == opener.marker }).count
        return width >= opener.width &&
            root.dropFirst(width).trimmingCharacters(in: .whitespaces).isEmpty
    }

    private static func eligibleSetextTitle(_ line: String) -> Bool {
        guard let root = rootContent(line) else { return false }
        let value = root.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty, atx(line) == nil,
              !value.hasPrefix(">"), !value.hasPrefix("<!--"),
              !value.hasPrefix("|"), !value.hasPrefix("- "),
              !value.hasPrefix("* "), !value.hasPrefix("+ "),
              !value.hasPrefix("1. "), !value.hasPrefix("1) ") else { return false }
        return true
    }

    /// ATX/Setext, jumping levels and duplicated headings use source byte
    /// ranges, not the heading's text, as the authoritative locator.
    /// A parent contains descendants until the next same/higher-level heading.
    public static func sections(in markdown: String) -> [ImpressMarkdownSection] {
        let bytes = Array(markdown.utf8)
        let lines = lines(in: bytes)
        guard !lines.isEmpty else { return [] }
        var markers: [Marker] = []
        var fence: Fence?
        var inComment = false
        var inFrontmatter = false
        let first = lines[0].body.replacingOccurrences(of: "\u{FEFF}", with: "")
            .trimmingCharacters(in: .whitespaces)
        if first == "---" { inFrontmatter = true }
        var previousEligible = false

        for index in lines.indices {
            let line = lines[index]
            var body = line.body
            if index == 0 && body.hasPrefix("\u{FEFF}") {
                body.removeFirst()
            }
            let stripped = body.trimmingCharacters(in: .whitespaces)
            if inFrontmatter {
                if index > 0 && (stripped == "---" || stripped == "...") {
                    inFrontmatter = false
                }
                previousEligible = false
                continue
            }
            if inComment {
                if let end = body.range(of: "-->") {
                    body = String(body[end.upperBound...])
                    inComment = false
                } else {
                    previousEligible = false
                    continue
                }
            }
            if let start = body.range(of: "<!--") {
                if let end = body.range(of: "-->", range: start.upperBound..<body.endIndex) {
                    body.removeSubrange(start.lowerBound..<end.upperBound)
                } else {
                    inComment = true
                    body = String(body[..<start.lowerBound])
                }
            }
            if let existing = fence {
                if fenceCloses(body, opener: existing) { fence = nil }
                previousEligible = false
                continue
            }
            if let opener = fenceOpen(body) {
                fence = opener
                previousEligible = false
                continue
            }
            if let level = setext(body), previousEligible && index > 0 {
                let previous = lines[index - 1].body
                markers.append(Marker(start: lines[index - 1].start,
                    heading: previous.trimmingCharacters(in: .whitespaces),
                    level: level))
                previousEligible = false
                continue
            }
            if let heading = atx(body) {
                markers.append(Marker(start: line.start,
                    heading: heading.1, level: heading.0))
                previousEligible = false
                continue
            }
            previousEligible = !inComment && eligibleSetextTitle(body)
        }

        func original(_ start: Int, _ end: Int) -> String {
            String(decoding: bytes[start..<end], as: UTF8.self)
        }
        var sections: [ImpressMarkdownSection] = []
        let firstStart = markers.first?.start ?? bytes.count
        if firstStart > 0 {
            let prefix = original(0, firstStart)
            let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                sections.append(ImpressMarkdownSection(id: "section-0",
                    heading: "全文", level: 0, parentID: nil,
                    startUTF8: 0, endUTF8: firstStart, text: trimmed,
                    rawUTF8: prefix))
            }
        }
        var ancestors: [(level: Int, id: String)] = []
        for (index, marker) in markers.enumerated() {
            while let last = ancestors.last, last.level >= marker.level {
                ancestors.removeLast()
            }
            let parent = ancestors.last?.id
            var end = bytes.count
            for next in markers.dropFirst(index + 1) where next.level <= marker.level {
                end = next.start
                break
            }
            let raw = original(marker.start, end)
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            let id = "section-\(sections.count)"
            sections.append(ImpressMarkdownSection(id: id,
                heading: marker.heading, level: marker.level, parentID: parent,
                startUTF8: marker.start, endUTF8: end, text: trimmed,
                rawUTF8: raw))
            ancestors.append((level: marker.level, id: id))
        }
        return sections
    }

    /// Co-selecting parent+child never duplicates sent content.
    public static func effectiveSelection(_ sections: [ImpressMarkdownSection],
                                          selectedIDs: Set<String>) -> [ImpressMarkdownSection] {
        let chosen = sections.filter { selectedIDs.contains($0.id) }
            .sorted {
                if $0.startUTF8 != $1.startUTF8 { return $0.startUTF8 < $1.startUTF8 }
                return $0.endUTF8 > $1.endUTF8
            }
        var effective: [ImpressMarkdownSection] = []
        for item in chosen where !effective.contains(where: {
            $0.startUTF8 <= item.startUTF8 && item.endUTF8 <= $0.endUTF8
        }) {
            effective.append(item)
        }
        return effective
    }
}