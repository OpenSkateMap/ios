import SQLiteData
public import SQLiteKit

extension DatabaseSchema {
    public static let review = DatabaseSchema { migrator in
        migrator.registerMigration("Cache the review queue") { db in
            try #sql(
                """
                CREATE TABLE "review_queue_cache" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "payload" BLOB NOT NULL,
                  "savedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
        }
    }
}
