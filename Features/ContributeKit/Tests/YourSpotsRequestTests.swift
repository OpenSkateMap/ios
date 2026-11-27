import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributeKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct YourSpotsRequestTests {

    private static let latitude = 51.506
    private static let longitude = -0.116
    private static let date = Date(timeIntervalSince1970: 1_790_000_000)

    private static func rejected(_ id: String,
                                 reason: String?,
                                 editing spotID: String? = nil,
                                 metresNorth: Double = 0) -> MySubmission {
        MySubmission(
            id: id,
            title: id,
            kind: .street,
            cityID: nil,
            latitude: latitude + metresNorth / 111_320,
            longitude: longitude,
            status: .rejected,
            rejectReason: reason,
            spotID: spotID,
            changedFields: spotID == nil ? [] : [.photos],
            coverThumbhash: nil,
            createdAt: date,
            updatedAt: date,
        )
    }

    private static func spot(_ id: String, metresNorth: Double, isPrivate: Bool = false) -> SpotIndex {
        SpotIndex(
            id: id,
            title: id,
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: latitude + metresNorth / 111_320,
            longitude: longitude,
            version: 1,
            isPrivate: isPrivate,
        )
    }

    private static func wayBacks(_ submissions: [MySubmission], spots: [SpotIndex] = []) throws -> [YourSpot.WayBack?] {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        try database.write { db in
            try SpotIndex.insert { spots }.execute(db)
            try MySubmission.insert { submissions }.execute(db)
        }
        let rows = try database.read { db in try YourSpotsRequest().fetch(db) }
        return submissions.map { submission in
            guard case .rejected(_, let wayBack) = rows.first(where: { $0.id == submission.id })?.badge else {
                return nil
            }
            return wayBack
        }
    }

    @Test
    func `a rejected edit goes back to its spot and a rejected new spot starts over, each phrased from its reason`() throws {
        let strings = ContributeKitStrings.Contribute.YourSpots.WayBack.self
        let wayBacks = try Self.wayBacks([
            Self.rejected("pin", reason: "wrong_location", editing: "spot-1"),
            Self.rejected("rights", reason: "photo_rights"),
            Self.rejected("not-a-spot", reason: "not_a_spot"),
            Self.rejected("private", reason: "private_property", editing: "spot-2"),
            Self.rejected("unknown", reason: "too_blurry", editing: "spot-3"),
            Self.rejected("none", reason: nil),
        ])

        expectNoDifference(wayBacks, [
            YourSpot.WayBack(line: strings.wrongLocation, action: .suggestEdit(spotID: "spot-1")),
            YourSpot.WayBack(line: strings.photoRights, action: .newSpot),
            YourSpot.WayBack(line: strings.notASpot, action: .newSpot),
            // Private property isn't fixed by editing the same place.
            YourSpot.WayBack(line: strings.privateProperty, action: .newSpot),
            YourSpot.WayBack(line: strings.other, action: .suggestEdit(spotID: "spot-3")),
            YourSpot.WayBack(line: strings.other, action: .newSpot),
        ])
    }

    @Test
    func `a duplicate new spot's photos go to the public spot already there, or nowhere when the map doesn't have it`() throws {
        let strings = ContributeKitStrings.Contribute.YourSpots.WayBack.self
        let wayBacks = try Self.wayBacks(
            [
                Self.rejected("near", reason: "duplicate"),
                Self.rejected("far", reason: "duplicate", metresNorth: 2000),
                Self.rejected("edit", reason: "duplicate", editing: "spot-1"),
            ],
            spots: [
                Self.spot("hidden", metresNorth: 10, isPrivate: true),
                Self.spot("there", metresNorth: 60),
            ],
        )

        expectNoDifference(wayBacks, [
            YourSpot.WayBack(line: strings.duplicate, action: .addPhotos(spotID: "there")),
            YourSpot.WayBack(line: strings.duplicate, action: nil),
            YourSpot.WayBack(line: strings.duplicateEdit, action: .suggestEdit(spotID: "spot-1")),
        ])
    }
}
