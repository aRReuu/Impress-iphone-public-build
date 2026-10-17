import Foundation

/// Portable, no-I/O contracts for the V3.1 Obsidian synchronization gate.
/// No scheduler, WCDB, UIKit, Vault root or iCloud dependency.
public enum ImVaultCoreError: Error, Equatable {
    case invalidVaultIdentity
    case invalidRelativePath
    case modifiedSource
    case invalidDraft
    case oversizedFile
}

public struct ImVaultFileIdentity: Codable, Hashable, Sendable {
    public let vaultID: String
    public let relativePath: String

    public init(vaultID: String, relativePath: String) throws {
        let key = vaultID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, !key.contains("/"), !key.contains("\\"),
              !key.contains("\0") else { throw ImVaultCoreError.invalidVaultIdentity }
        let raw = relativePath.precomposedStringWithCanonicalMapping
        guard !raw.isEmpty, !raw.hasPrefix("/"), !raw.contains("\\"),
              !raw.contains("\0"), !raw.contains(":") else {
            throw ImVaultCoreError.invalidRelativePath
        }
        let segments = raw.split(separator: "/", omittingEmptySubsequences: false)
        guard !segments.isEmpty, segments.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." }),
              segments[0] != ".obsidian", raw.lowercased().hasSuffix(".md") else {
            throw ImVaultCoreError.invalidRelativePath
        }
        self.vaultID = key
        self.relativePath = raw
    }
}

public enum ImVaultWriteDecision: Equatable {
    case unchanged
    case safeToWrite
    case alreadyApplied
    case conflict
}

public enum ImVaultVersionGate {
    /// Re-hash the ACTUAL file bytes inside a coordinated write block, not the
    /// metadata timestamp. Neither two competing editors nor offline iCloud
    /// versions may silently replace a different local source revision.
    public static func decide(baseDigest: String, currentDigest: String,
                              proposedDigest: String) -> ImVaultWriteDecision {
        if proposedDigest == baseDigest { return .unchanged }
        if proposedDigest == currentDigest { return .alreadyApplied }
        if currentDigest != baseDigest { return .conflict }
        return .safeToWrite
    }
}

public struct ImVaultDraft: Codable, Equatable, Sendable {
    public let identity: ImVaultFileIdentity
    public let baseText: String
    /// Exact pre-edit file bytes, including any UTF-8 BOM/newline convention.
    public let baseRawData: Data
    public let baseDigest: String
    public var editedText: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(identity: ImVaultFileIdentity, baseText: String,
                baseRawData: Data? = nil, editedText: String? = nil,
                createdAt: Date = Date()) throws {
        guard baseText.utf8.count <= 8 * 1024 * 1024 else {
            throw ImVaultCoreError.oversizedFile
        }
        let originalBytes = baseRawData ?? Data(baseText.utf8)
        guard originalBytes.count <= 8 * 1024 * 1024,
              String(data: originalBytes, encoding: .utf8) == baseText else {
            throw ImVaultCoreError.invalidDraft
        }
        self.identity = identity
        self.baseText = baseText
        self.baseRawData = originalBytes
        self.baseDigest = ImVaultDigest.sha256(originalBytes)
        self.editedText = editedText ?? baseText
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    public mutating func update(_ newValue: String, at date: Date = Date()) throws {
        guard newValue.utf8.count <= 8 * 1024 * 1024 else {
            throw ImVaultCoreError.oversizedFile
        }
        editedText = newValue
        updatedAt = date
    }

    public func validate() throws {
        guard ImVaultDigest.sha256(baseRawData) == baseDigest,
              String(data: baseRawData, encoding: .utf8) == baseText,
              editedText.utf8.count <= 8 * 1024 * 1024 else {
            throw ImVaultCoreError.invalidDraft
        }
    }

    public func decision(against source: Data) -> ImVaultWriteDecision {
        ImVaultVersionGate.decide(baseDigest: baseDigest,
            currentDigest: ImVaultDigest.sha256(source),
            proposedDigest: ImVaultDigest.sha256(Data(editedText.utf8)))
    }

    public var hasChanges: Bool { baseText != editedText }
}

public enum ImVaultDiff {
    /// Bounded, lossless-text comparison for a user approval surface.
    /// Displays ALL differing middle lines up to the preview cap. When the
    /// preview is truncated, approval must remain disabled by the caller.
    public static func summary(base: String, edited: String, maximumLines: Int = 200) -> (text: String, complete: Bool) {
        let before = base.components(separatedBy: "\n")
        let after = edited.components(separatedBy: "\n")
        var prefix = 0
        while prefix < min(before.count, after.count) && before[prefix] == after[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix &&
                before[before.count - suffix - 1] == after[after.count - suffix - 1] {
            suffix += 1
        }
        let oldEnd = before.count - suffix, newEnd = after.count - suffix
        let removed = prefix < oldEnd ? Array(before[prefix..<oldEnd]).map { "- " + $0 } : []
        let added = prefix < newEnd ? Array(after[prefix..<newEnd]).map { "+ " + $0 } : []
        let all = removed + added
        guard !all.isEmpty else { return ("没有变更", true) }
        let cap = max(1, maximumLines)
        let shown = all.prefix(cap)
        let header = "变更区域从第 \(prefix + 1) 行开始。删除 \(removed.count) 行，新增 \(added.count) 行。\n"
        let complete = all.count <= cap
        return (header + shown.joined(separator: "\n") +
                (complete ? "" : "\n⚠ 变更预览已截断，禁止提交"), complete)
    }
}

/// Cryptographic content version: Apple CryptoKit on iOS and a portable
/// FIPS-180 SHA-256 implementation on Linux test runners.
public enum ImVaultDigest {
    public static func sha256(_ data: Data) -> String {
        #if canImport(CryptoKit)
        return CryptoKit.SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        #else
        return portableSHA256(Array(data)).map { String(format: "%02x", $0) }.joined()
        #endif
    }

