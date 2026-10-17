//
//  ReviewWCDBRepository.swift
//  Impress V3 -- staged iOS integration adapter (WCDB.swift 1.1.0).
//
//  This file deliberately is not added to the legacy Xcode target yet.
//  Link the ImpressReviewCore Swift package before target integration.
//

import Foundation
import WCDBSwift
import ImpressReviewCore

public enum ReviewWCDBError: Swift.Error {
    case missingCard
    case suspendedCard
    case revisionConflict
    case eventIdentifierCollision
    case corruptRecord
    case invalidSchedulerOutput
    case duplicateCard
    case duplicateContent
}

/// Opaque FSRS result; the scheduler owns mathematics, WCDB owns durability.
public struct WCDBCalculatedReview: Sendable {
    public let snapshot: ReviewScheduleSnapshot
    public let status: ReviewCardStatus

    public init(snapshot: ReviewScheduleSnapshot, status: ReviewCardStatus) {
        self.snapshot = snapshot
        self.status = status
    }
}

/// The actual FSRS-6 adapter is supplied separately and pinned to a tested SHA.
public protocol WCDBReviewCalculating: Sendable {
    func next(before: ReviewScheduleSnapshot,
              status: ReviewCardStatus,
              submission: ReviewSubmission) throws -> WCDBCalculatedReview
}

/// WCDB does not load picture BLOBs to construct the review queue.
private struct WCDBV3CardRow: TableCodable {
    var cardID: String?
    var question: String?
    var answerText: String?
    var choices: String?
    var correctIndices: String?
    var cardType: Int?
    var imageData: Data?
    var sourceNotePath: String?
    var createdAt: Date?
    var updatedAt: Date?
    var revision: Int?
    var isSuspended: Int?
    var state: Int?
    var dueAt: Date?
    var lastReviewedAt: Date?
    var schedulerPayload: Data?
    var schemaVersion: Int?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = WCDBV3CardRow
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case cardID = "card_id"
        case question
        case answerText = "answer_text"
        case choices
        case correctIndices = "correct_indices"
        case cardType = "card_type"
        case imageData = "image_data"
        case sourceNotePath = "source_note_path"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case revision
        case isSuspended = "is_suspended"
        case state
        case dueAt = "due_at"
        case lastReviewedAt = "last_reviewed_at"
        case schedulerPayload = "scheduler_payload"
        case schemaVersion = "schema_version"

        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .cardID: ColumnConstraintBinding(isPrimary: true, isNotNull: true)
            ]
        }

        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return [
                "_due": IndexBinding(indexesBy: dueAt),
                "_review_lookup": IndexBinding(indexesBy: isSuspended, state, dueAt)
            ]
        }
    }
}

private struct WCDBV3EventRow: TableCodable {
    var eventID: String?
    var cardID: String?
    var reviewedAt: Date?
    var eventPayload: Data?
    var schemaVersion: Int?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = WCDBV3EventRow
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case eventID = "event_id"
        case cardID = "card_id"
        case reviewedAt = "reviewed_at"
        case eventPayload = "event_payload"
        case schemaVersion = "schema_version"

        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            return [
                .eventID: ColumnConstraintBinding(isPrimary: true, isNotNull: true)
            ]
        }

        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            return ["_history": IndexBinding(indexesBy: cardID, reviewedAt)]
        }
    }
}

public struct WCDBV3CardInput: Sendable {
    public let cardID: UUID
    public let question: String
    public let answerText: String?
    public let choices: String?
    public let correctIndices: String?
    public let cardType: Int
    public let imageData: Data?
    public let sourceNotePath: String?

    public init(cardID: UUID = UUID(), question: String, answerText: String? = nil,
                choices: String? = nil, correctIndices: String? = nil,
                cardType: Int = 0, imageData: Data? = nil,
                sourceNotePath: String? = nil) {
        self.cardID = cardID
        self.question = question
        self.answerText = answerText
        self.choices = choices
        self.correctIndices = correctIndices
        self.cardType = cardType
        self.imageData = imageData
        self.sourceNotePath = sourceNotePath
    }
}

/// Lightweight, BLOB-free projection for the native V3 card collection.
public struct WCDBV3ManagedCard: Sendable {
    public let cardID: UUID
    public let question: String
    public let answerText: String?
    public let cardType: Int
    public let sourceNotePath: String?
    public let isSuspended: Bool
    public let revision: Int
    public let updatedAt: Date
}

