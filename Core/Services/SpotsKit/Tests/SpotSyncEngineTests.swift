import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotsKit

@Suite(.timeLimit(.minutes(1)))
struct SyncEngineTests {
    private static let photoAdded = Date(timeIntervalSince1970: 1_764_063_660.789)

    private let server = FakeSpotServer()
    private let database: any DatabaseWriter
    private let engine: SpotSyncEngine

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        engine = SpotSyncEngine(api: server.api, database: database, pageSize: 2, now: { Date(timeIntervalSince1970: 1_000) })
    }

    @Test
    func `a pass pages through every change and stores the cursor last`() async throws {
        for id in ["a", "b", "c", "d", "e"] {
            await server.publish(id)
        }

        let outcome = await engine.sync()

        expectNoDifference(outcome, SpotSyncEngine.Outcome.synced)
        expectNoDifference(try localIDs(), ["a", "b", "c", "d", "e"])
        expectNoDifference(try state().cursor, 5)
        #expect(await server.requestedCursors == [0, 2, 4])
    }

    @Test
    func `removed spots leave the index and take their details with them`() async throws {
        await server.publish("a")
        await server.publish("b")
        _ = await engine.sync()
        try await engine.applyDetails(
            SpotDetailsPage(spots: [detail("a", version: 1)], missing: []),
            requestedAt: engine.detailStamp(),
        )

        await server.remove("a")
        _ = await engine.sync()

        expectNoDifference(try localIDs(), ["b"])
        let details = try await database.read { db in try SpotDetail.fetchCount(db) }
        let photos = try await database.read { db in try SpotPhoto.fetchCount(db) }
        expectNoDifference(details, 0)
        expectNoDifference(photos, 0)
    }

    @Test
    func `a photo's clip is stored with the details`() async throws {
        await server.publish("a")
        _ = await engine.sync()
        let clip = SpotClip(key: "clips/a.mp4", width: 1280, height: 720, durationMs: 9500)
        var detail = detail("a", version: 1)
        detail.photos[0].clip = clip

        try await engine.applyDetails(SpotDetailsPage(spots: [detail], missing: []), requestedAt: engine.detailStamp())

        let clips = try await database.read { db in try SpotPhoto.fetchAll(db).map(\.clip) }
        expectNoDifference(clips, [clip])
    }

    @Test
    func `a photo's date is stored to the second`() async throws {
        await server.publish("a")
        _ = await engine.sync()

        try await engine.applyDetails(
            SpotDetailsPage(spots: [detail("a", version: 1)], missing: []),
            requestedAt: engine.detailStamp(),
        )

        let dates = try await database.read { db in try SpotPhoto.fetchAll(db).map(\.createdAt) }
        expectNoDifference(dates, [Date(timeIntervalSince1970: 1_764_063_660)])
    }

    @Test
    func `a row never moves back to an older version`() throws {
        try database.write { db in
            try SpotIndex.insert { SpotIndex(
                id: "a",
                title: "New",
                kind: .park,
                condition: .skateable,
                cityID: nil,
                latitude: 1,
                longitude: 1,
                version: 5,
            ) }.execute(db)
            try SyncState.find(SyncState.rowID).update { $0.cursor = 2 }.execute(db)
        }
        let stale = SyncPage(
            items: [remote("a", title: "Old", version: 3)],
            tombstones: [],
            nextCursor: 3,
            hasMore: false,
            resetRequired: false,
        )

        let applied = try database.write { db in try SpotSyncEngine.apply(stale, from: 2, reindexing: false, at: .now, db) }

        #expect(applied)
        let title = try database.read { db in try SpotIndex.find("a").fetchOne(db)?.title }
        expectNoDifference(title, "New")
    }

    @Test
    func `a page requested from a cursor that has since moved is dropped`() throws {
        try database.write { db in try SyncState.find(SyncState.rowID).update { $0.cursor = 7 }.execute(db) }
        let page = SyncPage(
            items: [remote("a", title: "A", version: 3)],
            tombstones: [],
            nextCursor: 3,
            hasMore: false,
            resetRequired: false,
        )

        let applied = try database.write { db in try SpotSyncEngine.apply(page, from: 0, reindexing: false, at: .now, db) }

        #expect(!applied)
        expectNoDifference(try localIDs(), [])
        expectNoDifference(try state().cursor, 7)
    }

    @Test
    func `a failure between pages keeps the pages before it and resumes after them`() async throws {
        for id in ["a", "b", "c", "d"] {
            await server.publish(id)
        }
        await server.failOnce(at: 2)

        #expect(await engine.sync() == SpotSyncEngine.Outcome.failed(.offline))
        expectNoDifference(try localIDs(), ["a", "b"])
        expectNoDifference(try state().cursor, 2)

        #expect(await engine.sync() == SpotSyncEngine.Outcome.synced)
        expectNoDifference(try localIDs(), ["a", "b", "c", "d"])
        #expect(await server.requestedCursors == [0, 2, 2])
    }

    @Test
    func `a server reset re-indexes without wiping, then drops what it no longer has`() async throws {
        for id in ["a", "b", "c", "d", "e"] {
            await server.publish(id)
        }
        _ = await engine.sync()
        await server.replaceAll(with: ["a", "b", "d", "f"])
        await server.failOnce(at: 2)

        #expect(await engine.sync() == SpotSyncEngine.Outcome.failed(.offline))
        expectNoDifference(try localIDs(), ["a", "b", "c", "d", "e"])
        let midway = try state()
        #expect(midway.resyncNeeded)
        expectNoDifference(midway.reindexCursor, 2)

        #expect(await engine.sync() == SpotSyncEngine.Outcome.synced)
        expectNoDifference(try localIDs(), ["a", "b", "d", "f"])
        let done = try state()
        #expect(!done.resyncNeeded)
        expectNoDifference(done.cursor, 4)
        expectNoDifference(done.reindexEpoch, 1)
    }

    @Test
    func `private spots stay through a re-index and go only when the collections leave them out`() async throws {
        for id in ["a", "c", "d"] {
            await server.publish(id)
        }
        _ = await engine.sync()
        let mine = SpotIndex(
            id: "p",
            title: "Garage",
            kind: .diy,
            condition: .skateable,
            cityID: nil,
            latitude: 1,
            longitude: 1,
            version: 9,
        )
        try await engine.replacePrivateSpots(with: [mine], requestedIn: engine.generation)

        await server.replaceAll(with: ["b"])
        #expect(await engine.sync() == SpotSyncEngine.Outcome.synced)
        expectNoDifference(try localIDs(), ["b", "p"])

        try await engine.replacePrivateSpots(with: [], requestedIn: engine.generation)
        expectNoDifference(try localIDs(), ["b"])
    }

    @Test
    func `a pass stores obstacles and scores, and drops scores the server no longer sends`() async throws {
        await server.publish("a", obstacles: ["ledges", "stairs"])
        await server.publish("b")
        await server.rate([SpotScore(id: "a", up: 3, down: 0, score: 0.7), SpotScore(id: "b", up: 0, down: 1, score: 0.4)])
        _ = await engine.sync()
        await server.rate([SpotScore(id: "b", up: 0, down: 1, score: 0.45)])

        _ = await engine.sync()

        let obstacles = try await database.read { db in try SpotIndex.find("a").fetchOne(db)?.obstacles }
        let scores = try await database.read { db in try SpotScore.order(by: \.id).fetchAll(db) }
        expectNoDifference(obstacles, ["ledges", "stairs"])
        expectNoDifference(scores, [SpotScore(id: "b", up: 0, down: 1, score: 0.45)])
    }

    @Test
    func `reset empties local spots and drops detail answers from before it`() async throws {
        await server.publish("a")
        _ = await engine.sync()
        let before = await engine.detailStamp()

        await engine.reset()
        await server.publish("b")
        try await engine.applyDetails(SpotDetailsPage(spots: [detail("a", version: 1)], missing: []), requestedAt: before)

        expectNoDifference(try localIDs(), [])
        expectNoDifference(try state(), SyncState())
        let details = try await database.read { db in try SpotDetail.fetchCount(db) }
        expectNoDifference(details, 0)
    }

    @Test
    func `a detail fetched again unchanged rewrites only its own row, not its photos`() async throws {
        await server.publish("a")
        _ = await engine.sync()
        let page = SpotDetailsPage(spots: [detail("a", version: 1)], missing: [])
        try await engine.applyDetails(page, requestedAt: engine.detailStamp())
        let before = try await database.read { db in db.totalChangesCount }

        try await engine.applyDetails(page, requestedAt: engine.detailStamp())

        let written = try await database.read { db in db.totalChangesCount } - before
        expectNoDifference(written, 1)
    }

    // MARK: Helpers

    private func localIDs() throws -> [String] {
        try database.read { db in try SpotIndex.order(by: \.id).fetchAll(db).map(\.id) }
    }

    private func state() throws -> SyncState {
        try database.read { db in try SyncState.find(SyncState.rowID).fetchOne(db) } ?? SyncState(id: -1)
    }

    private func remote(_ id: String, title: String, version: Int) -> SpotIndex {
        SpotIndex(
            id: id,
            title: title,
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: 1,
            longitude: 1,
            version: version,
        )
    }

    private func detail(_ id: String, version: Int) -> RemoteSpotDetail {
        RemoteSpotDetail(
            id: id,
            about: "About \(id)",
            obstacles: ["ledges"],
            addedByID: nil,
            addedByName: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            version: version,
            photos: [.init(
                id: "\(id)-p0",
                key: "photos/\(id).jpg",
                width: 4,
                height: 3,
                thumbhash: "AAAA",
                credit: nil,
                position: 0,
                createdAt: Self.photoAdded,
            )],
        )
    }
}
