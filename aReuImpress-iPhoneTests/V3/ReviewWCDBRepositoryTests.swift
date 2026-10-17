//
//  ReviewWCDBRepositoryTests.swift
//  Staged for the iOS XCTest target; Xcode target integration pending.
//

import XCTest
import UIKit
import ImpressReviewCore
@testable import aReuImpress_iPhone

private enum ForcedSchedulingError: Error {
    case fixtureFailure
}

private struct FailingReviewCalculator: WCDBReviewCalculating {
    func next(before: ReviewScheduleSnapshot, status: ReviewCardStatus,
              submission: ReviewSubmission) throws -> WCDBCalculatedReview {
        throw ForcedSchedulingError.fixtureFailure
    }
}

final class ReviewWCDBRepositoryTests: XCTestCase {
    private func temporaryPath() -> String {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImpressV3-" + UUID().uuidString, isDirectory: true)
        return folder.appendingPathComponent("v3.sqlite").path
    }

    func testNewCardCommitsOneEventAndRetriesIdempotently() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repository = try ReviewWCDBRepository(
            databasePath: path, calculator: calculator)
        let cardID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let initial = try calculator.newCardSnapshot(id: cardID, now: now)
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: cardID, question: "Why recall before reading?",
                            answerText: "Active recall tests retrieval."),
            initial: initial, now: now)

        let request = ReviewSubmission(eventID: UUID(), cardID: cardID,
                                       expectedRevision: 0, rating: .good,
                                       reviewedAt: now)
        let first = try await repository.commit(request)
        let replay = try await repository.commit(request)
        XCTAssertEqual(first, replay)
        XCTAssertEqual(first.before.revision, 0)
        XCTAssertEqual(first.after.revision, 1)
        let events = try await repository.reviewHistory(for: cardID)
        XCTAssertEqual(events.count, 1)
        let candidates = try await repository.fetchQueueCandidates()
        XCTAssertEqual(candidates[0].revision, 1)
        XCTAssertEqual(candidates[0].status, .learning)
    }

    func testStaleRevisionCannotCreateSecondRating() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repository = try ReviewWCDBRepository(databasePath: path,
                                                   calculator: calculator)
        let cardID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: cardID, question: "Q", answerText: "A"),
            initial: calculator.newCardSnapshot(id: cardID, now: now), now: now)
        _ = try await repository.commit(ReviewSubmission(
            eventID: UUID(), cardID: cardID, expectedRevision: 0,
            rating: .good, reviewedAt: now))
        do {
            _ = try await repository.commit(ReviewSubmission(
                eventID: UUID(), cardID: cardID, expectedRevision: 0,
                rating: .easy, reviewedAt: now))
            XCTFail("A second distinct rating with an old revision must fail")
        } catch ReviewWCDBError.revisionConflict { }
        let events = try await repository.reviewHistory(for: cardID)
        XCTAssertEqual(events.count, 1)
    }

    func testCalculatorFailureRollsBackAndPreservesRevision() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repo = try ReviewWCDBRepository(databasePath: path,
                                             calculator: FailingReviewCalculator())
        let cardID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: cardID, question: "Q", answerText: "A"),
            initial: calculator.newCardSnapshot(id: cardID, now: now), now: now)
        do {
            _ = try await repo.commit(ReviewSubmission(
                eventID: UUID(), cardID: cardID, expectedRevision: 0,
                rating: .hard, reviewedAt: now))
            XCTFail("Expected injected failure")
        } catch ForcedSchedulingError.fixtureFailure { }
        let candidates = try await repo.fetchQueueCandidates()
        XCTAssertEqual(candidates[0].revision, 0)
        let history = try await repo.reviewHistory(for: cardID)
        XCTAssertEqual(history.count, 0)
    }

    func testImageAndMultipleChoicePayloadsSurvivePersistence() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repo = try ReviewWCDBRepository(databasePath: path, calculator: calculator)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let imageID = UUID()
        let pixels = Data([0xFF, 0xD8, 0xFF, 0xD9])
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: imageID, question: "Identify this image",
                            cardType: 3, imageData: pixels),
            initial: calculator.newCardSnapshot(id: imageID, now: now), now: now)
        let multipleID = UUID()
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: multipleID, question: "Choose two",
                            choices: "A\nB\nC", correctIndices: "0,2", cardType: 2),
            initial: calculator.newCardSnapshot(id: multipleID, now: now), now: now)
        let image = try await repo.content(for: imageID)
        XCTAssertEqual(image?.imageData, pixels)
        let multiple = try await repo.content(for: multipleID)
        XCTAssertEqual(multiple?.choices, "A\nB\nC")
        XCTAssertEqual(multiple?.correctIndices, "0,2")
        let candidates = try await repo.fetchQueueCandidates()
        XCTAssertEqual(candidates.count, 2)
    }

    func testDueCountUsesFSRSDueAndExcludesNewInventory() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repo = try ReviewWCDBRepository(databasePath: path, calculator: calculator)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let cardID = UUID()
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: cardID, question: "Q", answerText: "A"),
            initial: calculator.newCardSnapshot(id: cardID, now: now), now: now)
        let beforeCount = try await repo.dueCount(at: now)
        XCTAssertEqual(beforeCount, 0)
        _ = try await repo.commit(ReviewSubmission(
            eventID: UUID(), cardID: cardID, expectedRevision: 0,
            rating: .good, reviewedAt: now))
        let immediateCount = try await repo.dueCount(at: now)
        let laterCount = try await repo.dueCount(at: now.addingTimeInterval(11*60))
        XCTAssertEqual(immediateCount, 0)
        XCTAssertEqual(laterCount, 1)
    }
    func testFractionalSecondClockSurvivesFSRSWCDBRoundTrip() async throws {
        let path = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repository = try ReviewWCDBRepository(databasePath: path, calculator: calculator)
        let id = UUID()
        let at = Date(timeIntervalSince1970: 1_700_000_000.1234567)
        try await repository.insertNewCard(
            WCDBV3CardInput(cardID: id, question: "Fractional date", answerText: "A"),
            initial: calculator.newCardSnapshot(id: id, now: at), now: at)
        let event = try await repository.commit(ReviewSubmission(
            eventID: UUID(), cardID: id, expectedRevision: 0,
            rating: .easy, reviewedAt: at.addingTimeInterval(1.25)))
        XCTAssertEqual(event.rating, .easy)
        XCTAssertEqual(event.after.revision, 1)
        let history = try await repository.reviewHistory(for: id)
        XCTAssertEqual(history.count, 1)
    }

    func testSnapshotPreservesCommittedStateWithoutStoppingFutureWrites() async throws {
        let original = temporaryPath()
        let calculator = FSRS6ReviewCalculator()
        let repo = try ReviewWCDBRepository(databasePath: original, calculator: calculator)
        let cardID = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        try await repo.insertNewCard(
            WCDBV3CardInput(cardID: cardID, question: "Q", answerText: "A"),
            initial: calculator.newCardSnapshot(id: cardID, now: now), now: now)
        _ = try await repo.commit(ReviewSubmission(
            eventID: UUID(), cardID: cardID, expectedRevision: 0,
            rating: .good, reviewedAt: now))
        let backup = URL(fileURLWithPath: original).deletingLastPathComponent()
            .appendingPathComponent("safe-backup.sqlite")
        try await repo.createConsistentBackup(to: backup)
        let restored = try ReviewWCDBRepository(
            databasePath: backup.path, calculator: calculator)
        let oldHistory = try await repo.reviewHistory(for: cardID)
        let backupHistory = try await restored.reviewHistory(for: cardID)
        XCTAssertEqual(backupHistory, oldHistory)
        let remaining = try await repo.fetchQueueCandidates()
        XCTAssertEqual(remaining.first?.revision, 1)
    }

}


