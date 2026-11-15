import CustomDump
import Foundation
import SQLiteData
import Testing
@testable import SQLiteKit

@Suite(.timeLimit(.minutes(1)))
struct AppDatabaseTests {
    private let schema = DatabaseSchema { migrator in
        migrator.registerMigration("Create note") { db in
            try db.execute(sql: #"CREATE TABLE "note" ("id" INTEGER PRIMARY KEY, "text" TEXT NOT NULL) STRICT"#)
        }
    }

    @Test
    func `schemas migrate in the order they are given`() throws {
        let second = DatabaseSchema { migrator in
            migrator.registerMigration("Add note.pinned") { db in
                try db.execute(sql: #"ALTER TABLE "note" ADD COLUMN "pinned" INTEGER NOT NULL DEFAULT 0"#)
            }
        }
        let database = try AppDatabase.inMemory(schemas: [schema, second])

        let columns = try database.read { db in try db.columns(in: "note").map(\.name) }

        expectNoDifference(columns, ["id", "text", "pinned"])
    }

    @Test
    func `a file that is not a database is replaced instead of breaking the launch`() throws {
        let url = URL.temporaryDirectory.appending(path: "AppDatabaseTests-\(UUID().uuidString)/broken.sqlite")
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not a database".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let database = AppDatabase.openOrRecover(at: url, schemas: [schema])
        try database.write { db in try db.execute(sql: #"INSERT INTO "note" ("text") VALUES ('hello')"#) }

        expectNoDifference(try database.read { db in try String.fetchOne(db, sql: #"SELECT "text" FROM "note""#) }, "hello")
        #expect(database is DatabasePool)
    }

    @Test
    func `a stored file its migrations fail on is replaced`() throws {
        let url = try temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        try AppDatabase.open(at: url, schemas: [schema]).write { db in
            try db.execute(sql: #"INSERT INTO "note" ("text") VALUES ('twice'), ('twice')"#)
        }
        let unique = DatabaseSchema { migrator in
            migrator.registerMigration("Make note.text unique") { db in
                try db.execute(sql: #"CREATE UNIQUE INDEX "note_text" ON "note" ("text")"#)
            }
        }

        let database = AppDatabase.openOrRecover(at: url, schemas: [schema, unique])

        expectNoDifference(try database.read { db in try Int.fetchOne(db, sql: #"SELECT count(*) FROM "note""#) }, 0)
        #expect(database is DatabasePool)
    }

    @Test
    func `a file that can't be opened right now is kept and the launch runs in memory`() throws {
        let url = try temporaryDatabaseURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let other = try DatabaseQueue(path: url.path(percentEncoded: false))
        var migrator = DatabaseMigrator()
        schema.registerMigrations(&migrator)
        try migrator.migrate(other)
        try other.write { db in try db.execute(sql: #"INSERT INTO "note" ("text") VALUES ('unsent')"#) }

        // Another connection's exclusive lock makes SQLite answer busy, a failure of the moment like a full disk.
        let database = try other.inDatabase { db in
            try db.execute(sql: "BEGIN EXCLUSIVE")
            defer { try? db.execute(sql: "ROLLBACK") }
            return AppDatabase.openOrRecover(at: url, schemas: [schema])
        }

        #expect(!(database is DatabasePool))
        expectNoDifference(try other.read { db in try String.fetchAll(db, sql: #"SELECT "text" FROM "note""#) }, ["unsent"])
    }

    private func temporaryDatabaseURL() throws -> URL {
        let directory = URL.temporaryDirectory.appending(
            path: "AppDatabaseTests-\(UUID().uuidString)",
            directoryHint: .isDirectory,
        )
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "openskatemap.sqlite")
    }
}