    #if !canImport(CryptoKit)
    private static let roundConstants: [UInt32] = [
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    ]
    private static func ror(_ v: UInt32, _ n: UInt32) -> UInt32 {
        (v >> n) | (v << (32 - n))
    }
    private static func portableSHA256(_ input: [UInt8]) -> [UInt8] {
        var bytes = input
        let bitLength = UInt64(bytes.count) &* 8
        bytes.append(0x80)
        while bytes.count % 64 != 56 { bytes.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }
        var hash: [UInt32] = [
            0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
            0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
        ]
        for offset in stride(from: 0, to: bytes.count, by: 64) {
            var w = [UInt32](repeating: 0, count: 64)
            for i in 0..<16 {
                let p = offset + i * 4
                w[i] = UInt32(bytes[p]) << 24 | UInt32(bytes[p + 1]) << 16 |
                       UInt32(bytes[p + 2]) << 8 | UInt32(bytes[p + 3])
            }
            for i in 16..<64 {
                let s0 = ror(w[i-15], 7) ^ ror(w[i-15], 18) ^ (w[i-15] >> 3)
                let s1 = ror(w[i-2], 17) ^ ror(w[i-2], 19) ^ (w[i-2] >> 10)
                w[i] = w[i-16] &+ s0 &+ w[i-7] &+ s1
            }
            var a=hash[0], b=hash[1], c=hash[2], d=hash[3]
            var e=hash[4], f=hash[5], g=hash[6], h=hash[7]
            for i in 0..<64 {
                let s1 = ror(e,6) ^ ror(e,11) ^ ror(e,25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = h &+ s1 &+ ch &+ roundConstants[i] &+ w[i]
                let s0 = ror(a,2) ^ ror(a,13) ^ ror(a,22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                h=g; g=f; f=e; e=d &+ temp1
                d=c; c=b; b=a; a=temp1 &+ temp2
            }
            hash[0] = hash[0] &+ a; hash[1] = hash[1] &+ b
            hash[2] = hash[2] &+ c; hash[3] = hash[3] &+ d
            hash[4] = hash[4] &+ e; hash[5] = hash[5] &+ f
            hash[6] = hash[6] &+ g; hash[7] = hash[7] &+ h
        }
        return hash.flatMap { word in
            [UInt8(truncatingIfNeeded: word >> 24),UInt8(truncatingIfNeeded: word >> 16),
             UInt8(truncatingIfNeeded: word >> 8),UInt8(truncatingIfNeeded: word)]
        }
    }
    #endif
}
#if canImport(CryptoKit)
import CryptoKit
#endif


/// P0 privacy boundary for presenting an external Markdown document inside a
/// WebKit renderer. Preserves Obsidian wiki-image syntax for the separate
/// security-scoped local embed resolver, but removes all normal Markdown image
/// constructs including reference-style, shortcut and inline variants.
/// This does NOT mutate the original Markdown bytes.
public enum ImVaultSafetyProjection {
    /// Maps Obsidian [[note|alias]] to an inert, interceptable internal HTTPS
    /// URI. This special host is never allowed to navigate in the web view;
    /// the native router resolves links against the *authorized Vault index*.
    /// Untrusted/external-looking targets remain plain text.
    public static func withWikiLinks(_ source: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!!)\[\[([^\]\r\n]{1,200})\]\]"#) else { return source }
        var output = source
        let matches = regex.matches(in: source, range: NSRange(source.startIndex..., in: source))
        for match in matches.reversed() {
            guard let range = Range(match.range, in: output),
                  let inner = Range(match.range(at: 1), in: output) else { continue }
            let parts = String(output[inner]).split(separator: "|", maxSplits: 1,
                                                    omittingEmptySubsequences: false)
            let target = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !target.isEmpty, !target.hasPrefix("/"),
                  !target.contains(":"), !target.contains("\\"),
                  !target.contains("[") && !target.contains("]"),
                  !target.split(separator: "/").contains("..") else { continue }
            let alias = parts.count > 1 ? String(parts[1]) : target
            let label = alias.replacingOccurrences(of: "[", with: "\\[")
                             .replacingOccurrences(of: "]", with: "\\]")
                             .replacingOccurrences(of: "(", with: "\\(")
                             .replacingOccurrences(of: ")", with: "\\)")
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "&=+#")
            guard let encoded = target.addingPercentEncoding(withAllowedCharacters: allowed) else { continue }
            output.replaceSubrange(range, with:
                "[\(label)](https://impress.invalid/wiki?target=\(encoded))")
        }
        return output
    }