// P0-0: These tests create disposable sandbox fixtures only. They never read,
// write, select or import the user's real Obsidian/iCloud directory.
@MainActor
final class ImVaultSafetyTests: XCTestCase {
    private func fixtureRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImpressVaultSafety-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func testFirstImportCopiesNewDestinationWithoutChangingSource() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("ImpressVault", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        let sourceFile = source.appendingPathComponent("one.md")
        try "# Original\n[[Link]]".write(to: sourceFile, atomically: true, encoding: .utf8)

        try ImVaultSafeImporter.copyOnlyWhenAbsent(from: source, to: destination)
        XCTAssertEqual(try String(contentsOf: sourceFile, encoding: .utf8), "# Original\n[[Link]]")
        XCTAssertEqual(try String(contentsOf: destination.appendingPathComponent("one.md"),
                                  encoding: .utf8), "# Original\n[[Link]]")
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(names.contains(where: { $0.hasPrefix(".impress-vault-import-") }))
    }

    func testRepeatImportNeverDestroysUserModifiedVault() throws {
        let root = try fixtureRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source", isDirectory: true)
        let destination = root.appendingPathComponent("ImpressVault", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "# New content".write(to: source.appendingPathComponent("note.md"),
                                   atomically: true, encoding: .utf8)
        let existingFile = destination.appendingPathComponent("note.md")
        let original = "---\ntitle: private\n---\n# Keep my edits\n[[Original]]"
        try original.write(to: existingFile, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try ImVaultSafeImporter.copyOnlyWhenAbsent(
            from: source, to: destination))
        XCTAssertEqual(try String(contentsOf: existingFile, encoding: .utf8), original)
        XCTAssertEqual(try String(contentsOf: source.appendingPathComponent("note.md"),
                                  encoding: .utf8), "# New content")
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path)
        XCTAssertFalse(names.contains(where: { $0.hasPrefix(".impress-vault-import-") }))
    }

