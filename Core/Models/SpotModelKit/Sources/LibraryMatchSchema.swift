import SQLiteData
public import SQLiteKit

extension DatabaseSchema {
    /// Found on this device from its photo library, never synced; cleared when the account ends.
    public static let libraryMatches = DatabaseSchema { migrator in
        migrator.registerMigration("Create library matches") { db in
            try #sql(
                """
                CREATE TABLE "library_match" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "assetID" TEXT NOT NULL,
                  "spotID" TEXT NOT NULL,
                  "day" TEXT NOT NULL,
                  "takenAt" TEXT NOT NULL,
                  "distanceMeters" REAL NOT NULL,
                  "score" REAL NOT NULL,
                  "state" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "library_match_asset" ON "library_match"("assetID")"#).execute(db)
            try #sql(
                """
                CREATE TABLE "library_scan" (
                  "id" INTEGER PRIMARY KEY NOT NULL,
                  "changeToken" BLOB,
                  "isLimited" INTEGER NOT NULL,
                  "spotsDigest" TEXT NOT NULL,
                  "scannedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
        }
    }
}
