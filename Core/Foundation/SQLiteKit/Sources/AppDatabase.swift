import Dependencies
public import Foundation
import os
public import SQLiteData

public enum AppDatabase {

    // MARK: Static Properties

    public static let defaultURL = URL.applicationSupportDirectory
        .appending(path: "Database", directoryHint: .isDirectory)
        .appending(path: "openskatemap.sqlite")

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "database")

    private static var configuration: Configuration {
        var configuration = Configuration()
        configuration.foreignKeysEnabled = true
        return configuration
    }

    // MARK: Static Functions

    /// Recreates the file only when it's corrupt or its migrations fail; when the device can't open it (disk full, I/O),
    /// this launch runs in memory and the file, with the outbox in it, is kept for the next one.
    public static func openOrRecover(at url: URL, schemas: [DatabaseSchema]) -> any DatabaseWriter {
        do {
            let database = try connect(at: url)
            do {
                try migrator(for: schemas).migrate(database)
                return database
            } catch where !isDeviceFailure(error) {
                logger.fault(
                    "Migrating the database failed, recreating it (unsent contributions are lost): \(describe(error), privacy: .public)"
                )
            }
        } catch where isCorrupt(error) {
            logger.fault(
                "The database file is corrupt, recreating it (unsent contributions are lost): \(describe(error), privacy: .public)"
            )
        } catch {
            logger.fault("Opening the database failed, using memory until the next launch: \(describe(error), privacy: .public)")
            return lastResort(schemas: schemas)
        }
        do {
            try deleteFiles(at: url)
            return try open(at: url, schemas: schemas)
        } catch {
            logger.fault("Recreating the database failed, using memory: \(describe(error), privacy: .public)")
            return lastResort(schemas: schemas)
        }
    }

    public static func open(at url: URL, schemas: [DatabaseSchema]) throws -> any DatabaseWriter {
        let database = try connect(at: url)
        try migrator(for: schemas).migrate(database)
        return database
    }

    public static func inMemory(schemas: [DatabaseSchema]) throws -> any DatabaseWriter {
        let database = try DatabaseQueue(configuration: configuration)
        try migrator(for: schemas).migrate(database)
        return database
    }

    public static func bridgeToSQLiteData(_ database: any DatabaseWriter) {
        prepareDependencies { $0.defaultDatabase = database }
    }

    private static func connect(at url: URL) throws -> DatabasePool {
        var directory = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? directory.setResourceValues(values)
        return try DatabasePool(path: url.path(percentEncoded: false), configuration: configuration)
    }

    private static func lastResort(schemas: [DatabaseSchema]) -> any DatabaseWriter {
        // In memory this only fails on a migration bug or an allocation failure; nothing is left to fall back to.
        try! inMemory(schemas: schemas)
    }

    private static func isCorrupt(_ error: any Error) -> Bool {
        guard let code = (error as? DatabaseError)?.resultCode else {
            return false
        }
        return [DatabaseError.SQLITE_CORRUPT, DatabaseError.SQLITE_NOTADB].contains(code)
    }

    private static func isDeviceFailure(_ error: any Error) -> Bool {
        guard let code = (error as? DatabaseError)?.resultCode else {
            return false
        }
        return [
            DatabaseError.SQLITE_FULL,
            DatabaseError.SQLITE_IOERR,
            DatabaseError.SQLITE_NOMEM,
            DatabaseError.SQLITE_CANTOPEN,
            DatabaseError.SQLITE_PERM,
            DatabaseError.SQLITE_READONLY,
            DatabaseError.SQLITE_BUSY,
            DatabaseError.SQLITE_LOCKED,
        ].contains(code)
    }

    /// The SQLite result code where there is one; messages can quote stored values.
    private static func describe(_ error: any Error) -> String {
        (error as? DatabaseError).map { "\($0.extendedResultCode)" } ?? String(describing: type(of: error))
    }

    private static func migrator(for schemas: [DatabaseSchema]) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
        #endif
        for schema in schemas {
            schema.registerMigrations(&migrator)
        }
        return migrator
    }

    private static func deleteFiles(at url: URL) throws {
        for suffix in ["", "-wal", "-shm"] {
            let file = URL(filePath: url.path(percentEncoded: false) + suffix)
            if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
                try FileManager.default.removeItem(at: file)
            }
        }
    }
}