    /// Obsidian > [!NOTE] and > [!WARNING] become readable native Markdown
    /// blockquotes. Full Obsidian plugin and foldable callout semantics are
    /// intentionally not claimed.
    public static func withCalloutHeadings(_ source: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?m)^([ \t]*>[ \t]*)\[!(NOTE|TIP|IMPORTANT|WARNING|CAUTION|QUOTE|TODO)\](?:[ \t]+([^\r\n]*))?"#,
            options: [.caseInsensitive]) else { return source }
        var result = source
        for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).reversed() {
            guard let full = Range(match.range, in: result),
                  let first = Range(match.range(at: 1), in: result),
                  let kind = Range(match.range(at: 2), in: result) else { continue }
            let title = match.range(at: 3).location == NSNotFound ? "" :
                (Range(match.range(at: 3), in: result).map { String(result[$0]) } ?? "")
            let type = String(result[kind]).uppercased()
            let heading = title.isEmpty ? type : type + " · " + title
            result.replaceSubrange(full, with: String(result[first]) + "**" + heading + "**")
        }
        return result
    }

    public static func withoutUntrustedImages(_ source: String) -> String {
        var projected = source
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
        let markers: [(String, String)] = [
            // Direct image URLs, including whitespace and angle-bracket form.
            (#"(?s)!\[[^\]\n]*\]\s*\([^)]*\)"#, "（外部图片已屏蔽）"),
            // Reference image: ![desc][asset] or ![desc][].
            (#"!\[[^\]\n]*\]\s*\[[^\]\n]*\]"#, "（外部图片已屏蔽）"),
            // Shortcut reference ![desc]. Don't eat Obsidian ![[image.png]].
            (#"!\[[^\]\n]*\](?!\])"#, "（外部图片已屏蔽）")
        ]
        for (pattern, replacement) in markers {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(projected.startIndex..., in: projected)
            projected = regex.stringByReplacingMatches(in: projected,
                options: [], range: range, withTemplate: replacement)
        }
        return projected
    }
}


/// A main-thread scoped generation token for asynchronous directory scans.
/// Changing or disconnecting the Vault invalidates ALL responses from the old
/// source, even if a callback completes successfully after authorization
/// changes. Does not access files or acquire additional provider privileges.
public struct ImVaultAsyncReadToken: Equatable, Sendable {
    public let vaultID: String
    public let generation: UInt64
}

public struct ImVaultAsyncReadGate {
    public private(set) var activeVaultID: String?
    private var generation: UInt64 = 0

    public init() {}

    @discardableResult
    public mutating func changeSource(to vaultID: String?) -> Bool {
        guard activeVaultID != vaultID else { return false }
        activeVaultID = vaultID
        generation &+= 1
        return true
    }

    public mutating func begin(for vaultID: String) -> ImVaultAsyncReadToken {
        changeSource(to: vaultID)
        generation &+= 1
        return ImVaultAsyncReadToken(vaultID: vaultID, generation: generation)
    }

    /// Caller must also check the current authorized Bookmark identity, since
    /// a revoked permission may change in a different control flow.
    public func accepts(_ token: ImVaultAsyncReadToken) -> Bool {
        activeVaultID == token.vaultID && generation == token.generation
    }
}
