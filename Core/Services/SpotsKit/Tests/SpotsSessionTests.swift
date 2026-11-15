import Clocks
import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotsKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SpotsSessionTests {
    private let server = FakeDetailServer()
    private let time = TestTime()
    private let database: any DatabaseWriter
    private let session: SpotsSession
    private let fetcher: DetailFetcher

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert {
                SpotIndex(
                    id: "s1",
                    title: "Spot",
                    kind: .street,
                    condition: .skateable,
                    cityID: nil,
                    latitude: 1,
                    longitude: 1,
                    version: 1,
                )
            }
            .execute(db)
        }
        let api = server.api
        let engine = SpotSyncEngine(api: api, database: database, now: { [time] in time.now })
        fetcher = DetailFetcher(
            api: api,
            engine: engine,
            database: database,
            clock: ImmediateClock(),
            now: { [time] in time.now },
        )
        session = SpotsSession(engine: engine, fetcher: fetcher, api: api)
    }

    @Test
    func `a sync that brings a newer version of the open spot fetches its detail again`() async throws {
        await fetcher.select("s1")
        await server.change("s1", to: 2)

        await session.syncNow()

        #expect(await server.requests == [["s1"], ["s1"]])
        let version = try await database.read { db in try SpotDetail.find("s1").fetchOne(db)?.version }
        expectNoDifference(version, 2)
    }

    @Test
    func `the open spot's details show as loading, then failed, and Try Again fetches them`() async {
        await server.failNext()
        session.select("s1")
        expectNoDifference(session.selectedDetails, .loading)
        await settle()
        expectNoDifference(session.selectedDetails, .failed)

        session.retrySelectedDetails()
        await settle()

        expectNoDifference(session.selectedDetails, .idle)
        #expect(await server.requests == [["s1"], ["s1"]])
    }

    @Test
    func `a spot taken down leaves the index once the server agrees, and stays when it refuses`() async throws {
        await #expect(throws: SpotsAPIError.rejected) {
            try await session(takingDown: { _, _ in throw SpotsAPIError.rejected }).takeDown("s1", reason: .duplicate)
        }
        let kept = try await indexedIDs()
        expectNoDifference(kept, ["s1"])

        try await session(takingDown: { _, _ in }).takeDown("s1", reason: .duplicate)

        let left = try await indexedIDs()
        expectNoDifference(left, [])
    }

    private func session(takingDown takeDown: @escaping @Sendable (String, SpotRemovalReason) async throws -> Void)
        -> SpotsSession {
        var api = server.api
        api.takeDown = takeDown
        let engine = SpotSyncEngine(api: api, database: database, now: { [time] in time.now })
        return SpotsSession(engine: engine, fetcher: fetcher, api: api)
    }

    private func indexedIDs() async throws -> [String] {
        try await database.read { db in try SpotIndex.select(\.id).fetchAll(db) }
    }

    private func settle() async {
        for await details in Observations({ [session] in session.selectedDetails }) where details != .loading {
            return
        }
    }
}
