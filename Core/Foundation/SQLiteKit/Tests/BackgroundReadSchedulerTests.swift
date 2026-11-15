import CustomDump
import Foundation
import SQLiteData
import Synchronization
import Testing
@testable import SQLiteKit

// MARK: - BackgroundReadSchedulerTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct BackgroundReadSchedulerTests {
    private let schema = DatabaseSchema { migrator in
        migrator.registerMigration("Create note") { db in
            try db.execute(sql: #"CREATE TABLE "note" ("id" INTEGER PRIMARY KEY, "text" TEXT NOT NULL) STRICT"#)
        }
    }

    @Test
    func `a load reads its query off the main thread and keeps observing it`() async throws {
        let directory = URL.temporaryDirectory.appending(
            path: "BackgroundReadSchedulerTests-\(UUID().uuidString)",
            directoryHint: .isDirectory,
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let database = try AppDatabase.open(at: directory.appending(path: "openskatemap.sqlite"), schemas: [schema])
        try await database.write { db in try db.execute(sql: #"INSERT INTO "note" ("text") VALUES ('kept')"#) }
        let notes = Fetch(wrappedValue: [String]())

        try await notes.load(NoteTexts(), database: database, scheduler: .backgroundRead)
        let loaded = notes.wrappedValue
        try await database.write { db in try db.execute(sql: #"INSERT INTO "note" ("text") VALUES ('added')"#) }
        for await texts in Observations({ notes.wrappedValue }) where texts.count == 2 {
            break
        }

        expectNoDifference(loaded, ["kept"])
        expectNoDifference(notes.wrappedValue, ["kept", "added"])
        expectNoDifference(NoteTexts.mainThreadReads.withLock { $0 }, 0)
    }
}

// MARK: - NoteTexts

private struct NoteTexts: FetchKeyRequest {
    static let mainThreadReads = Mutex(0)

    func fetch(_ db: Database) throws -> [String] {
        if Thread.isMainThread {
            Self.mainThreadReads.withLock { $0 += 1 }
        }
        return try String.fetchAll(db, sql: #"SELECT "text" FROM "note" ORDER BY "id""#)
    }
}
