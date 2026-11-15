import SQLiteData
public import SQLiteKit

extension DatabaseSchema {
    public static let people = DatabaseSchema { migrator in
        migrator.registerMigration("Create the people cache") { db in
            try #sql(
                """
                CREATE TABLE "people_profile" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "accountID" TEXT NOT NULL,
                  "name" TEXT NOT NULL,
                  "username" TEXT,
                  "bio" TEXT NOT NULL DEFAULT '',
                  "avatarKey" TEXT,
                  "avatarThumbhash" TEXT,
                  "handles" TEXT NOT NULL DEFAULT '{}',
                  "role" TEXT NOT NULL,
                  "editorOf" TEXT NOT NULL DEFAULT '[]',
                  "submitted" INTEGER NOT NULL,
                  "approved" INTEGER NOT NULL,
                  "cities" INTEGER NOT NULL,
                  "joinedAt" TEXT NOT NULL,
                  "blockedByMe" INTEGER NOT NULL DEFAULT 0,
                  "fetchedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "people_blocked_user" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "accountID" TEXT NOT NULL,
                  "name" TEXT NOT NULL,
                  "username" TEXT,
                  "blockedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "people_blocked_user_account" ON "people_blocked_user"("accountID", "blockedAt")"#)
                .execute(db)
            try #sql(
                """
                CREATE TABLE "people_sync_state" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "blockedLoadedAt" TEXT
                ) STRICT
                """
            )
            .execute(db)
        }
    }
}