    func testSameNamedMarkdownFilesHaveDistinctFolderIdentity() {
        let a = ImVaultNoteIdentity(title: "Untitled", directory: "/Studies/Physics")
        let b = ImVaultNoteIdentity(title: "Untitled", directory: "/Studies/Biology")
        let alias = ImVaultNoteIdentity(title: "Untitled", directory: "Studies/Physics/")
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a, alias)
    }

    func testLegacyOverwriteAPIIsExplicitlyDisabled() {
        var returnedError: Error?
        ImObsidianManager.shared.writeMarkdownFile(
            from: UIViewController(), at: "test.md", content: "# Must not write") { error in
            returnedError = error
        }
        XCTAssertNotNil(returnedError)
        XCTAssertTrue(returnedError?.localizedDescription.contains("旧版覆盖写回已停用") == true)
    }
}


// P0-2/3/4/5 simulation: disposable test Vault ONLY. No user document picker,
// iCloud container or original Obsidian file is accessed. Coordinator, local
// draft persistence and recovery are the same code paths used by the app.
@MainActor
final class ImVaultSyncIntegrationTests: XCTestCase {
    private func createRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ImVaultIntegration-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func put(_ content: String, root: URL, path: String = "Notes/Topic.md") throws -> URL {
        let file = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try Data(content.utf8).write(to: file, options: .atomic)
        return file
    }

