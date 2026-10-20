import Foundation
import Testing
@testable import ImpressReviewCore

@Suite("Obsidian Vault content authority and conflict gates")
struct ImVaultSyncCoreTests {
    @Test func oldVaultScanCannotCompleteAfterSwitch() {
        var gate = ImVaultAsyncReadGate()
        let fromA = gate.begin(for: "Vault-A")
        #expect(gate.accepts(fromA))
        let switchedVault = gate.changeSource(to: "Vault-B")
        #expect(switchedVault)
        #expect(!gate.accepts(fromA))
        let fromB = gate.begin(for: "Vault-B")
        #expect(gate.accepts(fromB))
        #expect(!gate.accepts(fromA))
    }

    @Test func lateScanCannotCompleteAfterDisconnectOrRefresh() {
        var gate = ImVaultAsyncReadGate()
        let stale = gate.begin(for: "Vault-A")
        let latest = gate.begin(for: "Vault-A")
        #expect(!gate.accepts(stale))
        #expect(gate.accepts(latest))
        let disconnectedVault = gate.changeSource(to: nil)
        #expect(disconnectedVault)
        #expect(!gate.accepts(latest))
        #expect(gate.activeVaultID == nil)
    }

    @Test func privacyProjectionBlocksInlineAndReferenceImages() {
        let markdown = """
        # Personal note
        ![remote](https://example.com/track.png)
        ![reference][asset]
        [asset]: https://example.com/track2.png
        ![shortcut]
        [shortcut]: https://example.com/track3.png
        <img src="https://example.com/fetch">
        ![[local-chart.png]]
        """
        let preview = ImVaultSafetyProjection.withoutUntrustedImages(markdown)
        #expect(!preview.contains("![remote]"))
        #expect(!preview.contains("![reference]"))
        #expect(!preview.contains("![shortcut]"))
        #expect(!preview.contains("<img"))
        #expect(preview.contains("![[local-chart.png]]"))
        #expect(preview.contains("（外部图片已屏蔽）"))
    }

    @Test func unknownImageDataUriIsNotLoadedDirectly() {
        let payload = "![payload](data:image/svg+xml;base64,PGh0bWw+)"
        let projected = ImVaultSafetyProjection.withoutUntrustedImages(payload)
        #expect(!projected.contains("data:image/svg"))
    }

    @Test func wikiLinksRemainInAuthorizedInternalRoute() {
        let source = "See [[Studies/Physics|Mechanics]] and ![[chart.png]]"
        let preview = ImVaultSafetyProjection.withWikiLinks(source)
        #expect(preview.contains("[Mechanics](https://impress.invalid/wiki?target="))
        #expect(preview.contains("[Mechanics]"))
        #expect(preview.contains("![[chart.png]]"))
        #expect(!preview.contains("https://example.com"))
    }

    @Test func dangerousWikiPathsRemainLiteralAndUnrouted() {
        let source = "[[../secret]] [[https://evil.example]] [[C:\\\\private]]"
        let preview = ImVaultSafetyProjection.withWikiLinks(source)
        #expect(!preview.contains("impress.invalid"))
    }

    @Test func calloutUsesOrdinarySafeBlockquoteMarkdown() {
        let source = "> [!NOTE] First principle\n> Test the assumption"
        let result = ImVaultSafetyProjection.withCalloutHeadings(source)
        #expect(result.contains("> **NOTE · First principle**"))
        #expect(result.contains("> Test the assumption"))
    }

