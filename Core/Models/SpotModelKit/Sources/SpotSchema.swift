import Foundation
import SQLiteData
public import SQLiteKit

extension DatabaseSchema {
    public static let spots = DatabaseSchema { migrator in
        migrator.registerMigration("Create the spot index, details, photos, cities and sync state") { db in
            try #sql(
                """
                CREATE TABLE "spot_index" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "title" TEXT NOT NULL,
                  "kind" TEXT NOT NULL,
                  "condition" TEXT NOT NULL,
                  "cityID" TEXT,
                  "latitude" REAL NOT NULL,
                  "longitude" REAL NOT NULL,
                  "version" INTEGER NOT NULL,
                  "coverKey" TEXT,
                  "coverWidth" INTEGER,
                  "coverHeight" INTEGER,
                  "coverThumbhash" TEXT,
                  "reindexEpoch" INTEGER NOT NULL DEFAULT 0
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "spot_index_location" ON "spot_index"("latitude", "longitude")"#).execute(db)
            try #sql(
                """
                CREATE TABLE "spot_detail" (
                  "id" TEXT PRIMARY KEY NOT NULL REFERENCES "spot_index"("id") ON DELETE CASCADE,
                  "about" TEXT NOT NULL,
                  "obstacles" TEXT NOT NULL DEFAULT '[]',
                  "addedByID" TEXT,
                  "addedByName" TEXT,
                  "createdAt" TEXT NOT NULL,
                  "version" INTEGER NOT NULL,
                  "fetchedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "spot_photo" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "spotID" TEXT NOT NULL REFERENCES "spot_index"("id") ON DELETE CASCADE,
                  "key" TEXT NOT NULL,
                  "width" INTEGER NOT NULL,
                  "height" INTEGER NOT NULL,
                  "thumbhash" TEXT NOT NULL,
                  "credit" TEXT,
                  "position" INTEGER NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "spot_photo_spot" ON "spot_photo"("spotID", "position")"#).execute(db)
            try #sql(
                """
                CREATE TABLE "city" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "slug" TEXT NOT NULL,
                  "name" TEXT NOT NULL,
                  "countryCode" TEXT NOT NULL,
                  "minLatitude" REAL NOT NULL,
                  "minLongitude" REAL NOT NULL,
                  "maxLatitude" REAL NOT NULL,
                  "maxLongitude" REAL NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "sync_state" (
                  "id" INTEGER PRIMARY KEY NOT NULL CHECK ("id" = 1),
                  "cursor" INTEGER NOT NULL DEFAULT 0,
                  "reindexEpoch" INTEGER NOT NULL DEFAULT 0,
                  "resyncNeeded" INTEGER NOT NULL DEFAULT 0,
                  "reindexCursor" INTEGER NOT NULL DEFAULT 0,
                  "lastSuccessAt" TEXT
                ) STRICT
                """
            )
            .execute(db)
            try SyncState.insert { SyncState() }.execute(db)
        }
        migrator.registerMigration("Create spot videos") { db in
            try #sql(
                """
                CREATE TABLE "spot_video" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "spotID" TEXT NOT NULL REFERENCES "spot_index"("id") ON DELETE CASCADE,
                  "provider" TEXT NOT NULL,
                  "url" TEXT NOT NULL,
                  "thumbnailURL" TEXT,
                  "caption" TEXT NOT NULL DEFAULT '',
                  "addedByID" TEXT,
                  "addedByName" TEXT,
                  "position" INTEGER NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "spot_video_spot" ON "spot_video"("spotID", "position")"#).execute(db)
        }
        migrator.registerMigration("Add spot votes") { db in
            try #sql(#"ALTER TABLE "spot_detail" ADD COLUMN "upvotes" INTEGER NOT NULL DEFAULT 0"#).execute(db)
            try #sql(#"ALTER TABLE "spot_detail" ADD COLUMN "downvotes" INTEGER NOT NULL DEFAULT 0"#).execute(db)
            try #sql(
                #"ALTER TABLE "spot_detail" ADD COLUMN "myVote" INTEGER NOT NULL DEFAULT 0 CHECK ("myVote" IN (-1, 0, 1))"#
            )
            .execute(db)
            try SpotDetail.update { $0.fetchedAt = #bind(Date.distantPast) }.execute(db)
        }
        migrator.registerMigration("Add collections and private spots") { db in
            try #sql(
                #"ALTER TABLE "spot_index" ADD COLUMN "isPrivate" INTEGER NOT NULL DEFAULT 0 CHECK ("isPrivate" IN (0, 1))"#
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "collection" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL,
                  "about" TEXT NOT NULL DEFAULT '',
                  "visibility" TEXT NOT NULL,
                  "role" TEXT NOT NULL,
                  "ownerID" TEXT NOT NULL,
                  "ownerName" TEXT NOT NULL,
                  "ownerUsername" TEXT,
                  "memberCount" INTEGER NOT NULL DEFAULT 0,
                  "coverKey" TEXT,
                  "coverThumbhash" TEXT,
                  "position" INTEGER NOT NULL,
                  "createdAt" TEXT NOT NULL,
                  "updatedAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TABLE "collection_spot" (
                  "collectionID" TEXT NOT NULL REFERENCES "collection"("id") ON DELETE CASCADE,
                  "spotID" TEXT NOT NULL,
                  "position" INTEGER NOT NULL,
                  PRIMARY KEY ("collectionID", "spotID")
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE INDEX "collection_spot_spot" ON "collection_spot"("spotID")"#).execute(db)
        }
        migrator.registerMigration("Index spots by city") { db in
            try #sql(#"CREATE INDEX "spot_index_city" ON "spot_index"("cityID")"#).execute(db)
        }
        migrator.registerMigration("Add obstacles to the index, and spot scores") { db in
            try #sql(#"ALTER TABLE "spot_index" ADD COLUMN "obstacles" TEXT NOT NULL DEFAULT '[]'"#).execute(db)
            try #sql(
                """
                CREATE TABLE "spot_score" (
                  "id" TEXT PRIMARY KEY NOT NULL,
                  "up" INTEGER NOT NULL,
                  "down" INTEGER NOT NULL,
                  "score" REAL NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(
                #"""
                UPDATE "sync_state" SET "resyncNeeded" = 1, "reindexEpoch" = "reindexEpoch" + 1, "reindexCursor" = 0
                WHERE EXISTS (SELECT 1 FROM "spot_index")
                """#
            )
            .execute(db)
        }
        migrator.registerMigration("Add curators' ratings to details") { db in
            try #sql(#"ALTER TABLE "spot_detail" ADD COLUMN "editorialRating" INTEGER"#).execute(db)
            try SpotDetail.update { $0.fetchedAt = #bind(Date.distantPast) }.execute(db)
        }
        migrator.registerMigration("Add collection kinds, looks, invitations and requests") { db in
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "kind" TEXT NOT NULL DEFAULT 'custom'"#).execute(db)
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "color" TEXT NOT NULL DEFAULT 'blue'"#).execute(db)
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "pattern" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "photoID" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "photoKey" TEXT"#).execute(db)
            try #sql(#"ALTER TABLE "collection" ADD COLUMN "photoThumbhash" TEXT"#).execute(db)
            try #sql(
                """
                CREATE TABLE "collection_invitation" (
                  "collectionID" TEXT PRIMARY KEY NOT NULL,
                  "name" TEXT NOT NULL,
                  "ownerID" TEXT NOT NULL,
                  "ownerName" TEXT NOT NULL,
                  "ownerUsername" TEXT,
                  "role" TEXT NOT NULL,
                  "inviterName" TEXT,
                  "position" INTEGER NOT NULL,
                  "createdAt" TEXT NOT NULL
                ) STRICT
                """
            )
            .execute(db)
            try #sql(#"CREATE TABLE "collection_request" ("collectionID" TEXT PRIMARY KEY NOT NULL) STRICT"#).execute(db)
        }
        migrator.registerMigration("Drop collection patterns") { db in
            try #sql(#"ALTER TABLE "collection" DROP COLUMN "pattern""#).execute(db)
        }
        migrator.registerMigration("Drop curators' ratings") { db in
            try #sql(#"ALTER TABLE "spot_detail" DROP COLUMN "editorialRating""#).execute(db)
        }
        migrator.registerMigration("Add clips to spot photos") { db in
            try #sql(#"ALTER TABLE "spot_photo" ADD COLUMN "clip" TEXT"#).execute(db)
            try SpotDetail.update { $0.fetchedAt = #bind(Date.distantPast) }.execute(db)
        }
        migrator.registerMigration("Add dates to spot photos") { db in
            try #sql(#"ALTER TABLE "spot_photo" ADD COLUMN "createdAt" TEXT"#).execute(db)
            try SpotDetail.update { $0.fetchedAt = #bind(Date.distantPast) }.execute(db)
        }
        migrator.registerMigration("Add spot search") { db in
            try #sql(
                """
                CREATE VIRTUAL TABLE "spot_search" USING fts5(
                  "spotID" UNINDEXED,
                  "title",
                  "latin",
                  tokenize = 'unicode61 remove_diacritics 2',
                  prefix = '2 3'
                )
                """
            )
            .execute(db)
            try #sql(
                """
                CREATE TRIGGER "spot_search_delete" AFTER DELETE ON "spot_index" BEGIN
                  DELETE FROM "spot_search" WHERE "spotID" = old."id";
                END
                """
            )
            .execute(db)
            let spots = try SpotIndex.select { ($0.id, $0.title) }.fetchAll(db)
            if !spots.isEmpty {
                try SpotSearchText.insert { spots.map { SpotSearchText(spotID: $0.0, title: $0.1) } }.execute(db)
            }
        }
        migrator.registerMigration("Add city names") { db in
            try #sql(#"ALTER TABLE "city" ADD COLUMN "names" TEXT NOT NULL DEFAULT '{}'"#).execute(db)
        }
    }
}