    func testReadOnlyIndexAndOnDemandReadNeverTouchSource() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let body = "---\ntags: [inbox]\n---\n# Title\n![[graph.png]]\n"
        let url = try put(body, root: root)
        let original = try Data(contentsOf: url)
        try put("# Other", root: root, path: "Different/Topic.md")
        let index = try ImVaultReadSync.list(root: root, vaultID: "Fixture")
        XCTAssertEqual(index.count, 2)
        XCTAssertNotEqual(index[0].identity, index[1].identity)
        let id = try ImVaultFileIdentity(vaultID: "Fixture", relativePath: "Notes/Topic.md")
        let read = try ImVaultReadSync.load(root: root, identity: id)
        XCTAssertEqual(read.sourceBytes, original)
        XCTAssertEqual(read.markdown, body)
        XCTAssertEqual(try Data(contentsOf: url), original)
    }

    func testPrivateDraftCanBeRecoveredAfterControllerRecreation() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let text = "---\noriginal: yes\n---\n# Original\n[[Keep]]"
        let url = try put(text, root: root)
        let id = try ImVaultFileIdentity(vaultID: UUID().uuidString,
                                         relativePath: "Notes/Topic.md")
        let source = try ImVaultReadSync.load(root: root, identity: id)
        var draft = try ImVaultDraft(identity: id, baseText: source.markdown,
                                     baseRawData: source.sourceBytes)
        try draft.update(text + "\nadditional idea")
        try ImVaultPrivateStore.saveDraft(draft)
        let restored = try XCTUnwrap(ImVaultPrivateStore.loadDraft(identity: id))
        XCTAssertEqual(restored.identity, draft.identity)
        XCTAssertEqual(restored.baseDigest, draft.baseDigest)
        XCTAssertEqual(restored.baseRawData, draft.baseRawData)
        XCTAssertEqual(restored.editedText, draft.editedText)
        XCTAssertEqual(try Data(contentsOf: url), source.sourceBytes)
    }

    func testSameFileConflictsNeverOverwriteExternalEdit() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try put("source text", root: root)
        let id = try ImVaultFileIdentity(vaultID: UUID().uuidString,
                                         relativePath: "Notes/Topic.md")
        let doc = try ImVaultReadSync.load(root: root, identity: id)
        var draft = try ImVaultDraft(identity: id, baseText: doc.markdown,
                                     baseRawData: doc.sourceBytes)
        try draft.update("Impress edit")
        try Data("Obsidian edit".utf8).write(to: url, options: .atomic)
        XCTAssertThrowsError(try ImVaultGuardedWrite.commitFixture(
            root: root, draft: draft, userConfirmedDiff: true))
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "Obsidian edit")
        XCTAssertEqual(draft.editedText, "Impress edit")
    }

    func testUserApprovalRequiredAndSuccessfulFixtureWriteIsRecoverable() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = "# Learn\n[[Link]]"
        let file = try put(original, root: root)
        let id = try ImVaultFileIdentity(vaultID: UUID().uuidString,
                                         relativePath: "Notes/Topic.md")
        let source = try ImVaultReadSync.load(root: root, identity: id)
        var draft = try ImVaultDraft(identity: id, baseText: source.markdown,
                                     baseRawData: source.sourceBytes)
        try draft.update("# Learn\n[[Link]]\n- My understanding")
        XCTAssertThrowsError(try ImVaultGuardedWrite.commitFixture(
            root: root, draft: draft, userConfirmedDiff: false))
        XCTAssertEqual(try Data(contentsOf: file), source.sourceBytes)
        let written = try ImVaultGuardedWrite.commitFixture(
            root: root, draft: draft, userConfirmedDiff: true)
        switch written {
        case let .written(recoveryURL):
            XCTAssertEqual(try Data(contentsOf: recoveryURL), source.sourceBytes)
            XCTAssertEqual(try String(contentsOf: file, encoding: .utf8),
                           draft.editedText)
        default:
            XCTFail("Expected a single verified fixture write with private recovery")
        }
        let replay = try ImVaultGuardedWrite.commitFixture(
            root: root, draft: draft, userConfirmedDiff: true)
        if case .alreadyApplied = replay {
            // idempotent second submission has no overwrite side-effect
        } else {
            XCTFail("Replay must not write source again")
        }
    }


    func testDocumentViewerIsNotAnEditableSourceTextView() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = "# Heading\n[[Obsidian link]]\n> Callout\n"
        let file = try put(source, root: root)
        let id = try ImVaultFileIdentity(vaultID: UUID().uuidString,
                                         relativePath: "Notes/Topic.md")
        let original = try Data(contentsOf: file)
        let doc = try ImVaultReadSync.load(root: root, identity: id)
        let viewer = ImVaultDocumentController(document: doc)
        viewer.loadViewIfNeeded()
        let textViews = viewer.view.subviews.compactMap { $0 as? UITextView }
        XCTAssertEqual(textViews.count, 1)
        XCTAssertFalse(textViews[0].isEditable)
        XCTAssertEqual(viewer.navigationItem.rightBarButtonItems?.count, 2)
        XCTAssertEqual(try Data(contentsOf: file), original)
    }

    func testDebugFixtureWriteCannotTargetUserDocumentsDirectory() throws {
        let documents = try XCTUnwrap(FileManager.default.urls(
            for: .documentDirectory, in: .userDomainMask).first)
        let identity = try ImVaultFileIdentity(
            vaultID: "TEST-NON-TEMP", relativePath: "must-not-create.md")
        var draft = try ImVaultDraft(identity: identity, baseText: "source")
        try draft.update("new text")
        let candidate = documents.appendingPathComponent(identity.relativePath)
        let wasPresent = FileManager.default.fileExists(atPath: candidate.path)
        XCTAssertThrowsError(try ImVaultGuardedWrite.commitFixture(
            root: documents, draft: draft, userConfirmedDiff: true))
        XCTAssertEqual(FileManager.default.fileExists(atPath: candidate.path), wasPresent)
    }

    func testMissingSourceFailsClosedWithoutRecreatingFile() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try put("Delete externally", root: root)
        let id = try ImVaultFileIdentity(vaultID: UUID().uuidString,
                                         relativePath: "Notes/Topic.md")
        let doc = try ImVaultReadSync.load(root: root, identity: id)
        var draft = try ImVaultDraft(identity: id, baseText: doc.markdown,
                                     baseRawData: doc.sourceBytes)
        try draft.update("Keep only as private draft")
        try FileManager.default.removeItem(at: file) // disposable fixture only
        XCTAssertThrowsError(try ImVaultGuardedWrite.commitFixture(
            root: root, draft: draft, userConfirmedDiff: true))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }


    func testSafeMarkdownProjectionEmbedsOnlyLocalImagesAndNeverChangesSource() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let userMarkdown = """
        # Notes
        ![[attachment.png]]
        ![remote](https://tracking.example/pixel.png)
        <img src="https://tracking.example/leak">
        """
        let file = try put(userMarkdown, root: root)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 120, height: 90), format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 120, height: 90))
        }
        try XCTUnwrap(image.pngData()).write(
            to: root.appendingPathComponent("attachment.png"), options: .atomic)
        let identity = try ImVaultFileIdentity(
            vaultID: UUID().uuidString, relativePath: "Notes/Topic.md")
        let preview = try ImVaultReadSync.safeMarkdownProjection(
            root: root, identity: identity, source: userMarkdown)
        XCTAssertTrue(preview.contains("data:image/jpeg;base64,"))
        XCTAssertFalse(preview.contains("<img"))
        XCTAssertFalse(preview.contains("![remote](https://"))
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), userMarkdown)
    }

    func testAmbiguousLocalAttachmentNeverPicksWrongPhoto() throws {
        let root = try createRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(
            size: CGSize(width: 40, height: 30), format: format).image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 40, height: 30))
        }
        try XCTUnwrap(image.pngData()).write(
            to: put("reserved", root: root, path: "A/image.png"), options: .atomic)
        try XCTUnwrap(image.pngData()).write(
            to: put("reserved", root: root, path: "B/image.png"), options: .atomic)
        let identity = try ImVaultFileIdentity(
            vaultID: UUID().uuidString, relativePath: "Notes/Topic.md")
        let rendered = try ImVaultReadSync.safeMarkdownProjection(
            root: root, identity: identity, source: "![[image.png]]")
        XCTAssertFalse(rendered.contains("data:image"))
    }

    func testEscapingAttachmentSymlinkDoesNotBlockEntireNotePreview() throws {
        let root = try createRoot()
        let outside = try createRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let picture = outside.appendingPathComponent("outside.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: picture, options: .atomic)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("outside.png"), withDestinationURL: picture)
        let id = try ImVaultFileIdentity(
            vaultID: "fixture", relativePath: "some-note.md")
        let original = "# Keep reading\n![[outside.png]]"
        let projected = try ImVaultReadSync.safeMarkdownProjection(
            root: root, identity: id, source: original)
        XCTAssertTrue(projected.contains("Keep reading"))
        XCTAssertFalse(projected.contains("data:image"))
        XCTAssertTrue(projected.contains("outside.png"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: picture.path))
    }

    func testSymlinkOutsideVaultIsNeverRead() throws {
        let root = try createRoot()
        let outside = try createRoot()
        defer {
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: outside)
        }
        let file = try put("# Private", root: outside, path: "secret.md")
        let link = root.appendingPathComponent("secret.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
        let id = try ImVaultFileIdentity(vaultID: "fixture", relativePath: "secret.md")
        XCTAssertThrowsError(try ImVaultReadSync.load(root: root, identity: id))
    }
}