    @Test func standardSHA256Vectors() {
        #expect(ImVaultDigest.sha256(Data()) ==
            "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
        #expect(ImVaultDigest.sha256(Data("abc".utf8)) ==
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad")
    }
    @Test func binaryByteDifferenceAlwaysChangesVersion() {
        #expect(ImVaultDigest.sha256(Data("one\r\n".utf8)) !=
                ImVaultDigest.sha256(Data("one\n".utf8)))
    }
    @Test func sameNamesDifferentFoldersAreDifferentDocuments() throws {
        let a = try ImVaultFileIdentity(vaultID: "Vault-001", relativePath: "A/笔记.md")
        let b = try ImVaultFileIdentity(vaultID: "Vault-001", relativePath: "B/笔记.md")
        let c = try ImVaultFileIdentity(vaultID: "Vault-002", relativePath: "A/笔记.md")
        #expect(a != b)
        #expect(a != c)
        #expect(Set([a,b,c]).count == 3)
    }
    @Test(arguments: ["../secret.md", "/absolute.md", "A/../secret.md",
                       "A//empty.md", ".obsidian/config.md", "notes.txt",
                       "C:\\users\\note.md", "note.md:stream", "./note.md"])
    func rejectPathTraversal(_ path: String) {
        #expect(throws: ImVaultCoreError.invalidRelativePath) {
            try ImVaultFileIdentity(vaultID: "vault", relativePath: path)
        }
    }
    @Test func draftPreservesOriginalMarkdown() throws {
        let text = "---\ntags: [demo]\n---\n# Heading\n![[image.png]]\n[[Linked]]\n"
        let id = try ImVaultFileIdentity(vaultID: "v",relativePath: "notes/test.md")
        var draft = try ImVaultDraft(identity: id, baseText: text)
        try draft.update(text + "\nAdded text")
        try draft.validate()
        #expect(draft.baseText == text)
        #expect(draft.hasChanges)
        #expect(draft.decision(against: Data(text.utf8)) == .safeToWrite)
    }
    @Test func concurrentEditorMustNotOverwrite() throws {
        let id = try ImVaultFileIdentity(vaultID: "v", relativePath: "A.md")
        var a = try ImVaultDraft(identity: id, baseText: "A")
        var b = try ImVaultDraft(identity: id, baseText: "A")
        try a.update("from Obsidian")
        try b.update("from Impress")
        #expect(a.decision(against: Data("A".utf8)) == .safeToWrite)
        #expect(b.decision(against: Data(a.editedText.utf8)) == .conflict)
        #expect(b.editedText == "from Impress")
    }
    @Test func idempotentRetryIsNotASecondWrite() throws {
        let id = try ImVaultFileIdentity(vaultID: "v", relativePath: "A.md")
        var draft = try ImVaultDraft(identity: id, baseText: "A")
        try draft.update("B")
        #expect(draft.decision(against: Data("B".utf8)) == .alreadyApplied)
    }
    @Test func noContentChangeMeansNoWriteEvenWhenRemoteChanged() throws {
        let id = try ImVaultFileIdentity(vaultID: "v", relativePath: "A.md")
        let draft = try ImVaultDraft(identity: id, baseText: "A")
        #expect(draft.decision(against: Data("B".utf8)) == .unchanged)
    }
    @Test func previewCapNeverApprovesTruncatedDiff() {
        let a = (0..<1000).map { "old \($0)" }.joined(separator: "\n")
        let b = (0..<1000).map { "new \($0)" }.joined(separator: "\n")
        let short = ImVaultDiff.summary(base: a,edited: b,maximumLines: 20)
        #expect(!short.complete)
        #expect(short.text.contains("禁止提交"))
        #expect(ImVaultDiff.summary(base: a,edited: b,maximumLines: 4000).complete)
    }
    @Test func draftDetectsModifiedBaseline() throws {
        let id = try ImVaultFileIdentity(vaultID: "v",relativePath: "A.md")
        let initial = try ImVaultDraft(identity: id, baseText: "A")
        let decoder = JSONDecoder()
        let encoder = JSONEncoder()
        let data = try encoder.encode(initial)
        let tampered = String(decoding: data, as: UTF8.self).replacingOccurrences(
            of: "\"baseText\":\"A\"", with: "\"baseText\":\"malicious\"")
        #expect(tampered != String(decoding: data, as: UTF8.self))
        let loaded = try decoder.decode(ImVaultDraft.self, from: Data(tampered.utf8))
        #expect(throws: ImVaultCoreError.invalidDraft) { try loaded.validate() }
    } 
    @Test func duplexIndividualTargetsAndExplicitRetryAreIdempotent() {
        var both = ImDuplexApprovalState(noteSelected: true, cardSelected: true)
        #expect(both.needsNoteAction && both.needsCardAction)
        #expect(!both.completed)
        both.noteStatus = .applied
        both.cardStatus = .failed
        #expect(!both.needsNoteAction && both.needsCardAction)
        #expect(!both.completed)
        let restored = try? JSONDecoder().decode(ImDuplexApprovalState.self,
            from: JSONEncoder().encode(both))
        #expect(restored == both)
        #expect(restored?.needsCardAction == true)
        both.cardStatus = .applied
        #expect(both.completed)
        var cardOnly = ImDuplexApprovalState(noteSelected: false, cardSelected: true)
        #expect(!cardOnly.needsNoteAction)
        cardOnly.cardStatus = .applied
        #expect(cardOnly.completed)
        var discarded = ImDuplexApprovalState(noteSelected: true, cardSelected: true)
        discarded.noteSelected = false
        discarded.cardSelected = false
        #expect(discarded.completed)
        #expect(!discarded.needsNoteAction && !discarded.needsCardAction)
    }

    @Test func duplexCardConflictAndRepeatNeverOverwriteAnotherVersion() {
        let safe = ImDuplexCardVersionGate.decide(expectedContentRevision: 3,
            currentContentRevision: 3, baseQuestion: "Original Q", baseAnswer: "Original A",
            proposedQuestion: "Revised Q", proposedAnswer: "Revised A",
            currentQuestion: "Original Q", currentAnswer: "Original A")
        #expect(safe == .safeToWrite)
        let retry = ImDuplexCardVersionGate.decide(expectedContentRevision: 3,
            currentContentRevision: 4, baseQuestion: "Original Q", baseAnswer: "Original A",
            proposedQuestion: "Revised Q", proposedAnswer: "Revised A",
            currentQuestion: "Revised Q", currentAnswer: "Revised A")
        #expect(retry == .alreadyApplied)
        let conflict = ImDuplexCardVersionGate.decide(expectedContentRevision: 3,
            currentContentRevision: 4, baseQuestion: "Original Q", baseAnswer: "Original A",
            proposedQuestion: "Revised Q", proposedAnswer: "Revised A",
            currentQuestion: "A different edit", currentAnswer: "Original A")
        #expect(conflict == .conflict)
        #expect(ImDuplexCardVersionGate.decide(expectedContentRevision: 3,
            currentContentRevision: 3, baseQuestion: "Original Q", baseAnswer: "Original A",
            proposedQuestion: "Original Q", proposedAnswer: "Original A",
            currentQuestion: "Original Q", currentAnswer: "Original A") == .unchanged)
    }


}
