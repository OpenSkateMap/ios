import CustomDump
import GRDB
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotModelKit

@Suite(.timeLimit(.minutes(1)))
struct SpotIndexViewportTests {
    private let database: any DatabaseWriter

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert {
                spot("southbank", latitude: 51.5066, longitude: -0.1169, version: 1)
                spot("stockwell", latitude: 51.4710, longitude: -0.1163, version: 4)
                spot("macba", latitude: 41.3830, longitude: 2.1665, version: 2)
                spot("suva", latitude: -18.1416, longitude: 178.4419, version: 3)
                spot("taveuni", latitude: -16.8600, longitude: -179.9500, version: 5)
            }
            .execute(db)
        }
    }

    @Test
    func `only spots inside the box come back, newest first`() throws {
        let london = CoordinateBox(south: 51.28, west: -0.51, north: 51.69, east: 0.33)

        let ids = try database.read { db in try SpotIndex.inViewport(london).fetchAll(db).map(\.id) }

        expectNoDifference(ids, ["stockwell", "southbank"])
    }

    @Test
    func `a box across the antimeridian finds spots on both sides`() throws {
        let fiji = CoordinateBox(south: -20, west: 177, north: -15, east: -178)

        let ids = try database.read { db in try SpotIndex.inViewport(fiji).fetchAll(db).map(\.id) }

        expectNoDifference(ids, ["taveuni", "suva"])
    }

    @Test
    func `the nearest spots come first, however old they are`() throws {
        let london = CoordinateBox(south: 51.28, west: -0.51, north: 51.69, east: 0.33)

        let ids = try database.read { db in
            try SpotIndex.nearest(toLatitude: 51.5066, longitude: -0.1169, in: london, limit: 1).fetchAll(db).map(\.id)
        }

        expectNoDifference(ids, ["southbank"])
    }

    @Test
    func `a box knows what it contains, across the antimeridian too`() {
        let london = CoordinateBox(south: 51.28, west: -0.51, north: 51.69, east: 0.33)
        let fiji = CoordinateBox(south: -20, west: 177, north: -15, east: -178)

        #expect(london.contains(latitude: 51.5066, longitude: -0.1169))
        #expect(!london.contains(latitude: 41.3830, longitude: 2.1665))
        #expect(fiji.contains(latitude: -16.86, longitude: -179.95))
        #expect(fiji.contains(latitude: -18.14, longitude: 178.44))
        #expect(!fiji.contains(latitude: -18.14, longitude: 0))
    }

    @Test
    func `the query runs on the location index`() throws {
        let box = CoordinateBox(south: 51.28, west: -0.51, north: 51.69, east: 0.33)
        let sql = "EXPLAIN QUERY PLAN " + SpotIndex.inViewport(box).query.debugDescription

        let plan = try database.read { db in try Row.fetchAll(db, sql: sql).map { $0["detail"] as String } }

        #expect(plan.contains { $0.contains("spot_index_location") })
    }

    private func spot(_ id: String, latitude: Double, longitude: Double, version: Int) -> SpotIndex {
        SpotIndex(
            id: id,
            title: id,
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: latitude,
            longitude: longitude,
            version: version,
        )
    }
}
