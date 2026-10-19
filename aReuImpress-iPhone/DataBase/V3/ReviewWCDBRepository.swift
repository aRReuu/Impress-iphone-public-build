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
    case contentConflict
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
    var contentRevision: Int?
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
        case contentRevision = "content_revision"
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

/// Immutable content snapshots are separate from ReviewEvent/FSRS scheduling.
/// A stable (cardID, contentRevision) ID prevents duplicate history on retries.
private struct WCDBV3ContentVersionRow: TableCodable {
    var versionID: String?
    var cardID: String?
    var contentRevision: Int?
    var recordedAt: Date?
    var snapshot: Data?

    enum CodingKeys: String, CodingTableKey {
        typealias Root = WCDBV3ContentVersionRow
        static let objectRelationalMapping = TableBinding(CodingKeys.self)
        case versionID = "version_id"
        case cardID = "card_id"
        case contentRevision = "content_revision"
        case recordedAt = "recorded_at"
        case snapshot

        static var columnConstraintBindings: [CodingKeys: ColumnConstraintBinding]? {
            [.versionID: ColumnConstraintBinding(isPrimary: true, isNotNull: true)]
        }
        static var indexBindings: [IndexBinding.Subfix: IndexBinding]? {
            ["_by_card": IndexBinding(indexesBy: cardID, contentRevision)]
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
    /// Independent of FSRS review revision. Incremented only by content edits.
    public let contentRevision: Int
}

/// The exact fields that were effective at a particular content revision.
/// Existing cards only gain history from the first version actually observed:
/// we NEVER synthesize the inaccessible revisions of an old installation.
public enum WCDBV3ContentVersionOrigin: String, Codable, Sendable {
    case manual, approvedAI, restored, observedBaseline
}

public struct WCDBV3ContentVersion: Codable, Equatable, Sendable {
    public let cardID: UUID
    public let contentRevision: Int
    public let recordedAt: Date
    public let origin: WCDBV3ContentVersionOrigin
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
    private static let contentVersionsTable = "impress_v3_content_version"
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
        // A device already running V3 may have the pre-R04.2 card table
        // without content_revision. Upgrade that table in-place before WCDB
        // prepares ORM bindings; never discard the live database or events.
        try Self.migrateContentRevisionIfNeeded(at: databasePath)
        let db = Database(withPath: databasePath)
        try db.run(transaction: {
            try db.create(table: Self.cardsTable, of: WCDBV3CardRow.self)
            try db.create(table: Self.eventsTable, of: WCDBV3EventRow.self)
            try db.create(table: Self.contentVersionsTable, of: WCDBV3ContentVersionRow.self)
        })
        database = db
        self.calculator = calculator
        self.algorithmIdentifier = algorithmIdentifier
    }


    /// Idempotent, transactionally adds the R04.2 content CAS column to the
    /// existing V3 table. A fresh install remains owned by WCDB's ORM create.
    /// SQLite ALTER TABLE retains all original rows, blobs, and FSRS events.
    private static func migrateContentRevisionIfNeeded(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else { return }
        var connection: OpaquePointer?
        let openResult = path.withCString {
            sqlite3_open_v2($0, &connection, SQLITE_OPEN_READWRITE, nil)
        }
        guard openResult == SQLITE_OK, let db = connection else {
            if let connection { sqlite3_close(connection) }
            throw ReviewWCDBError.corruptRecord
        }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db,
            "PRAGMA table_info(impress_v3_memory_card);", -1,
            &statement, nil) == SQLITE_OK, let query = statement else {
            if let statement { sqlite3_finalize(statement) }
            throw ReviewWCDBError.corruptRecord
        }
        var hasTable = false
        var hasColumn = false
        var result = sqlite3_step(query)
        while result == SQLITE_ROW {
            hasTable = true
            if let name = sqlite3_column_text(query, 1),
               String(cString: UnsafeRawPointer(name)
                    .assumingMemoryBound(to: CChar.self)) == "content_revision" {
                hasColumn = true
            }
            result = sqlite3_step(query)
        }
        sqlite3_finalize(query)
        guard result == SQLITE_DONE else { throw ReviewWCDBError.corruptRecord }
        guard hasTable && !hasColumn else { return }
        guard sqlite3_exec(db, "BEGIN IMMEDIATE;", nil, nil, nil) == SQLITE_OK else {
            throw ReviewWCDBError.corruptRecord
        }
        do {
            // The default backfills pre-R04.2 cards with content revision zero.
            guard sqlite3_exec(db,
                "ALTER TABLE impress_v3_memory_card " +
                "ADD COLUMN content_revision INTEGER NOT NULL DEFAULT 0;",
                nil, nil, nil) == SQLITE_OK else { throw ReviewWCDBError.corruptRecord }
            guard sqlite3_exec(db, "COMMIT;", nil, nil, nil) == SQLITE_OK else {
                throw ReviewWCDBError.corruptRecord
            }
        } catch {
            _ = sqlite3_exec(db, "ROLLBACK;", nil, nil, nil)
            throw error
        }
    }

