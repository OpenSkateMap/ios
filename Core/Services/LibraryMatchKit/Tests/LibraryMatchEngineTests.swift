import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import LibraryMatchKit

// MARK: - LibraryMatchEngineTests

@Suite(.timeLimit(.minutes(1)))
struct LibraryMatchEngineTests {

    // MARK: Nested Types

    struct Row: Equatable {
        let id: String
        let assetID: String
        let state: LibraryMatchState
    }

    // MARK: Static Properties

    static let undercroft = LibraryMatcherTests.undercroft
    static let park = LibraryMatcherTests.park
    static let day = LibraryMatcherTests.now.addingTimeInterval(-5 * 86400)

    // MARK: Properties

    private let photos = FakePhotoLibrary(access: .full)
    private let database: any DatabaseWriter
    private let engine: LibraryMatchEngine

    // MARK: Lifecycle

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots, .libraryMatches])
        engine = LibraryMatchEngine(
            database: database,
            library: photos.library,
            classifier: photos.classifier,
            now: { LibraryMatcherTests.now },
            calendar: LibraryMatcherTests.london,
        )
        try addSpot(Self.undercroft)
        try addSpot(Self.park)
    }

    // MARK: Functions

    @Test
    func `a scan keeps the best photo of each spot per day`() async throws {
        photos.add(LibraryMatcherTests.asset("plain", takenAt: Self.day))
        photos.add(LibraryMatcherTests.asset("trick", takenAt: Self.day.addingTimeInterval(300)), labels: ["skateboarding": 0.9])
        photos.add(LibraryMatcherTests.asset("later", takenAt: Self.day.addingTimeInterval(2 * 86400)))
        photos.add(LibraryMatcherTests.asset("lunch", near: Self.park, takenAt: Self.day), labels: ["food": 0.9])
        photos.add(LibraryAsset(id: "home", latitude: 48.85, longitude: 2.35, takenAt: Self.day))

        let outcome = await engine.scan(isLimited: false)

        expectNoDifference(outcome, .scanned)
        expectNoDifference(try rows(), [
            Row(id: "undercroft/2026-11-13", assetID: "trick", state: .new),
            Row(id: "undercroft/2026-11-15", assetID: "later", state: .new),
        ])
    }

    @Test
    func `private and demolished spots are left out`() async throws {
        try await database.write { db in
            try SpotIndex.find("undercroft").update { $0.condition = #bind(SpotCondition.demolished) }.execute(db)
            try SpotIndex.find("park").update { $0.isPrivate = true }.execute(db)
        }
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        photos.add(LibraryMatcherTests.asset("b", near: Self.park, takenAt: Self.day))

        _ = await engine.scan(isLimited: false)

        expectNoDifference(try rows(), [])
    }

    @Test
    func `a skipped spot and day never comes back, even with a better photo`() async throws {
        photos.add(LibraryMatcherTests.asset("plain", takenAt: Self.day))
        _ = await engine.scan(isLimited: false)

        await engine.setState(.skipped, ofMatch: "undercroft/2026-11-13")
        photos.add(LibraryMatcherTests.asset("trick", takenAt: Self.day.addingTimeInterval(60)), labels: ["skateboarding": 1])
        photos.expireTokens()
        _ = await engine.scan(isLimited: false)

        expectNoDifference(try rows(), [Row(id: "undercroft/2026-11-13", assetID: "plain", state: .skipped)])
    }

    @Test
    func `photos sent with an edit leave as used`() async throws {
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        photos.add(LibraryMatcherTests.asset("b", near: Self.park, takenAt: Self.day))
        _ = await engine.scan(isLimited: false)

        await engine.markUsed(assetIDs: ["b"])

        expectNoDifference(try rows(), [
            Row(id: "park/2026-11-13", assetID: "b", state: .used),
            Row(id: "undercroft/2026-11-13", assetID: "a", state: .new),
        ])
    }

    @Test
    func `the next scan reads only what changed since, and a deleted photo's match goes`() async throws {
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        photos.add(LibraryMatcherTests.asset("b", near: Self.park, takenAt: Self.day))
        _ = await engine.scan(isLimited: false)

        photos.add(LibraryMatcherTests.asset("c", takenAt: Self.day.addingTimeInterval(86400)))
        photos.delete("b")
        _ = await engine.scan(isLimited: false)

        expectNoDifference(photos.reads, ["all", "since 2"])
        expectNoDifference(try rows().map(\.assetID), ["a", "c"])
    }

    @Test
    func `a better photo of the same spot and day replaces a waiting match`() async throws {
        photos.add(LibraryMatcherTests.asset("plain", takenAt: Self.day))
        _ = await engine.scan(isLimited: false)

        photos.add(LibraryMatcherTests.asset("trick", takenAt: Self.day.addingTimeInterval(60)), labels: ["skateboarding": 1])
        _ = await engine.scan(isLimited: false)

        expectNoDifference(try rows(), [Row(id: "undercroft/2026-11-13", assetID: "trick", state: .new)])
    }

    @Test
    func `a new spot, or access that changed, reads the whole library again`() async throws {
        let ledges = SpotPoint(id: "ledges", latitude: 51.53, longitude: -0.12, kind: .street)
        photos.add(LibraryMatcherTests.asset("old", near: ledges, takenAt: Self.day))
        _ = await engine.scan(isLimited: true)

        _ = await engine.scan(isLimited: false)
        try addSpot(ledges)
        _ = await engine.scan(isLimited: false)

        expectNoDifference(photos.reads, ["all", "all", "all"])
        expectNoDifference(try rows().map(\.assetID), ["old"])
    }

    @Test
    func `reset clears the matches and the last scan`() async throws {
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        _ = await engine.scan(isLimited: false)

        await engine.reset()
        _ = await engine.scan(isLimited: false)

        expectNoDifference(photos.reads, ["all", "all"])
        expectNoDifference(try rows().map(\.assetID), ["a"])
    }

    @Test
    func `a scan the account's end interrupts writes nothing`() async throws {
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        photos.holdNextRead()
        async let outcome = engine.scan(isLimited: false)
        for await _ in photos.readHeld {
            break
        }

        await engine.reset()
        let ended = await outcome

        expectNoDifference(ended, .cancelled)
        expectNoDifference(try rows(), [])
        let scans = try await database.read { db in try LibraryScan.fetchCount(db) }
        expectNoDifference(scans, 0)
    }

    @Test
    func `a newer scan replaces the one under way`() async throws {
        photos.add(LibraryMatcherTests.asset("a", takenAt: Self.day))
        photos.holdNextRead()
        async let first = engine.scan(isLimited: true)
        for await _ in photos.readHeld {
            break
        }

        let second = await engine.scan(isLimited: false)
        let replaced = await first

        expectNoDifference(replaced, .cancelled)
        expectNoDifference(second, .scanned)
        expectNoDifference(try rows().map(\.assetID), ["a"])
    }

    private func addSpot(_ spot: SpotPoint) throws {
        try database.write { db in
            try SpotIndex.insert {
                SpotIndex(
                    id: spot.id,
                    title: spot.id,
                    kind: spot.kind,
                    condition: .skateable,
                    cityID: nil,
                    latitude: spot.latitude,
                    longitude: spot.longitude,
                    version: 1,
                )
            }
            .execute(db)
        }
    }

    private func rows() throws -> [Row] {
        try database.read { db in
            try LibraryMatch.order(by: \.id).fetchAll(db).map { Row(id: $0.id, assetID: $0.assetID, state: $0.state) }
        }
    }
}
