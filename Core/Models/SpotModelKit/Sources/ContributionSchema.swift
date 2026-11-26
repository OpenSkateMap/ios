import SQLiteData
public import SQLiteKit

extension DatabaseSchema {
    public static let contributions = DatabaseSchema { migrator in
        migrator.registerMigration("Create the submission outbox and history") { db in
            try #sql(
                """
                CREATE TABLE "submission_draft" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "title" TEXT NOT NULL,
                  "about" TEXT NOT NULL DEFAULT '',
                  "kind" TEXT NOT NULL,
                  "obstacles" TEXT NOT NULL DEFAULT '[]',
                  "condition" TEXT NOT NULL,
                  "latitude" REAL NOT NULL,
                  "longitude" REAL NOT NULL,
                  "note" TEXT NOT NULL DEFAULT '',
                  "status" TEXT NOT NULL,
                  "problem" TEXT,
                  "attempts" INTEGER NOT NULL DEFAULT 0,
                  "nextAttemptAt" TEXT,
                  "createdAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                #"CREATE INDEX "submission_draft_pending" ON "submission_draft"("nextAttemptAt", "createdAt") WHERE "status" = 'pending'"#
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "draft_photo" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "draftID" TEXT NOT NULL REFERENCES "submission_draft"("id") ON DELETE CASCADE,
                  "position" INTEGER NOT NULL,
                  "fileName" TEXT NOT NULL,
                  "width" INTEGER NOT NULL,
                  "height" INTEGER NOT NULL,
                  "thumbhash" TEXT NOT NULL,
                  "credit" TEXT,
                  "sourceURL" TEXT,
                  "isUploaded" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "draft_photo_draft" ON "draft_photo"("draftID", "position")"#).execute(db)
            try #sql(
                """
                CREATE TABLE "my_submission" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "title" TEXT NOT NULL,
                  "kind" TEXT NOT NULL,
                  "cityID" TEXT,
                  "latitude" REAL NOT NULL,
                  "longitude" REAL NOT NULL,
                  "status" TEXT NOT NULL,
                  "rejectReason" TEXT,
                  "spotID" TEXT,
                  "coverThumbhash" TEXT,
                  "createdAt" TEXT NOT NULL,
                  "updatedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
        }
        migrator.registerMigration("Create the video outbox") { db in
            try #sql(
                """
                CREATE TABLE "video_draft" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "spotID" TEXT NOT NULL,
                  "url" TEXT NOT NULL,
                  "caption" TEXT NOT NULL DEFAULT '',
                  "status" TEXT NOT NULL,
                  "problem" TEXT,
                  "attempts" INTEGER NOT NULL DEFAULT 0,
                  "nextAttemptAt" TEXT,
                  "createdAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                #"CREATE INDEX "video_draft_pending" ON "video_draft"("nextAttemptAt", "createdAt") WHERE "status" = 'pending'"#
            )
            .execute(db)
        }
        migrator.registerMigration("Add private spot destinations") { db in
            try #sql(#"ALTER TABLE "submission_draft" ADD COLUMN "collectionID" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "my_submission" ADD COLUMN "collectionID" TEXT"#).execute(db)
        }
        migrator.registerMigration("Suggested edits in the outbox and history") { db in
            try #sql(#"ALTER TABLE "submission_draft" ADD COLUMN "editsSpotID" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "submission_draft" ADD COLUMN "changedFields" TEXT NOT NULL DEFAULT '[]'"#).execute(db)
            try #sql(#"ALTER TABLE "my_submission" ADD COLUMN "changedFields" TEXT NOT NULL DEFAULT '[]'"#).execute(db)
        }
        migrator.registerMigration("Taken-down spots in the history") { db in
            try #sql(#"ALTER TABLE "my_submission" ADD COLUMN "removalReason" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "my_submission" ADD COLUMN "removedAt" TEXT"#).execute(db)
        }
        migrator.registerMigration("Suggested edits carry the spot's photo list") { db in
            try #sql(#"ALTER TABLE "submission_draft" ADD COLUMN "photoOrder" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "submission_draft" ADD COLUMN "basePhotoIDs" TEXT"#).execute(db)
        }
        migrator.registerMigration("Draft photos carry their clips") { db in
            try #sql(#"ALTER TABLE "draft_photo" ADD COLUMN "clip" TEXT"#).execute(db)
        }
        migrator.registerMigration("Outbox problems are kinds, not text") { db in
            // Earlier rows hold free text (some of it the server's), which `OutboxProblem` can't read.
            try #sql(#"UPDATE "submission_draft" SET "problem" = NULL"#).execute(db)
            try #sql(#"UPDATE "video_draft" SET "problem" = NULL"#).execute(db)
        }
        migrator.registerMigration("The submission history keeps its cover's key") { db in
            try #sql(#"ALTER TABLE "my_submission" ADD COLUMN "coverKey" TEXT"#).execute(db)
        }
    }
}