    #if DEBUG
    /// Creates a disposable legacy V3 fixture with the application's existing
    /// SQLCipher-compatible SQLite import. Never called during normal startup.
    static func seedPreR042FixtureForTesting(at path: String, cardID: UUID) throws {
        // SQLite OPEN_CREATE creates a file, not its enclosing directory.
        // This fixture is an isolated pre-R04.2 V3 database, never user data.
        try FileManager.default.createDirectory(
            at: URL(fileURLWithPath: path).deletingLastPathComponent(),
            withIntermediateDirectories: true)
        var pointer: OpaquePointer?
        let result = path.withCString {
            sqlite3_open_v2($0, &pointer,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        }
        guard result == SQLITE_OK, let db = pointer else {
            if let pointer { sqlite3_close(pointer) }
            throw ReviewWCDBError.corruptRecord
        }
        defer { sqlite3_close(db) }
        func execute(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
                throw ReviewWCDBError.corruptRecord
            }
        }
        try execute("""
            CREATE TABLE impress_v3_memory_card (
                card_id TEXT PRIMARY KEY, question TEXT, answer_text TEXT,
                choices TEXT, correct_indices TEXT, card_type INTEGER,
                image_data BLOB, source_note_path TEXT, created_at REAL,
                updated_at REAL, revision INTEGER, is_suspended INTEGER,
                state INTEGER, due_at REAL, last_reviewed_at REAL,
                scheduler_payload BLOB, schema_version INTEGER
            );
            """)
        try execute("""
            CREATE TABLE impress_v3_review_event (
                event_id TEXT PRIMARY KEY, card_id TEXT, reviewed_at REAL,
                event_payload BLOB, schema_version INTEGER
            );
            """)
        try execute("""
            INSERT INTO impress_v3_memory_card
                (card_id, question, answer_text, card_type, revision,
                 is_suspended, state, due_at, created_at, updated_at,
                 scheduler_payload, schema_version)
            VALUES ('\(cardID.uuidString)', 'Original saved V3',
                    'Do not discard', 0, 0, 0, 0, 1720000000,
                    1720000000, 1720000000, X'0102', 1);
            """)
    }
    #endif

    /// Creates a new card with a full, explicitly encoded FSRS-6 initial state.
    public func insertNewCard(_ input: WCDBV3CardInput,
                              initial: ReviewScheduleSnapshot,
                              now: Date) throws {
        let row = try Self.makeNewCardRow(input, initial: initial, now: now)
        let tx = try database.getTransaction()
        try tx.run(transaction: {
            try tx.insert(objects: [row], intoTable: Self.cardsTable)
            let version = try Self.makeContentVersionRow(
                row, origin: .manual, recordedAt: now)
            try tx.insert(objects: [version], intoTable: Self.contentVersionsTable)
        })
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
                let version = try Self.makeContentVersionRow(
                    row, origin: .manual, recordedAt: now)
                try transaction.insert(objects: [version], intoTable: Self.contentVersionsTable)
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
        row.contentRevision = 0
        row.isSuspended = 0
        row.state = ReviewCardStatus.new.rawValue
        row.dueAt = initial.dueAt
        row.schedulerPayload = initial.schedulerPayload
        row.schemaVersion = Self.schema
        return row
    }

