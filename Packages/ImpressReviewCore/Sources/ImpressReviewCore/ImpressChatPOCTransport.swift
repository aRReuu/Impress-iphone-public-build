import Foundation

/// Zero-network transport contract used by the Chat renderer POC.
/// Decode raw UTF-8 bytes before interpreting SSE: a network read may end
/// in the middle of a Chinese glyph, emoji, CRLF or JSON string.
public enum ImpressChatPOCTransportError: Error, Equatable, Sendable {
    case tooLarge, invalidUTF8, malformedJSON, invalidEvent, unexpectedAfterTerminal
}

public struct ImpressChatPOCSSEEvent: Equatable, Sendable {
    public let event: String?
    public let id: String?
    public let data: String
    public init(event: String?, id: String?, data: String) {
        self.event = event
        self.id = id
        self.data = data
    }
}

public struct ImpressChatPOCSSEDecoder: Sendable {
    public static let maximumBufferBytes = 256 * 1024
    public private(set) var dispatchedCount = 0
    private var buffer = Data()
    private var lines: [String] = []
    private var activeEvent: String?
    private var activeID: String?
    private var dataBytes = 0

    public init() {}

    /// Arbitrary fragmented reads, including a single byte per call.
    public mutating func append(_ bytes: Data) throws -> [ImpressChatPOCSSEEvent] {
        guard buffer.count + bytes.count <= Self.maximumBufferBytes else {
            throw ImpressChatPOCTransportError.tooLarge
        }
        buffer.append(bytes)
        var produced: [ImpressChatPOCSSEEvent] = []
        while let delimiter = Self.findLineDelimiter(in: buffer) {
            let data = Data(buffer.prefix(delimiter.offset))
            buffer.removeSubrange(0..<delimiter.end)
            try consumeLine(data, into: &produced)
        }
        return produced
    }

    /// End of socket is *not* a completion signal for the AI response.
    /// This only drains a final unterminated line/event; the consumer still
    /// requires a provider-specific explicit terminal event.
    public mutating func finish() throws -> [ImpressChatPOCSSEEvent] {
        var produced: [ImpressChatPOCSSEEvent] = []
        if !buffer.isEmpty {
            let remaining = buffer
            buffer.removeAll()
            try consumeLine(remaining, into: &produced)
        }
        dispatch(into: &produced)
        return produced
    }

    private static func findLineDelimiter(in bytes: Data) -> (offset: Int, end: Int)? {
        for (index, byte) in bytes.enumerated() {
            if byte == 10 { return (index, index + 1) }
            if byte == 13 {
                guard index + 1 < bytes.count else { return nil }
                return (index, bytes[index + 1] == 10 ? index + 2 : index + 1)
            }
        }
        return nil
    }

    private mutating func consumeLine(
        _ bytes: Data, into output: inout [ImpressChatPOCSSEEvent]
    ) throws {
        guard let line = String(data: bytes, encoding: .utf8),
              !line.unicodeScalars.contains(where: { $0.value == 0 })
        else { throw ImpressChatPOCTransportError.invalidUTF8 }
        guard !line.isEmpty else { dispatch(into: &output); return }
        if line.hasPrefix(":") { return } // standard SSE keepalive
        let head = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let key = String(head.first ?? "")
        var value = head.count == 2 ? String(head[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }
        switch key {
        case "event":
            guard value.utf8.count <= 128 else { throw ImpressChatPOCTransportError.tooLarge }
            activeEvent = value
        case "id":
            guard !value.contains("\u{0000}"), value.utf8.count <= 1024
            else { throw ImpressChatPOCTransportError.invalidEvent }
            activeID = value
        case "data":
            dataBytes += value.utf8.count + 1
            guard dataBytes <= Self.maximumBufferBytes else {
                throw ImpressChatPOCTransportError.tooLarge
            }
            lines.append(value)
        default:
            break // retry/unknown fields are not model content
        }
    }

    private mutating func dispatch(into output: inout [ImpressChatPOCSSEEvent]) {
        if !lines.isEmpty {
            output.append(ImpressChatPOCSSEEvent(
                event: activeEvent, id: activeID, data: lines.joined(separator: "\n")))
            dispatchedCount += 1
        }
        activeEvent = nil
        activeID = nil
        lines.removeAll(keepingCapacity: true)
        dataBytes = 0
    }
}

public enum ImpressChatPOCProviderProtocol: Sendable {
    case openAIChat, openAIResponses, anthropicMessages, geminiGenerateContent
}

public enum ImpressChatPOCOutput: Equatable, Sendable {
    case delta(String)
    case completed
    case failed
}

/// Provider-specific events have one common UI contract. No HTTP or keys.
/// A missing explicit terminal event is *never* converted to completed.
public struct ImpressChatPOCEventNormalizer: Sendable {
    public let provider: ImpressChatPOCProviderProtocol
    public private(set) var isCompleted = false
    public private(set) var isFailed = false
    private var lastGeminiSnapshot = ""

