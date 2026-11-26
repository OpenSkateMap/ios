import CustomDump
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributeKit

@Suite(.timeLimit(.minutes(1)))
struct NearYouRequestTests {

    private static let here = NearYouRequest.Origin(latitude: 59.9343, longitude: 30.3351, isPersonal: true)

    private static func spot(_ id: String,
                             metresNorth: Double,
                             cover: String? = nil,
                             condition: SpotCondition = .skateable,
                             isPrivate: Bool = false) -> SpotIndex {
        SpotIndex(
            id: id,
            title: id,
            kind: .street,
            condition: condition,
            cityID: "spb",
            latitude: here.latitude + metresNorth / 111_320,
            longitude: here.longitude,
            version: 1,
            coverKey: cover,
            isPrivate: isPrivate,
        )
    }

    private static func fetch(_ origin: NearYouRequest.Origin?, spots: [SpotIndex]) throws -> NearYou {
        let database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert { spots }.execute(db)
            try City.insert {
                City(
                    id: "spb",
                    slug: "saint-petersburg",
                    name: "Saint Petersburg",
                    countryCode: "RU",
                    minLatitude: 59.7,
                    minLongitude: 29.4,
                    maxLatitude: 60.2,
                    maxLongitude: 30.8,
                )
            }.execute(db)
        }
        return try database.read { db in try NearYouRequest(origin: origin).fetch(db) }
    }

    @Test
    func `spots without a photo come first, nearest first, leaving out private and demolished ones`() throws {
        let nearYou = try Self.fetch(Self.here, spots: [
            Self.spot("photo-near", metresNorth: 100, cover: "photos/a.jpg"),
            Self.spot("bare-far", metresNorth: 2000),
            Self.spot("bare-near", metresNorth: 300),
            Self.spot("private", metresNorth: 50, isPrivate: true),
            Self.spot("gone", metresNorth: 60, condition: .demolished),
            Self.spot("out-of-reach", metresNorth: 40000),
        ])

        expectNoDifference(nearYou.spots.map(\.id), ["bare-near", "bare-far", "photo-near"])
        // To 10 m: the request measures on the globe, the test placed the spots on a flat one.
        expectNoDifference(nearYou.spots.map { $0.distanceMeters.map { ($0 + 5) / 10 * 10 } }, [300, 2000, 100])
        expectNoDifference(nearYou.cityName, "Saint Petersburg")
    }

    @Test
    func `around the map's last camera there are no distances, and without an origin nothing`() throws {
        var map = Self.here
        map.isPersonal = false
        let spots = [Self.spot("bare", metresNorth: 300)]

        expectNoDifference(try Self.fetch(map, spots: spots).spots.map(\.distanceMeters), [nil])
        expectNoDifference(try Self.fetch(nil, spots: spots), NearYou())
    }
}