    /// SQL-backed, BLOB-free sorted pagination for normal queries.
    /// Literal SQL LIKE wildcards use a bounded fallback scan so searching for
    /// "%" or "_" cannot broaden matches and never allocates the entire table.
    public func listManagedCards(matching search: String = "",
                                 offset: Int = 0,
                                 limit: Int = 100) throws -> [WCDBV3ManagedCard] {
        guard offset >= 0, (1...200).contains(limit) else {
            throw ReviewWCDBError.invalidSchedulerOutput
        }
        let selected = [
            WCDBV3CardRow.Properties.cardID,
            WCDBV3CardRow.Properties.question,
            WCDBV3CardRow.Properties.answerText,
            WCDBV3CardRow.Properties.cardType,
            WCDBV3CardRow.Properties.sourceNotePath,
            WCDBV3CardRow.Properties.isSuspended,
            WCDBV3CardRow.Properties.revision,
            WCDBV3CardRow.Properties.updatedAt
        ]
        // The secondary key makes pagination deterministic for equal timestamps.
        let ordering = [
            WCDBV3CardRow.Properties.updatedAt.asOrder(by: .descending),
            WCDBV3CardRow.Properties.cardID.asOrder(by: .ascending)
        ]
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        let rows: [WCDBV3CardRow]
        if query.isEmpty {
            rows = try database.getObjects(on: selected, fromTable: Self.cardsTable,
                orderBy: ordering, limit: limit, offset: offset)
        } else if !query.contains("%") && !query.contains("_") {
            // WCDB escapes SQL parameters: never interpolate into raw SQL.
            // Common searches use SQLite filtering *before* LIMIT/OFFSET.
            let pattern = "%" + query + "%"
            let matching = WCDBV3CardRow.Properties.question.like(pattern)
                || WCDBV3CardRow.Properties.answerText.like(pattern)
                || WCDBV3CardRow.Properties.sourceNotePath.like(pattern)
            rows = try database.getObjects(on: selected, fromTable: Self.cardsTable,
                where: matching, orderBy: ordering, limit: limit, offset: offset)
        } else {
            // SQLite LIKE treats _ and % as wildcards. Use bounded chunks
            // and a literal comparison to avoid false-positive search results.
            var collected = [WCDBV3CardRow]()
            var scanned = 0
            var matched = 0
            while collected.count < limit {
                let block: [WCDBV3CardRow] = try database.getObjects(
                    on: selected, fromTable: Self.cardsTable, orderBy: ordering,
                    limit: 200, offset: scanned)
                if block.isEmpty { break }
                for row in block where [row.question, row.answerText, row.sourceNotePath]
                    .compactMap({ $0 }).contains(where: { $0.localizedStandardContains(query) }) {
                    if matched >= offset && collected.count < limit {
                        collected.append(row)
                    }
                    matched += 1
                }
                scanned += block.count
            }
            rows = collected
        }
        return try rows.map { row in
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
    /// immutable review events remain intact. Two independent CAS tokens stop
    /// a stale editor after either an FSRS commit or another content edit.
    public func updateManagedCard(_ input: WCDBV3CardInput,
                                  expectedRevision: Int,
                                  expectedContentRevision: Int,
                                  now: Date = Date(),
                                  origin: WCDBV3ContentVersionOrigin = .manual) throws {
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
        var didChange = false
        try tx.run(transaction: {
            guard let old: WCDBV3CardRow = try tx.getObject(
                fromTable: Self.cardsTable,
                where: WCDBV3CardRow.Properties.cardID == key)
            else { throw ReviewWCDBError.missingCard }
            guard old.revision == expectedRevision else {
                throw ReviewWCDBError.revisionConflict
            }
            guard (old.contentRevision ?? 0) == expectedContentRevision else {
                throw ReviewWCDBError.contentConflict
            }
            // A save with no effective edits must not create a noise version,
            // change updatedAt, invalidate the current answer or dirty backup.
            guard !Self.sameContent(old, input) else { return }
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
            edited.contentRevision = expectedContentRevision + 1
            guard !all.contains(where: {
                $0.cardID != key && Self.duplicateKey($0) == Self.duplicateKey(edited)
            }) else { throw ReviewWCDBError.duplicateContent }
            // Pre-upgrade cards did not have recorded history. Snapshot the
            // currently observed content (never invent revisions -1, -2...).
            let existing: WCDBV3ContentVersionRow? = try tx.getObject(
                fromTable: Self.contentVersionsTable,
                where: WCDBV3ContentVersionRow.Properties.versionID ==
                    Self.contentVersionID(cardID: key, revision: expectedContentRevision))
            if existing == nil {
                try tx.insert(objects: [Self.makeContentVersionRow(
                    old, origin: .observedBaseline, recordedAt: now)],
                    intoTable: Self.contentVersionsTable)
            }
            try tx.update(table: Self.cardsTable, on: [
                WCDBV3CardRow.Properties.question,
                WCDBV3CardRow.Properties.answerText,
                WCDBV3CardRow.Properties.choices,
                WCDBV3CardRow.Properties.correctIndices,
                WCDBV3CardRow.Properties.cardType,
                WCDBV3CardRow.Properties.imageData,
                WCDBV3CardRow.Properties.sourceNotePath,
                WCDBV3CardRow.Properties.updatedAt,
                WCDBV3CardRow.Properties.contentRevision
            ], with: edited,
               where: WCDBV3CardRow.Properties.cardID == key &&
                      WCDBV3CardRow.Properties.revision == expectedRevision)
            guard tx.changes == 1 else { throw ReviewWCDBError.revisionConflict }
            // This insert and the current-content CAS are inseparable.
            try tx.insert(objects: [Self.makeContentVersionRow(
                edited, origin: origin, recordedAt: now)],
                intoTable: Self.contentVersionsTable)
            didChange = true
        })
        if didChange { ImpressV3BackupCoordinator.markDataChanged() }
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

    /// The content history is not the FSRS ReviewEvent history.
    /// Deleted card IDs retain snapshots for explicit archival/recovery;
    /// no title-based guessing is performed.
    public func contentHistory(for cardID: UUID) throws -> [WCDBV3ContentVersion] {
        let rows: [WCDBV3ContentVersionRow] = try database.getObjects(
            fromTable: Self.contentVersionsTable,
            where: WCDBV3ContentVersionRow.Properties.cardID == cardID.uuidString,
            orderBy: [WCDBV3ContentVersionRow.Properties.contentRevision.asOrder(by: .ascending)])
        return try rows.map { row in
            guard let blob = row.snapshot else { throw ReviewWCDBError.corruptRecord }
            let decoded = try JSONDecoder().decode(WCDBV3ContentVersion.self, from: blob)
            guard decoded.cardID == cardID,
                  decoded.contentRevision == row.contentRevision,
                  row.versionID == Self.contentVersionID(
                      cardID: cardID.uuidString, revision: decoded.contentRevision)
            else { throw ReviewWCDBError.corruptRecord }
            return decoded
        }
    }

    /// Restore creates a NEW effective version. Intermediate content revisions,
    /// their media BLOBs, and every FSRS event remain immutable.
    public func restoreContentVersion(cardID: UUID, savedRevision: Int,
                                      expectedContentRevision: Int,
                                      expectedReviewRevision: Int,
                                      now: Date = Date()) throws {
        guard let version = try contentHistory(for: cardID)
            .first(where: { $0.contentRevision == savedRevision }) else {
            throw ReviewWCDBError.missingCard
        }
        try updateManagedCard(
            WCDBV3CardInput(cardID: cardID, question: version.question,
                            answerText: version.answerText, choices: version.choices,
                            correctIndices: version.correctIndices,
                            cardType: version.cardType, imageData: version.imageData,
                            sourceNotePath: version.sourceNotePath),
            expectedRevision: expectedReviewRevision,
            expectedContentRevision: expectedContentRevision,
            now: now, origin: .restored)
    }

    private static func contentVersionID(cardID: String, revision: Int) -> String {
        cardID + ":" + String(revision)
    }

    private static func sameContent(_ old: WCDBV3CardRow,
                                    _ input: WCDBV3CardInput) -> Bool {
        old.question == input.question &&
        old.answerText == input.answerText &&
        old.choices == input.choices &&
        old.correctIndices == input.correctIndices &&
        old.cardType == input.cardType &&
        old.imageData == input.imageData &&
        old.sourceNotePath == input.sourceNotePath
    }

    private static func makeContentVersionRow(_ card: WCDBV3CardRow,
                                              origin: WCDBV3ContentVersionOrigin,
                                              recordedAt: Date) throws -> WCDBV3ContentVersionRow {
        guard let rawID = card.cardID, let cardID = UUID(uuidString: rawID),
              let revision = card.contentRevision, revision >= 0,
              let question = card.question, let cardType = card.cardType else {
            throw ReviewWCDBError.corruptRecord
        }
        let snapshot = WCDBV3ContentVersion(
            cardID: cardID, contentRevision: revision,
            recordedAt: recordedAt, origin: origin, question: question,
            answerText: card.answerText, choices: card.choices,
            correctIndices: card.correctIndices, cardType: cardType,
            imageData: card.imageData, sourceNotePath: card.sourceNotePath)
        var row = WCDBV3ContentVersionRow()
        row.versionID = contentVersionID(cardID: rawID, revision: revision)
        row.cardID = rawID
        row.contentRevision = revision
        row.recordedAt = recordedAt
        row.snapshot = try JSONEncoder().encode(snapshot)
        return row
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
            sourceNotePath: row.sourceNotePath,
            contentRevision: row.contentRevision ?? 0
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
