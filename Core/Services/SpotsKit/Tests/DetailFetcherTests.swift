import Clocks
import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Synchronization
import Testing
@testable import SpotsKit

// MARK: - DetailFetcherTests

@Suite(.timeLimit(.minutes(1)))
struct DetailFetcherTests {
    private let server = FakeDetailServer()
    private let time = TestTime()
    private let database: any DatabaseWriter
    private let engine: SpotSyncEngine
    private let fetcher: DetailFetcher

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert {
                (0..<150).map { SpotIndex(
                    id: "s\($0)",
                    title: "Spot \($0)",
                    kind: .street,
                    condition: .skateable,
                    cityID: nil,
                    latitude: 1,
                    longitude: 1,
                    version: 1,
                ) }
            }
            .execute(db)
        }
        let api = server.api
        engine = SpotSyncEngine(api: api, database: database, now: { [time] in time.now })
        fetcher = DetailFetcher(
            api: api,
            engine: engine,
            database: database,
            clock: ImmediateClock(),
            now: { [time] in time.now },
        )
    }

    @Test
    func `visible spots are fetched in batches of at most 100`() async throws {
        let ids = (0..<150).map { "s\($0)" }

        await fetcher.show(ids)
        await fetcher.flush()

        #expect(await server.requests.map(\.count).sorted() == [50, 100])
        let details = try await database.read { db in try SpotDetail.fetchCount(db) }
        expectNoDifference(details, 150)
    }

    @Test
    func `the selected spot is asked for once, even when it is also visible`() async {
        await fetcher.show(["s1", "s2"])
        await fetcher.select("s2")
        await fetcher.flush()

        #expect(await server.requests.map(Set.init) == [["s1", "s2"]])
    }

    @Test
    func `fresh details aren't fetched again until they are five minutes old`() async {
        await fetcher.select("s1")
        await fetcher.flush()
        time.advance(by: 4 * 60)
        await fetcher.flush()
        #expect(await server.requests.count == 1)

        time.advance(by: 61)
        await fetcher.flush()

        #expect(await server.requests == [["s1"], ["s1"]])
    }

    @Test
    func `expired details are fetched again for the open spot right away`() async throws {
        await fetcher.select("s1")

        try await engine.expireDetails()
        await fetcher.refresh()

        #expect(await server.requests == [["s1"], ["s1"]])
    }

    @Test
    func `a newer index row makes a fresh detail stale`() async throws {
        await fetcher.select("s1")
        try await database.write { db in try SpotIndex.find("s1").update { $0.version = 2 }.execute(db) }
        await server.setVersion(2)

        await fetcher.flush()

        #expect(await server.requests == [["s1"], ["s1"]])
        let version = try await database.read { db in try SpotDetail.find("s1").fetchOne(db)?.version }
        expectNoDifference(version, 2)
    }

    @Test
    func `failed and missing ids rest for 20 seconds instead of looping`() async {
        await server.setMissing(["s2"])
        await server.failNext()
        await fetcher.select("s1")
        await fetcher.show(["s2"])
        await fetcher.flush()
        await fetcher.flush()

        #expect(await server.requests == [["s1"], ["s2"]])

        time.advance(by: 21)
        await fetcher.flush()

        #expect(await server.requests.last == ["s1", "s2"])
    }

    @Test
    func `the open spot's failed fetch is reported, and Try Again asks before the pause ends`() async {
        await server.failNext()
        #expect(await fetcher.select("s1"))
        #expect(await fetcher.select("s1"))
        #expect(await server.requests == [["s1"]])

        #expect(await fetcher.select("s1", retrying: true) == false)
        #expect(await server.requests == [["s1"], ["s1"]])
    }
}

// MARK: - FakeDetailServer

actor FakeDetailServer {

    // MARK: Computed Properties

    nonisolated var api: SpotsAPIManager {
        SpotsAPIManager(
            syncPage: { cursor, _ in await self.syncPage(cursor: cursor) },
            details: { try await self.details($0) },
            cities: { [] },
            vote: { _, _ in throw SpotsAPIError.rejected },
        )
    }

    // MARK: Properties

    private(set) var requests = [[String]]()

    private var version = 1
    private var missing = Set<String>()
    private var failsNext = false
    private var changedRows = [SpotIndex]()

    // MARK: Functions

    func setVersion(_ version: Int) {
        self.version = version
    }

    func setMissing(_ ids: Set<String>) {
        missing = ids
    }

    func change(_ id: String, to version: Int) {
        self.version = version
        changedRows.append(SpotIndex(
            id: id,
            title: "Spot",
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: 1,
            longitude: 1,
            version: version,
        ))
    }

    func syncPage(cursor: Int) -> SyncPage {
        let items = changedRows
        changedRows = []
        let next = items.map(\.version).max() ?? cursor
        return SyncPage(items: items, tombstones: [], nextCursor: max(cursor, next), hasMore: false, resetRequired: false)
    }

    func failNext() {
        failsNext = true
    }

    func details(_ ids: [String]) throws -> SpotDetailsPage {
        requests.append(ids)
        if failsNext {
            failsNext = false
            throw SpotsAPIError.offline
        }
        let found = ids.filter { !missing.contains($0) }
        return SpotDetailsPage(
            spots: found.map {
                RemoteSpotDetail(
                    id: $0,
                    about: "",
                    obstacles: [],
                    addedByID: nil,
                    addedByName: nil,
                    createdAt: .distantPast,
                    version: version,
                    photos: [],
                )
            },
            missing: ids.filter { missing.contains($0) },
        )
    }

}

// MARK: - TestTime

final class TestTime: Sendable {

    // MARK: Computed Properties

    var now: Date {
        current.withLock { $0 }
    }

    // MARK: Properties

    private let current = Mutex(Date(timeIntervalSince1970: 1_000_000))

    // MARK: Functions

    func advance(by seconds: TimeInterval) {
        current.withLock { $0.addTimeInterval(seconds) }
    }
}