@MainActor
final class ImpressImageOptimizerTests: XCTestCase {
    private func sampleImage(size: CGSize, scale: CGFloat = 3,
                             textMode: Bool = false) -> UIImage {
        let f = UIGraphicsImageRendererFormat()
        f.scale = scale
        f.opaque = true
        return UIGraphicsImageRenderer(size: size, format: f).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            if textMode {
                for row in 0..<60 {
                    let r = CGRect(x: 15, y: CGFloat(row * 11 + 10),
                                   width: size.width - 30, height: 3)
                    UIColor.black.setFill()
                    context.fill(r)
                }
            } else {
                UIColor.systemBlue.setFill()
                context.fill(CGRect(x: 0, y: 0,
                                    width: size.width * 0.50,
                                    height: size.height * 0.50))
                UIColor.systemRed.setFill()
                context.fill(CGRect(x: size.width * 0.45,
                                    y: size.height * 0.45,
                                    width: size.width * 0.40,
                                    height: size.height * 0.40))
            }
        }
    }

    func testLargePhotoEncodesToBoundedBytesAndPixels() throws {
        let source = sampleImage(size: CGSize(width: 1400, height: 850))
        XCTAssertGreaterThan(source.cgImage!.width, 1280)
        let bytes = try ImpressImageOptimizer.optimize(source, kind: .photo)
        XCTAssertLessThanOrEqual(bytes.count, ImpressImageOptimizer.maximumEncodedBytes)
        let restored = try XCTUnwrap(UIImage(data: bytes))
        XCTAssertLessThanOrEqual(restored.cgImage!.width, 1280)
        XCTAssertLessThanOrEqual(restored.cgImage!.height, 1280)
        XCTAssertGreaterThan(restored.cgImage!.width, 0)
    }

    func testHighDPIImageResizesByPixelsNotByDeviceScale() throws {
        let source = sampleImage(size: CGSize(width: 700, height: 450), scale: 3)
        XCTAssertEqual(source.cgImage?.width, 2100)
        let data = try ImpressImageOptimizer.optimize(source)
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(image.cgImage!.width, 1280)
        XCTAssertLessThanOrEqual(image.cgImage!.height, 1280)
        XCTAssertLessThanOrEqual(data.count, ImpressImageOptimizer.maximumEncodedBytes)
    }

    func testImageDocumentModePreservesMorePixelsWithinStorageCap() throws {
        let sample = sampleImage(size: CGSize(width: 850, height: 700), scale: 2,
                                 textMode: true)
        let compressed = try ImpressImageOptimizer.optimize(sample, kind: .document)
        XCTAssertLessThanOrEqual(compressed.count, ImpressImageOptimizer.maximumEncodedBytes)
        let restored = try XCTUnwrap(UIImage(data: compressed))
        XCTAssertLessThanOrEqual(restored.cgImage!.width, 2000)
        XCTAssertLessThanOrEqual(restored.cgImage!.height, 2000)
    }

    func testInvalidImageAndTinyStorageBudgetDoNotPersistAnUnusableBlob() {
        XCTAssertThrowsError(try ImpressImageOptimizer.optimize(UIImage()))
        let sample = sampleImage(size: CGSize(width: 80, height: 80), scale: 1)
        XCTAssertThrowsError(try ImpressImageOptimizer.optimize(sample, maxBytes: 128))
    }
}


