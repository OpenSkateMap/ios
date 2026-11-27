import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributeKit

@Suite(.timeLimit(.minutes(1)))
struct NearYouRequestTests {

    private static let here = NearYouRequest.Origin(latitude: 59.9343, longitude: 30.3351, isPersonal: true)

    private static let date = Date(timeIntervalSince1970: 1_790_000_000)

    private static func spot(_ id: String,
                             metresNorth: Double,
                             cover: String? = nil,
                             condition: SpotCondition = .skateable,
                             isPrivate: Bool = false,
                             obstacles: [String] = ["ledge"]) -> SpotIndex {
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
            obstacles: obstacles,
        )
    }

    private static func edit(_ id: String, of spotID: String, status: SubmissionStatus) -> MySubmission {
        MySubmission(
            id: id,
            title: spotID,
            kind: .street,
            cityID: "spb",
            latitude: here.latitude,
            longitude: here.longitude,
            status: status,
            rejectReason: status == .rejected ? "photo_rights" : nil,
            spotID: spotID,
            changedFields: [.photos],
            coverThumbhash: nil,
            createdAt: date,
            updatedAt: date,
        )
    }

    private static func fetch(_ origin: NearYouRequest.Origin?,
                              spots: [SpotIndex],
                              drafts: [SubmissionDraft] = [],
                              submissions: [MySubmission] = []) throws -> NearYou {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        try database.write { db in
            try SpotIndex.insert { spots }.execute(db)
            try SubmissionDraft.insert { drafts }.execute(db)
            try MySubmission.insert { submissions }.execute(db)
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
            Self.spot("out-of-reach", metresNorth: 80000),
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

    @Test
    func `each card asks for what the spot is missing, a photo before obstacles`() throws {
        let nearYou = try Self.fetch(Self.here, spots: [
            Self.spot("bare", metresNorth: 100, obstacles: []),
            Self.spot("unlisted", metresNorth: 200, cover: "photos/a.jpg", obstacles: []),
            Self.spot("complete", metresNorth: 300, cover: "photos/b.jpg"),
        ])

        expectNoDifference(nearYou.spots.map(\.ask), [.noPhoto, .noObstacles, nil])
    }

    @Test
    func `somewhere to look with nothing there is an empty area, not a missing one`() throws {
        let nearYou = try Self.fetch(Self.here, spots: [Self.spot("far", metresNorth: 80000)])

        expectNoDifference(nearYou, NearYou(hasOrigin: true))
    }

    @Test
    func `spots you already have an edit on its way or waiting for are left out until it's decided`() throws {
        let draft = SubmissionDraft(
            id: "draft",
            title: "unsent",
            about: "",
            kind: .street,
            obstacles: [],
            condition: .skateable,
            latitude: Self.here.latitude,
            longitude: Self.here.longitude,
            note: "",
            editsSpotID: "unsent",
            changedFields: [.photos],
            createdAt: Self.date,
        )
        let nearYou = try Self.fetch(
            Self.here,
            spots: [
                Self.spot("unsent", metresNorth: 100),
                Self.spot("waiting", metresNorth: 200),
                Self.spot("rejected", metresNorth: 300),
                Self.spot("open", metresNorth: 400),
            ],
            drafts: [draft],
            submissions: [
                Self.edit("a", of: "waiting", status: .pending),
                Self.edit("b", of: "rejected", status: .rejected),
            ],
        )

        expectNoDifference(nearYou.spots.map(\.id), ["rejected", "open"])
    }
}