    public init(provider: ImpressChatPOCProviderProtocol) { self.provider = provider }

    public mutating func consume(
        _ event: ImpressChatPOCSSEEvent
    ) throws -> [ImpressChatPOCOutput] {
        guard !isCompleted && !isFailed else {
            // Repeated terminal events, including [DONE], are harmless.
            if event.data == "[DONE]" { return [] }
            throw ImpressChatPOCTransportError.unexpectedAfterTerminal
        }
        if event.data == "[DONE]" { return terminal() }
        if event.event == "error" || event.event == "response.failed" {
            isFailed = true
            return [.failed]
        }
        guard let object = try JSONSerialization.jsonObject(
            with: Data(event.data.utf8)) as? [String: Any] else {
            throw ImpressChatPOCTransportError.malformedJSON
        }
        if object["error"] != nil {
            isFailed = true
            return [.failed]
        }
        switch provider {
        case .openAIChat:
            guard let choice = (object["choices"] as? [[String: Any]])?.first
            else { return [] } // role-only metadata
            var events: [ImpressChatPOCOutput] = []
            if let delta = choice["delta"] as? [String: Any],
               let text = delta["content"] as? String, !text.isEmpty {
                events.append(.delta(text))
            }
            if let reason = choice["finish_reason"] as? String, !reason.isEmpty {
                events += terminal()
            }
            return events
        case .openAIResponses:
            let type = event.event ?? (object["type"] as? String ?? "")
            if type == "response.completed" { return terminal() }
            if type == "response.failed" {
                isFailed = true
                return [.failed]
            }
            if type == "response.output_text.delta",
               let text = object["delta"] as? String, !text.isEmpty {
                return [.delta(text)]
            }
            return []
        case .anthropicMessages:
            let type = event.event ?? (object["type"] as? String ?? "")
            if type == "message_stop" { return terminal() }
            if type == "content_block_delta",
               let delta = object["delta"] as? [String: Any],
               delta["type"] as? String == "text_delta",
               let text = delta["text"] as? String, !text.isEmpty {
                return [.delta(text)]
            }
            return []
        case .geminiGenerateContent:
            guard let candidate = (object["candidates"] as? [[String: Any]])?.first
            else { return [] }
            let content = candidate["content"] as? [String: Any]
            let parts = content?["parts"] as? [[String: Any]] ?? []
            let cumulative = parts.compactMap { $0["text"] as? String }.joined()
            var output: [ImpressChatPOCOutput] = []
            if cumulative.hasPrefix(lastGeminiSnapshot) {
                let next = String(cumulative.dropFirst(lastGeminiSnapshot.count))
                if !next.isEmpty { output.append(.delta(next)) }
                lastGeminiSnapshot = cumulative
            } else {
                // A revision/rewind cannot be appended as a duplicate delta.
                throw ImpressChatPOCTransportError.invalidEvent
            }
            if let reason = candidate["finishReason"] as? String, !reason.isEmpty {
                output += terminal()
            }
            return output
        }
    }

    private mutating func terminal() -> [ImpressChatPOCOutput] {
        guard !isCompleted else { return [] }
        isCompleted = true
        return [.completed]
    }
}

/// An explicit bounded offline wire replay for deterministic UIKit tests.
public struct ImpressChatPOCReplay: Sendable {
    public var decoder = ImpressChatPOCSSEDecoder()
    public var normalizer: ImpressChatPOCEventNormalizer

    public init(provider: ImpressChatPOCProviderProtocol) {
        normalizer = ImpressChatPOCEventNormalizer(provider: provider)
    }

    public mutating func append(_ bytes: Data) throws -> [ImpressChatPOCOutput] {
        try decoder.append(bytes).flatMap { event in try normalizer.consume(event) }
    }

    public mutating func finish() throws -> [ImpressChatPOCOutput] {
        try decoder.finish().flatMap { event in try normalizer.consume(event) }
    }
}