@MainActor
final class ImpressV3NativeFlowTests: XCTestCase {
    func testCaptureCancelDoesNotCreateLearningEntry() throws {
        let before = try ImpressV3LearningJournal.load().count
        let capture = ImpressV3CaptureViewController(cardID: UUID(), question: "Q")
        capture.loadViewIfNeeded()
        // No save callback, no record. A sheet is deliberately ephemeral
        // until the user taps the explicit Submit action.
        XCTAssertEqual(try ImpressV3LearningJournal.load().count, before)
        XCTAssertEqual(capture.navigationItem.rightBarButtonItem?.title, "提交")
        XCTAssertEqual(capture.navigationItem.leftBarButtonItem?.style, .plain)
    }

    func testLearningEntryPersistenceAndAIFeedbackAreVersioned() throws {
        let id = UUID()
        let card = UUID()
        let entry = ImpressV3LearningEntry(id: id, cardID: card, question: "Cause?",
            userAnswer: "Because of a testable mechanism.", createdAt: Date(),
            aiEvaluation: nil)
        try ImpressV3LearningJournal.save(entry)
        XCTAssertEqual(try ImpressV3LearningJournal.load().first(where: { $0.id == id })?.userAnswer,
                       entry.userAnswer)
        try ImpressV3LearningJournal.attachFeedback(
            "准确之处是因果链清楚；待改进之处是缺少反例。", to: id)
        let persisted = try XCTUnwrap(ImpressV3LearningJournal.load().first { $0.id == id })
        XCTAssertNotNil(persisted.aiEvaluation)
        XCTAssertEqual(persisted.cardID, card)
        // Same submission ID can never append a duplicate version.
        try ImpressV3LearningJournal.save(entry)
        XCTAssertEqual(try ImpressV3LearningJournal.load().filter { $0.id == id }.count, 1)
    }

