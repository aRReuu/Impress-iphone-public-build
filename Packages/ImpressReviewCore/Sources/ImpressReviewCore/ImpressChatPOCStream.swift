import Foundation

/// Offline-only typed streaming proof of concept. No HTTP, Vault or WCDB.
public struct ImpressChatPOCBlock: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case paragraph, heading, list, quote, code, table, math, divider
    }
    public let id: Int
    public let kind: Kind
    public let markdown: String
    public let headingLevel: Int
    public let stable: Bool
    public init(id: Int, kind: Kind, markdown: String,
                headingLevel: Int = 0, stable: Bool) {
        self.id = id; self.kind = kind; self.markdown = markdown
        self.headingLevel = headingLevel; self.stable = stable
    }
}

public enum ImpressChatPOCPhase: String, Sendable {
    case idle, streaming, completed, stopped, failed
}

/// Blank lines outside code/math finalize immutable blocks. Only the tail
/// is reclassified on new tokens; incomplete output never becomes completed.
public struct ImpressChatPOCStream: Sendable {
    public private(set) var phase: ImpressChatPOCPhase = .idle
    public private(set) var source = ""
    public private(set) var blocks: [ImpressChatPOCBlock] = []
    public private(set) var lastReparsedUTF8Count = 0
    private var fixed: [ImpressChatPOCBlock] = []
    private var tail = ""

    public init() {}
    public mutating func start() {
        source = ""; blocks = []; fixed = []; tail = ""
        lastReparsedUTF8Count = 0; phase = .streaming
    }
    public mutating func append(_ fragment: String) {
        guard phase == .streaming, !fragment.isEmpty else { return }
        source += fragment; tail += fragment
        if let point = Self.lastSafeBoundary(in: tail) {
            fixed += Self.parse(String(tail[..<point]), offset: fixed.count, stable: true)
            tail = String(tail[point...])
        }
        lastReparsedUTF8Count = tail.utf8.count
        blocks = fixed + Self.parse(tail, offset: fixed.count, stable: false)
    }
    public mutating func finish() {
        guard phase == .streaming else { return }
        fixed += Self.parse(tail, offset: fixed.count, stable: true)
        blocks = fixed; tail = ""; lastReparsedUTF8Count = 0; phase = .completed
    }
    public mutating func stop() { if phase == .streaming { phase = .stopped } }
    public mutating func fail() { if phase == .streaming { phase = .failed } }
    public static func parseOnce(_ source: String) -> [ImpressChatPOCBlock] {
        parse(source, offset: 0, stable: true)
    }
    private static func isFence(_ line: String) -> Bool {
        line.hasPrefix("~~~") || line.hasPrefix("\u{60}\u{60}\u{60}")
    }
    private static func lastSafeBoundary(in text: String) -> String.Index? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        var cursor = text.startIndex
        var code = false, math = false
        var last: String.Index?
        for (i, raw) in lines.enumerated() {
            let s = String(raw), t = s.trimmingCharacters(in: .whitespaces)
            if isFence(t) { code.toggle() }
            else if !code && t.hasPrefix("$$") &&
                    !(t.count > 2 && t.hasSuffix("$$")) { math.toggle() }
            cursor = text.index(cursor, offsetBy: s.count)
            if i < lines.count - 1 {
                cursor = text.index(after: cursor)
                if t.isEmpty && !code && !math { last = cursor }
            }
        }
        return last
    }
    private static func headingDepth(_ s: String) -> Int {
        let n = s.prefix(while: { $0 == "#" }).count
        return (1...6).contains(n) && s.dropFirst(n).first == " " ? n : 0
    }
    private static func isList(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("- ") || t.hasPrefix("* ") || t.hasPrefix("+ ") { return true }
        let digits = t.prefix(while: { $0.isNumber })
        return !digits.isEmpty && (t.dropFirst(digits.count).hasPrefix(". ") ||
                                  t.dropFirst(digits.count).hasPrefix(") "))
    }
    private static func classify(_ s: String) -> (ImpressChatPOCBlock.Kind, Int) {
        let lines = s.split(separator: "\n", omittingEmptySubsequences: false)
        let first = String(lines.first ?? "").trimmingCharacters(in: .whitespaces)
        let depth = headingDepth(first)
        if depth > 0 { return (.heading, depth) }
        if isFence(first) { return (.code, 0) }
        if first.hasPrefix("$$") { return (.math, 0) }
        if ["---", "***", "___"].contains(first) { return (.divider, 0) }
        if first.hasPrefix(">") { return (.quote, 0) }
        if isList(first) { return (.list, 0) }
        if lines.count > 1 && first.contains("|") {
            let separator = String(lines[1])
            let stripped = separator.replacingOccurrences(of: "|", with: "")
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: ":", with: "")
                .trimmingCharacters(in: .whitespaces)
            if separator.contains("---") && stripped.isEmpty { return (.table, 0) }
        }
        return (.paragraph, 0)
    }
    private static func parse(_ input: String, offset: Int,
                              stable: Bool) -> [ImpressChatPOCBlock] {
        var result: [ImpressChatPOCBlock] = [], pending: [String] = []
        var code = false, math = false
        func add(_ text: String) {
            guard !text.isEmpty else { return }
            let (kind, depth) = classify(text)
            result.append(ImpressChatPOCBlock(id: offset + result.count, kind: kind,
                                               markdown: text, headingLevel: depth, stable: stable))
        }
        func flush() {
            let text = pending.joined(separator: "\n").trimmingCharacters(in: .newlines)
            pending = []
            if text.isEmpty { return }
            if isFence(text) || text.hasPrefix("$$") { add(text); return }
            var chunk: [String] = []
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let row = String(line)
                if headingDepth(row) > 0 {
                    if !chunk.isEmpty { add(chunk.joined(separator: "\n")); chunk = [] }
                    add(row)
                } else { chunk.append(row) }
            }
            if !chunk.isEmpty { add(chunk.joined(separator: "\n")) }
        }
        for raw in input.split(separator: "\n", omittingEmptySubsequences: false) {
            let s = String(raw), t = s.trimmingCharacters(in: .whitespaces)
            if t.isEmpty && !code && !math { flush(); continue }
            pending.append(s)
            if isFence(t) { code.toggle() }
            else if !code && t.hasPrefix("$$") &&
                    !(t.count > 2 && t.hasSuffix("$$")) { math.toggle() }
        }
        flush()
        return result
    }
}
