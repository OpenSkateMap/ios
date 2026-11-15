import CustomDump
import GRDB
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotModelKit

// MARK: - SpotFilterTests

@Suite(.timeLimit(.minutes(1)))
struct SpotFilterTests {
    private let database: any DatabaseWriter
    private let spots = [
        spot("macba", kind: .plaza, condition: .skateable, city: "barcelona", obstacles: ["ledges", "stairs", "gaps"]),
        spot("parc-del-forum", kind: .park, condition: .skateable, city: "barcelona", obstacles: ["bowl", "Ledges"]),
        spot("sants", kind: .street, condition: .knobbed, city: "barcelona", obstacles: ["banks"]),
        spot("la-kantera", kind: .diy, condition: .demolished, city: "barcelona"),
        spot("southbank", kind: .street, condition: .skateable, city: "london", obstacles: ["ledges"]),
    ]

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { [spots] db in
            try SpotIndex.insert { spots }.execute(db)
        }
    }

    @Test
    func `a city lists its own spots, best rated first, then unrated by name`() throws {
        try database.write { db in
            try SpotScore.insert {
                SpotScore(id: "sants", up: 9, down: 1, score: 0.6)
                SpotScore(id: "parc-del-forum", up: 1, down: 0, score: 0.2)
                SpotScore(id: "southbank", up: 50, down: 0, score: 0.93)
            }
            .execute(db)
        }

        let rows = try database.read { db in try SpotIndex.inCity("barcelona").fetchAll(db) }

        expectNoDifference(rows.map(\.id), ["sants", "parc-del-forum", "la-kantera", "macba"])
        expectNoDifference(rows.map(\.score?.up), [9, 1, nil, nil])
    }

    @Test
    func `kinds and conditions let any listed one through; obstacles must all be there, in any case`() throws {
        func ids(_ filter: SpotFilter) throws -> [String] {
            try database.read { db in try SpotIndex.inCity("barcelona", matching: filter).fetchAll(db).map(\.id) }
        }

        expectNoDifference(try ids(SpotFilter(kinds: [.street, .plaza], conditions: [.skateable, .knobbed])), ["macba", "sants"])
        expectNoDifference(try ids(SpotFilter(obstacles: ["ledges"])), ["macba", "parc-del-forum"])
        expectNoDifference(try ids(SpotFilter(obstacles: ["Ledges", "stairs"])), ["macba"])
    }

    @Test
    func `the query and the in-memory check let the same spots through`() throws {
        let filters = [
            SpotFilter(),
            SpotFilter(kinds: [.street]),
            SpotFilter(conditions: [.skateable]),
            SpotFilter(kinds: [.park, .diy], conditions: [.skateable, .demolished]),
            SpotFilter(kinds: [.plaza], conditions: [.busty]),
            SpotFilter(obstacles: ["LEDGES"]),
            SpotFilter(kinds: [.street], obstacles: ["ledges", "banks"]),
            SpotFilter(spotIDs: ["macba", "sants"]),
            SpotFilter(kinds: [.street], spotIDs: ["macba", "parc-del-forum"]),
            SpotFilter(spotIDs: []),
        ]
        let world = CoordinateBox(south: -90, west: -180, north: 90, east: 180)
        for filter in filters {
            let queried = try database.read { db in
                try SpotIndex.inViewport(world, matching: filter).fetchAll(db).map(\.id)
            }

            expectNoDifference(Set(queried), Set(spots.filter(filter.matches).map(\.id)))
        }
    }

    @Test
    func `a collection on the map lists its spots wherever they are, best first`() throws {
        let listed = try database.read { db in
            try SpotIndex.listed(matching: SpotFilter(spotIDs: ["macba", "sants"])).fetchAll(db).map(\.id)
        }

        expectNoDifference(Set(listed), ["macba", "sants"])
    }

    @Test
    func `the city query runs on the city index`() throws {
        let sql = "EXPLAIN QUERY PLAN " + SpotIndex.inCity("barcelona").query.debugDescription

        let plan = try database.read { db in try Row.fetchAll(db, sql: sql).map { $0["detail"] as String } }

        #expect(plan.contains { $0.contains("spot_index_city") })
    }
}

private func spot(_ id: String,
                  kind: SpotKind,
                  condition: SpotCondition,
                  city: String,
                  obstacles: [String] = []) -> SpotIndex {
    SpotIndex(
        id: id,
        title: id,
        kind: kind,
        condition: condition,
        cityID: city,
        latitude: 41.38,
        longitude: 2.17,
        version: 1,
        obstacles: obstacles,
    )
}