    func testModernSettingsKeepsPromptAndReminderOnly() {
        let settings = ImpressV3SettingsHubViewController()
        settings.loadViewIfNeeded()
        XCTAssertEqual(settings.tableView.numberOfSections, 2)
        XCTAssertEqual(settings.tableView.numberOfRows(inSection: 0), 1)
        XCTAssertEqual(settings.tableView.numberOfRows(inSection: 1), 1)
        let prompts = settings.tableView(settings.tableView,
            cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(prompts.contentConfiguration is UIListContentConfiguration, true)
        let legacy = SettingsConfiguration.default
        XCTAssertEqual(legacy.displaySections.count, 1)
    }

    func testV3AppearanceIsBasedOnCentralColorAuthority() {
        XCTAssertEqual(ImpressV3Appearance.accent, funBtnColor)
        XCTAssertEqual(ImpressV3Appearance.primaryText, titleColor)
        XCTAssertEqual(ImpressV3Appearance.secondaryText, contentColor)
        XCTAssertEqual(ImpressV3Appearance.surface, UIColor.secondarySystemBackground)
        XCTAssertNotNil(ImpressV3Appearance.Typography.heading)
    }

    func testV3ReviewUsesExplicitRevealAndKeepsFourDirectionSwipeStack() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("V3Native-" + UUID().uuidString)
            .appendingPathComponent("v3.sqlite")
        let repo = try ReviewWCDBRepository(databasePath: root.path,
                                             calculator: FSRS6ReviewCalculator())
        let controller = ImpressV3ReviewViewController(repository: repo)
        let navigation = UINavigationController(rootViewController: controller)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        controller.loadViewIfNeeded()
        let buttons = controller.view.subviews.compactMap { $0 as? UIButton }
        XCTAssertTrue(buttons.contains { $0.title(for: .normal) == "查看答案" })
        let stacks = controller.view.subviews.compactMap { $0 as? SwipeCardStack }
        XCTAssertEqual(stacks.count, 1)
        XCTAssertTrue(stacks[0].protectsVerticalContentScroll)
        // R04.2-D moves Settings to its own tab and removes the chat action.
        XCTAssertTrue(controller.navigationItem.rightBarButtonItems?.isEmpty ?? true)
        XCTAssertEqual(controller.navigationItem.leftBarButtonItem?.accessibilityLabel,
                       "添加内容")
        XCTAssertFalse(buttons.contains { $0.title(for: .normal) == "困难" })
        XCTAssertFalse(buttons.contains { $0.title(for: .normal) == "简单" })
    }
}


// R04.2-C: disposable WCDB fixtures; no production user database touched.
final class ImpressV3AtomicBatchTests: XCTestCase {
    private func fixture() throws -> ReviewWCDBRepository {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("ImpressBatch-" + UUID().uuidString)
            .appendingPathComponent("v3.sqlite")
        return try ReviewWCDBRepository(databasePath: path.path,
                                        calculator: FSRS6ReviewCalculator())
    }

    func testAtomicBatchPersistsAllWithFSRSZeroRevisionAndVaultPath() async throws {
        let repo = try fixture()
        let calculator = FSRS6ReviewCalculator()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let source = try ImpressBatchSourceKey.encode(ImVaultFileIdentity(
            vaultID: "vault-A", relativePath: "First/Sub/笔记.md"))
        let a = WCDBV3CardInput(question: "第一题", answerText: "回答一", sourceNotePath: source)
        let b = WCDBV3CardInput(question: "第二题", answerText: "回答二")
        let result = try await repo.insertBatchCards([
            (a, try calculator.newCardSnapshot(id: a.cardID, now: now)),
            (b, try calculator.newCardSnapshot(id: b.cardID, now: now))
        ], now: now)
        XCTAssertEqual(result, 2)
        let candidates = try await repo.fetchQueueCandidates()
        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.allSatisfy { $0.revision == 0 && $0.status == .new })
        let stored = try await repo.content(for: a.cardID)
        XCTAssertEqual(stored?.sourceNotePath, source)
        XCTAssertEqual(try ImpressBatchSourceKey.decode(stored!.sourceNotePath!), try ImVaultFileIdentity(
            vaultID: "vault-A", relativePath: "First/Sub/笔记.md"))
    }

    func testCollisionAfterFirstInsertRollsBackEntireTransaction() async throws {
        let repo = try fixture()
        let calculator = FSRS6ReviewCalculator()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let existing = WCDBV3CardInput(question: "原有", answerText: "不可变")
        try await repo.insertNewCard(existing,
            initial: try calculator.newCardSnapshot(id: existing.cardID, now: now), now: now)
        let good = WCDBV3CardInput(question: "候选一", answerText: "只可全部提交")
        let collision = WCDBV3CardInput(cardID: existing.cardID, question: "候选二", answerText: "重复 ID")
        do {
            _ = try await repo.insertBatchCards([
                (good, try calculator.newCardSnapshot(id: good.cardID, now: now)),
                (collision, try calculator.newCardSnapshot(id: collision.cardID, now: now))
            ], now: now)
            XCTFail("Must fail atomically")
        } catch ReviewWCDBError.duplicateCard { }
        let snapshot = try await repo.fetchQueueCandidates()
        XCTAssertEqual(snapshot.count, 1)
        let rolledBackContent = try await repo.content(for: good.cardID)
        let existingContent = try await repo.content(for: existing.cardID)
        XCTAssertNil(rolledBackContent)
        XCTAssertEqual(existingContent?.answerText, "不可变")
    }

    func testInvalidAnswerOrDuplicateQuestionNeverPartiallyPersists() async throws {
        let repo = try fixture()
        let calculator = FSRS6ReviewCalculator()
        let now = Date()
        let a = WCDBV3CardInput(question: "Case", answerText: "A")
        let invalid = WCDBV3CardInput(question: "Missing", answerText: nil)
        do {
            _ = try await repo.insertBatchCards([
                (a, try calculator.newCardSnapshot(id: a.cardID, now: now)),
                (invalid, try calculator.newCardSnapshot(id: invalid.cardID, now: now))
            ], now: now)
            XCTFail("Reject a malformed card before any write")
        } catch ReviewWCDBError.invalidSchedulerOutput { }
        let b = WCDBV3CardInput(question: " case ", answerText: "B")
        do {
            _ = try await repo.insertBatchCards([
                (a, try calculator.newCardSnapshot(id: a.cardID, now: now)),
                (b, try calculator.newCardSnapshot(id: b.cardID, now: now))
            ], now: now)
            XCTFail("Reject duplicate content")
        } catch ReviewWCDBError.duplicateContent { }
        let remaining = try await repo.fetchQueueCandidates()
        XCTAssertEqual(remaining.count, 0)
    }

    @MainActor
    func testCreatingBatchPreviewWithoutConfirmationDoesNotWrite() async throws {
        let repo = try fixture()
        let input = WCDBV3CardInput(question: "Not confirmed", answerText: "No write")
        let parsed = ImpressBatchParser.parse("Q: Not confirmed\nA: No write", as: .text)
        XCTAssertEqual(parsed.count, 1)
        XCTAssertTrue(parsed[0].isValid)
        let found = try await repo.content(for: input.cardID)
        XCTAssertNil(found)
        let remaining = try await repo.fetchQueueCandidates()
        XCTAssertEqual(remaining.count, 0)

    }
}