public struct WCDBV3CardContent: Sendable {
    public let cardID: UUID
    public let question: String
    public let answerText: String?
    public let choices: String?
    public let correctIndices: String?
    public let cardType: Int
    public let imageData: Data?
    public let sourceNotePath: String?
}

/// An actor serializes the review transactions. The underlying WCDB connection
/// pool is thread-safe; every transaction is synchronous and has no await.
public actor ReviewWCDBRepository: ReviewRepository {
    private static let cardsTable = "impress_v3_memory_card"
    private static let eventsTable = "impress_v3_review_event"
    private static let schema = 1

    private let database: Database
    private let calculator: any WCDBReviewCalculating
    private let algorithmIdentifier: String

    /// Use an isolated V3 file, NOT the legacy impressdata.db.
    /// Schema creation failures are thrown, never swallowed.
    public init(databasePath: String, calculator: any WCDBReviewCalculating,
                algorithmIdentifier: String = "FSRS-6-default-v1") throws {
        let fileURL = URL(fileURLWithPath: databasePath)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let db = Database(withPath: databasePath)
        try db.run(transaction: {
            try db.create(table: Self.cardsTable, of: WCDBV3CardRow.self)
            try db.create(table: Self.eventsTable, of: WCDBV3EventRow.self)
        })
        database = db
        self.calculator = calculator
        self.algorithmIdentifier = algorithmIdentifier
    }

    /// Creates a new card with a full, explicitly encoded FSRS-6 initial state.
    public func insertNewCard(_ input: WCDBV3CardInput,
                              initial: ReviewScheduleSnapshot,
                              now: Date) throws {
        let row = try Self.makeNewCardRow(input, initial: initial, now: now)
        try database.insert(objects: [row], intoTable: Self.cardsTable)
        ImpressV3BackupCoordinator.markDataChanged()
    }

    /// One WCDB transaction for the entire reviewed batch. A collision or any
    /// failed insertion rolls back even rows inserted earlier in this loop.
    /// The actor serializes this against review events and ordinary card inserts.
    public func insertBatchCards(
        _ entries: [(input: WCDBV3CardInput, initial: ReviewScheduleSnapshot)],
        now: Date
    ) throws -> Int {
        guard !entries.isEmpty, entries.count <= 500 else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        let rows = try entries.map {
            try Self.makeNewCardRow($0.input, initial: $0.initial, now: now)
        }
        var ids = Set<String>()
        var content = Set<String>()
        for row in rows {
            guard let id = row.cardID, ids.insert(id).inserted else {
                throw ReviewWCDBError.duplicateCard
            }
            guard content.insert(Self.duplicateKey(row)).inserted else {
                throw ReviewWCDBError.duplicateContent
            }
        }
        let transaction = try database.getTransaction()
        try transaction.run(transaction: {
            // Look up old content *inside* the transaction, never from a
            // possibly stale earlier preview. Never mutate user cards.
            let prior: [WCDBV3CardRow] = try transaction.getObjects(
                on: [WCDBV3CardRow.Properties.question,
                     WCDBV3CardRow.Properties.sourceNotePath],
                fromTable: Self.cardsTable
            )
            let existingContent = Set(prior.map(Self.duplicateKey))
            for row in rows {
                guard !existingContent.contains(Self.duplicateKey(row)) else {
                    throw ReviewWCDBError.duplicateContent
                }
                let priorID: WCDBV3CardRow? = try transaction.getObject(
                    fromTable: Self.cardsTable,
                    where: WCDBV3CardRow.Properties.cardID == row.cardID!
                )
                guard priorID == nil else { throw ReviewWCDBError.duplicateCard }
                try transaction.insert(objects: [row], intoTable: Self.cardsTable)
            }
        })
        ImpressV3BackupCoordinator.markDataChanged()
        return rows.count
    }

    private static func duplicateKey(_ row: WCDBV3CardRow) -> String {
        let question = (row.question ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
        return (row.sourceNotePath ?? "") + "\u{001F}" + question
    }

    private static func makeNewCardRow(_ input: WCDBV3CardInput,
                                       initial: ReviewScheduleSnapshot,
                                       now: Date) throws -> WCDBV3CardRow {
        guard !input.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              initial.cardID == input.cardID,
              initial.revision == 0,
              initial.lastReviewedAt == nil,
              !initial.schedulerPayload.isEmpty,
              initial.dueAt.timeIntervalSince1970.isFinite,
              [0, 2, 3].contains(input.cardType),
              (input.cardType != 0 || !(input.answerText ?? "").isEmpty),
              (input.cardType != 2 || (!(input.choices ?? "").isEmpty && !(input.correctIndices ?? "").isEmpty)),
              (input.cardType != 3 || input.imageData != nil) else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        var row = WCDBV3CardRow()
        row.cardID = input.cardID.uuidString
        row.question = input.question
        row.answerText = input.answerText
        row.choices = input.choices
        row.correctIndices = input.correctIndices
        row.cardType = input.cardType
        row.imageData = input.imageData
        row.sourceNotePath = input.sourceNotePath
        row.createdAt = now
        row.updatedAt = now
        row.revision = 0
        row.isSuspended = 0
        row.state = ReviewCardStatus.new.rawValue
        row.dueAt = initial.dueAt
        row.schedulerPayload = initial.schedulerPayload
        row.schemaVersion = Self.schema
        return row
    }

    /// BLOB-free browse/search. Offset and limit are applied after filtering,
    /// preserving results across card types without loading image_data.
    /// An indexed database-side search can replace this projection later.
    public func listManagedCards(matching search: String = "",
                                 offset: Int = 0,
                                 limit: Int = 100) throws -> [WCDBV3ManagedCard] {
        guard offset >= 0, (1...200).contains(limit) else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        let rows: [WCDBV3CardRow] = try database.getObjects(
            on: [
                WCDBV3CardRow.Properties.cardID,
                WCDBV3CardRow.Properties.question,
                WCDBV3CardRow.Properties.answerText,
                WCDBV3CardRow.Properties.cardType,
                WCDBV3CardRow.Properties.sourceNotePath,
                WCDBV3CardRow.Properties.isSuspended,
                WCDBV3CardRow.Properties.revision,
                WCDBV3CardRow.Properties.updatedAt
            ], fromTable: Self.cardsTable)
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return try rows.filter { row in
            query.isEmpty || [row.question, row.answerText, row.sourceNotePath]
                .compactMap { $0 }
                .contains { $0.localizedStandardContains(query) }
        }.sorted {
            ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
        }.dropFirst(min(offset, rows.count)).prefix(limit).map { row in
            guard let rawID = row.cardID, let id = UUID(uuidString: rawID),
                  let question = row.question, let type = row.cardType,
                  let suspended = row.isSuspended, let revision = row.revision else {
                throw ReviewWCDBError.corruptRecord
            }
            return WCDBV3ManagedCard(cardID: id, question: question,
                answerText: row.answerText, cardType: type,
                sourceNotePath: row.sourceNotePath,
                isSuspended: suspended != 0, revision: revision,
                updatedAt: row.updatedAt ?? .distantPast)
        }
    }

    /// Update only content fields. Card identity, FSRS revision/schedule and
    /// immutable review events remain intact. Optimistic version check prevents
    /// editing a row concurrently changed by an in-flight grading operation.
    public func updateManagedCard(_ input: WCDBV3CardInput,
                                  expectedRevision: Int,
                                  now: Date = Date()) throws {
        guard !input.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              [0, 2, 3].contains(input.cardType),
              (input.cardType != 0 || !(input.answerText ?? "").isEmpty),
              (input.cardType != 2 ||
                 (!(input.choices ?? "").isEmpty &&
                  !(input.correctIndices ?? "").isEmpty)),
              (input.cardType != 3 || input.imageData != nil) else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        let key = input.cardID.uuidString
        let tx = try database.getTransaction()
        try tx.run(transaction: {
            guard let old: WCDBV3CardRow = try tx.getObject(
                fromTable: Self.cardsTable,
                where: WCDBV3CardRow.Properties.cardID == key)
            else { throw ReviewWCDBError.missingCard }
            guard old.revision == expectedRevision else {
                throw ReviewWCDBError.revisionConflict
            }
            let all: [WCDBV3CardRow] = try tx.getObjects(
                on: [WCDBV3CardRow.Properties.cardID,
                     WCDBV3CardRow.Properties.question,
                     WCDBV3CardRow.Properties.sourceNotePath],
                fromTable: Self.cardsTable)
            var edited = old
            edited.question = input.question
            edited.answerText = input.answerText
            edited.choices = input.choices
            edited.correctIndices = input.correctIndices
            edited.cardType = input.cardType
            edited.imageData = input.imageData
            edited.sourceNotePath = input.sourceNotePath
            edited.updatedAt = now
            guard !all.contains(where: {
                $0.cardID != key && Self.duplicateKey($0) == Self.duplicateKey(edited)
            }) else { throw ReviewWCDBError.duplicateContent }
            try tx.update(table: Self.cardsTable, on: [
                WCDBV3CardRow.Properties.question,
                WCDBV3CardRow.Properties.answerText,
                WCDBV3CardRow.Properties.choices,
                WCDBV3CardRow.Properties.correctIndices,
                WCDBV3CardRow.Properties.cardType,
                WCDBV3CardRow.Properties.imageData,
                WCDBV3CardRow.Properties.sourceNotePath,
                WCDBV3CardRow.Properties.updatedAt
            ], with: edited,
               where: WCDBV3CardRow.Properties.cardID == key &&
                      WCDBV3CardRow.Properties.revision == expectedRevision)
            guard tx.changes == 1 else { throw ReviewWCDBError.revisionConflict }
        })
        ImpressV3BackupCoordinator.markDataChanged()
    }

    public func setManagedCardSuspended(_ suspended: Bool,
                                        id: UUID,
                                        expectedRevision: Int) throws {
        let tx = try database.getTransaction()
        try tx.run(transaction: {
            guard let old: WCDBV3CardRow = try tx.getObject(
                fromTable: Self.cardsTable,
                where: WCDBV3CardRow.Properties.cardID == id.uuidString)
            else { throw ReviewWCDBError.missingCard }
            guard old.revision == expectedRevision else {
                throw ReviewWCDBError.revisionConflict
            }
            var updated = old
            updated.isSuspended = suspended ? 1 : 0
            updated.updatedAt = Date()
            try tx.update(table: Self.cardsTable,
                on: [WCDBV3CardRow.Properties.isSuspended,
                     WCDBV3CardRow.Properties.updatedAt],
                with: updated,
                where: WCDBV3CardRow.Properties.cardID == id.uuidString &&
                       WCDBV3CardRow.Properties.revision == expectedRevision)
            guard tx.changes == 1 else { throw ReviewWCDBError.revisionConflict }
        })
        ImpressV3BackupCoordinator.markDataChanged()
    }

    /// Explicit destructive action only. Removes the card and its review-event
    /// rows atomically; never affects source notes or independent learning logs.
    public func deleteManagedCard(id: UUID,
                                  expectedRevision: Int) throws {
        let tx = try database.getTransaction()
        try tx.run(transaction: {
            guard let old: WCDBV3CardRow = try tx.getObject(
                fromTable: Self.cardsTable,
                where: WCDBV3CardRow.Properties.cardID == id.uuidString)
            else { throw ReviewWCDBError.missingCard }
            guard old.revision == expectedRevision else {
                throw ReviewWCDBError.revisionConflict
            }
            try tx.delete(fromTable: Self.eventsTable,
                where: WCDBV3EventRow.Properties.cardID == id.uuidString)
            try tx.delete(fromTable: Self.cardsTable,
                where: WCDBV3CardRow.Properties.cardID == id.uuidString &&
                       WCDBV3CardRow.Properties.revision == expectedRevision)
            guard tx.changes == 1 else { throw ReviewWCDBError.revisionConflict }
        })
        ImpressV3BackupCoordinator.markDataChanged()
    }

    /// One transaction: event replay check, optimistic revision check, state
    /// update, row-count verification, immutable event insert.
    public func commit(_ submission: ReviewSubmission) async throws -> ReviewEvent {
        let eventKey = submission.eventID.uuidString
        let cardKey = submission.cardID.uuidString
        let transaction = try database.getTransaction()
        var outcome: ReviewEvent?

        do {
            try transaction.run(transaction: {
                let previousEvent: WCDBV3EventRow? = try transaction.getObject(
                    fromTable: Self.eventsTable,
                    where: WCDBV3EventRow.Properties.eventID == eventKey)
                if let previousEvent = previousEvent {
                    let event = try Self.decodeEvent(previousEvent)
                    try Self.assertSameRequest(event, submission)
                    outcome = event
                    return
                }

                guard let row: WCDBV3CardRow = try transaction.getObject(
                    fromTable: Self.cardsTable,
                    where: WCDBV3CardRow.Properties.cardID == cardKey)
                else { throw ReviewWCDBError.missingCard }
                guard let suspension = row.isSuspended else { throw ReviewWCDBError.corruptRecord }
                guard suspension == 0 else { throw ReviewWCDBError.suspendedCard }
                guard row.revision == submission.expectedRevision else {
                    throw ReviewWCDBError.revisionConflict
                }

                let before = try Self.decodeSnapshot(row, id: submission.cardID)
                guard let currentStatus = ReviewCardStatus(rawValue: row.state ?? -1),
                      currentStatus != .new || row.lastReviewedAt == nil else {
                    throw ReviewWCDBError.corruptRecord
                }

                let calculated = try calculator.next(
                    before: before, status: currentStatus, submission: submission)
                let after = calculated.snapshot
                guard after.cardID == submission.cardID,
                      after.revision == before.revision + 1,
                      after.lastReviewedAt == submission.reviewedAt,
                      after.dueAt.timeIntervalSince1970.isFinite,
                      !after.schedulerPayload.isEmpty else {
                    throw ReviewWCDBError.invalidSchedulerOutput
                }

                var nextRow = row
                nextRow.revision = after.revision
                nextRow.state = calculated.status.rawValue
                nextRow.dueAt = after.dueAt
                nextRow.lastReviewedAt = after.lastReviewedAt
                nextRow.schedulerPayload = after.schedulerPayload
                nextRow.updatedAt = submission.reviewedAt

                try transaction.update(
                    table: Self.cardsTable,
                    on: [
                        WCDBV3CardRow.Properties.revision,
                        WCDBV3CardRow.Properties.state,
                        WCDBV3CardRow.Properties.dueAt,
                        WCDBV3CardRow.Properties.lastReviewedAt,
                        WCDBV3CardRow.Properties.schedulerPayload,
                        WCDBV3CardRow.Properties.updatedAt
                    ],
                    with: nextRow,
                    where: WCDBV3CardRow.Properties.cardID == cardKey
                        && WCDBV3CardRow.Properties.revision == submission.expectedRevision
                )
                guard transaction.changes == 1 else {
                    throw ReviewWCDBError.revisionConflict
                }

                let event = ReviewEvent(
                    eventID: submission.eventID, cardID: submission.cardID,
                    rating: submission.rating, reviewedAt: submission.reviewedAt,
                    before: before, after: after,
                    algorithmIdentifier: algorithmIdentifier
                )
                var eventRow = WCDBV3EventRow()
                eventRow.eventID = eventKey
                eventRow.cardID = cardKey
                eventRow.reviewedAt = submission.reviewedAt
                eventRow.eventPayload = try JSONEncoder().encode(event)
                eventRow.schemaVersion = Self.schema
                try transaction.insert(objects: [eventRow], intoTable: Self.eventsTable)
                outcome = event
            })
        } catch {
            #if DEBUG
            NSLog("Impress V3 review transaction rejected: %@", String(describing: error))
            #endif
            // Commit acknowledgements can be ambiguous. If the event exists,
            // it and its card state were committed in the same transaction.
            if let persisted: WCDBV3EventRow = try? database.getObject(
                fromTable: Self.eventsTable,
                where: WCDBV3EventRow.Properties.eventID == eventKey) {
                let event = try Self.decodeEvent(persisted)
                try Self.assertSameRequest(event, submission)
                return event
            }
            throw error
        }
        guard let result = outcome else { throw ReviewWCDBError.corruptRecord }
        ImpressV3BackupCoordinator.markDataChanged()
        return result
    }

    /// Projection excludes question, answer, picture BLOB, and scheduler payload.
    public func fetchQueueCandidates() throws -> [ReviewQueueCandidate] {
        let projected: [WCDBV3CardRow] = try database.getObjects(
            on: [
                WCDBV3CardRow.Properties.cardID,
                WCDBV3CardRow.Properties.revision,
                WCDBV3CardRow.Properties.state,
                WCDBV3CardRow.Properties.dueAt,
                WCDBV3CardRow.Properties.createdAt,
                WCDBV3CardRow.Properties.isSuspended
            ],
            fromTable: Self.cardsTable
        )
        return try projected.map { row in
            guard let idText = row.cardID,
                  let id = UUID(uuidString: idText),
                  let version = row.revision,
                  let stateCode = row.state,
                  let status = ReviewCardStatus(rawValue: stateCode),
                  let due = row.dueAt,
                  let created = row.createdAt,
                  let suspension = row.isSuspended
            else { throw ReviewWCDBError.corruptRecord }
            return ReviewQueueCandidate(
                cardID: id, revision: version, status: status,
                dueAt: due, createdAt: created, isSuspended: suspension != 0
            )
        }
    }

    public func dueCount(at now: Date) throws -> Int {
        let condition = WCDBV3CardRow.Properties.isSuspended == 0
            && WCDBV3CardRow.Properties.state != ReviewCardStatus.new.rawValue
            && WCDBV3CardRow.Properties.dueAt <= now
        let result = try database.getRow(
            on: Column.all.count(), fromTable: Self.cardsTable, where: condition)
        return Int(result.first?.int64Value ?? 0)
    }

    /// Copy only a quiescent WCDB database. Closing all WCDB handles flushes
    /// the WAL to the main database before copying. The repository actor has no
    /// reentrant awaits inside this operation, so no new V3 write can race.
    /// This is deliberately separate from the legacy folder ZIP backup.
    /// The destination MUST be a fresh path; existing backups are not replaced.
    public func createConsistentBackup(to destination: URL) throws {
        let fileManager = FileManager.default
        let source = URL(fileURLWithPath: database.path)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        try fileManager.createDirectory(
            at: destination.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".impress-snapshot-" + UUID().uuidString)
        do {
            try database.close(onClosed: {
                try fileManager.copyItem(at: source, to: staging)
            })
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    /// Fetch the heavy image only when this card is about to be presented.
    public func content(for cardID: UUID) throws -> WCDBV3CardContent? {
        guard let row: WCDBV3CardRow = try database.getObject(
            fromTable: Self.cardsTable,
            where: WCDBV3CardRow.Properties.cardID == cardID.uuidString)
        else { return nil }
        guard let question = row.question, let cardType = row.cardType else {
            throw ReviewWCDBError.corruptRecord
        }
        return WCDBV3CardContent(
            cardID: cardID, question: question, answerText: row.answerText,
            choices: row.choices, correctIndices: row.correctIndices,
            cardType: cardType, imageData: row.imageData,
            sourceNotePath: row.sourceNotePath
        )
    }

    public func reviewHistory(for cardID: UUID) throws -> [ReviewEvent] {
        let rows: [WCDBV3EventRow] = try database.getObjects(
            fromTable: Self.eventsTable,
            where: WCDBV3EventRow.Properties.cardID == cardID.uuidString,
            orderBy: [WCDBV3EventRow.Properties.reviewedAt.asOrder(by: .ascending)]
        )
        return try rows.map { try Self.decodeEvent($0) }
    }

    private static func decodeSnapshot(
        _ row: WCDBV3CardRow, id: UUID) throws -> ReviewScheduleSnapshot {
        guard let revision = row.revision,
              let due = row.dueAt,
              let payload = row.schedulerPayload,
              !payload.isEmpty,
              due.timeIntervalSince1970.isFinite else {
            throw ReviewWCDBError.corruptRecord
        }
        return ReviewScheduleSnapshot(
            cardID: id, revision: revision, dueAt: due,
            lastReviewedAt: row.lastReviewedAt, schedulerPayload: payload
        )
    }

    private static func decodeEvent(_ row: WCDBV3EventRow) throws -> ReviewEvent {
        guard let data = row.eventPayload else { throw ReviewWCDBError.corruptRecord }
        return try JSONDecoder().decode(ReviewEvent.self, from: data)
    }

    private static func assertSameRequest(
        _ event: ReviewEvent, _ request: ReviewSubmission) throws {
        guard event.eventID == request.eventID,
              event.cardID == request.cardID,
              event.rating == request.rating,
              event.reviewedAt == request.reviewedAt,
              event.before.revision == request.expectedRevision else {
            throw ReviewWCDBError.eventIdentifierCollision
        }
    }
}
