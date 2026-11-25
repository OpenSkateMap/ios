import CustomDump
import GRDB
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotModelKit

// MARK: - SpotSearchTests

@Suite(.timeLimit(.minutes(1)))
struct SpotSearchTests {
    private let database: any DatabaseWriter

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        let spots = [
            spot("novokrestovskaya", title: "Новокрестовская", latitude: 59.97),
            spot("yolki", title: "Ёлки-палки", latitude: 59.9),
            spot("far", title: "Old South Bank", latitude: 51.9),
            spot("near", title: "The South Ledges", latitude: 51.5),
            spot("prefix", title: "Southbank Undercroft", latitude: 52.5),
            spot("macba", title: "MACBA", latitude: 41.38),
        ]
        try database.write { db in
            try SpotIndex.insert { spots }.execute(db)
            try SpotSearchText.replace(for: spots, db)
        }
    }

    @Test
    func `a lowercase query finds a capitalised Cyrillic name`() throws {
        expectNoDifference(try ids("новокрестовская"), ["novokrestovskaya"])
        expectNoDifference(try ids("НОВО"), ["novokrestovskaya"])
    }

    @Test
    func `the middle of a word still finds it, after word starts`() throws {
        expectNoDifference(try ids("крестовская"), ["novokrestovskaya"])
    }

    @Test
    func `a Latin spelling finds a Cyrillic name`() throws {
        expectNoDifference(try ids("novokrestovskaya"), ["novokrestovskaya"])
        expectNoDifference(try ids("Novokrest"), ["novokrestovskaya"])
    }

    @Test
    func `ё and е are the same letter`() throws {
        expectNoDifference(try ids("елки"), ["yolki"])
        expectNoDifference(try ids("палки"), ["yolki"])
    }

    @Test
    func `a letter or two off still finds it, short words don't`() throws {
        expectNoDifference(try ids("Новокрестоская"), ["novokrestovskaya"])
        expectNoDifference(try ids("macbs"), ["macba"])
        expectNoDifference(try ids("mac"), ["macba"])
        expectNoDifference(try ids("mbc"), [])
    }

    @Test
    func `names starting with the query come first, then the nearest`() throws {
        expectNoDifference(try ids("south", near: (latitude: 51.5, longitude: -0.1)), ["prefix", "near", "far"])
    }

    @Test
    func `query syntax typed into the field is just text`() throws {
        expectNoDifference(try ids("\"OR* NEAR("), [])
    }

    @Test
    func `a spot leaving the index leaves search with it`() throws {
        try database.write { db in try SpotIndex.find("macba").delete().execute(db) }

        expectNoDifference(try ids("macba"), [])
        let rows = try database.read { db in try SpotSearchText.fetchCount(db) }
        expectNoDifference(rows, 5)
    }

    @Test
    func `Latin spellings: the system's and the common one`() {
        expectNoDifference(
            SpotSearchText.latinSpellings(of: "Новокрестовская").split(separator: " ").contains("novokrestovskaya"),
            true,
        )
        expectNoDifference(SpotSearchText.latinSpellings(of: "MACBA"), "")
    }

    private func ids(_ query: String, near center: (latitude: Double, longitude: Double)? = nil) throws -> [String] {
        try database.read { db in try SpotSearch.spots(matching: query, near: center, limit: 30, db).map(\.id) }
    }
}

private func spot(_ id: String, title: String, latitude: Double) -> SpotIndex {
    SpotIndex(
        id: id,
        title: title,
        kind: .street,
        condition: .skateable,
        cityID: nil,
        latitude: latitude,
        longitude: -0.1,
        version: 1,
    )
}