@MainActor
final class ImpressV3BatchPreviewIntegrationTests: XCTestCase {
    func testInvalidCandidateDisablesAtomicCommit() {
        let parsed = ImpressBatchParser.parse("Q: 尚未回答", as: .text)
        let preview = ImpressV3BatchPreviewViewController(
            rows: parsed.map { ImpressV3BatchCandidate(parsed: $0, sourceKey: nil) })
        preview.loadViewIfNeeded()
        XCTAssertEqual(preview.rows.count, 1)
        XCTAssertEqual(preview.rows[0].raw, "Q: 尚未回答")
        let cell = preview.tableView(preview.tableView,
                                     cellForRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.accessoryType, .detailDisclosureButton)
        XCTAssertFalse(preview.navigationItem.rightBarButtonItem?.isEnabled ?? true)
        XCTAssertEqual(preview.tableView.numberOfRows(inSection: 0), 1)
    }

    func testValidPreviewRequiresExplicitCommit() throws {
        let parsed = ImpressBatchParser.parse("Q: Why?\nA: Because.", as: .text)
        let preview = ImpressV3BatchPreviewViewController(
            rows: parsed.map { ImpressV3BatchCandidate(parsed: $0, sourceKey: nil) })
        preview.loadViewIfNeeded()
        XCTAssertTrue(preview.navigationItem.rightBarButtonItem?.isEnabled ?? false)
        XCTAssertEqual(preview.rows[0].draft.question, "Why?")
        XCTAssertNotNil(try preview.rows[0].draft.validatedInput())
    }
    func testConfirmAlertMustPrecedeAnyDatabaseCallback() {
        let parsed = ImpressBatchParser.parse("Q: What?\nA: A fact.", as: .text)
        let screen = ImpressV3BatchPreviewViewController(
            rows: parsed.map { ImpressV3BatchCandidate(parsed: $0, sourceKey: nil) })
        let navigation = UINavigationController(rootViewController: screen)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 375, height: 667))
        window.rootViewController = navigation
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        var calls = 0
        screen.onCommit = { _ in calls += 1 }
        screen.loadViewIfNeeded()
        guard let button = screen.navigationItem.rightBarButtonItem,
              let action = button.action else {
            return XCTFail("Native import action missing")
        }
        UIApplication.shared.sendAction(action, to: button.target, from: button, for: nil)
        XCTAssertEqual(calls, 0)
        let alert = screen.presentedViewController as? UIAlertController
        XCTAssertNotNil(alert)
        XCTAssertEqual(alert?.actions.map(\.title), ["返回预览", "确认导入"])
        alert?.dismiss(animated: false)
    }

}
