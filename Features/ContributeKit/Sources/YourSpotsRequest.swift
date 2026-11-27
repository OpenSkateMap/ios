import ComponentKit
import CoreLocation
import Foundation
import ReviewKit
import SpotModelKit
import SQLiteData

struct YourSpotsRequest: FetchKeyRequest {

    // MARK: Static Properties

    /// The server calls a published spot this close a likely duplicate.
    private static let duplicateMeters: CLLocationDistance = 150

    // MARK: Static Functions

    static func rejectReasonTitle(_ reason: String) -> String {
        RejectReason(rawValue: reason)?.title ?? reason
    }

    /// Phrased from the reason; an edit goes back to its spot, a new spot starts over, and a duplicate's photos go to
    /// the spot that's already there when the map has it.
    static func wayBack(for submission: MySubmission, in db: Database) throws -> YourSpot.WayBack {
        let reason = submission.rejectReason.flatMap(RejectReason.init(rawValue:))
        let retry: YourSpot.WayBack.Action =
            if submission.isEdit, let spotID = submission.spotID {
                .suggestEdit(spotID: spotID)
            } else {
                .newSpot
            }
        let strings = ContributeKitStrings.Contribute.YourSpots.WayBack.self
        switch reason {
        case .duplicate where submission.isEdit:
            return YourSpot.WayBack(line: strings.duplicateEdit, action: retry)

        case .duplicate:
            let existing = try spotAlreadyThere(latitude: submission.latitude, longitude: submission.longitude, in: db)
            return YourSpot.WayBack(line: strings.duplicate, action: existing.map { .addPhotos(spotID: $0) })

        case .notASpot:
            return YourSpot.WayBack(line: submission.isEdit ? strings.notASpotEdit : strings.notASpot, action: retry)

        case .wrongLocation:
            return YourSpot.WayBack(line: strings.wrongLocation, action: retry)

        case .privateProperty:
            return YourSpot.WayBack(line: strings.privateProperty, action: .newSpot)

        case .photoRights:
            return YourSpot.WayBack(line: strings.photoRights, action: retry)

        case nil:
            return YourSpot.WayBack(line: strings.other, action: retry)
        }
    }

    private static func spotAlreadyThere(latitude: Double, longitude: Double, in db: Database) throws -> SpotIndex.ID? {
        let reach = duplicateMeters / 111_320
        let east = reach / max(cos(latitude * .pi / 180), 0.1)
        let box = CoordinateBox(south: latitude - reach, west: longitude - east, north: latitude + reach, east: longitude + east)
        let here = CLLocation(latitude: latitude, longitude: longitude)
        return try SpotIndex
            .nearest(toLatitude: latitude, longitude: longitude, in: box, limit: 5)
            .fetchAll(db)
            .first { spot in
                !spot.isPrivate
                    && here.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude)) <= duplicateMeters
            }?
            .id
    }

    private static func badge(for draft: SubmissionDraft) -> YourSpot.Badge {
        switch SubmittedSpotStatus(draft) {
        case .sending, .sent: .sending
        case .waitingForNetwork: .waitingForNetwork
        case .failed(let reason): .failed(reason: reason)
        }
    }

    private static func badge(for submission: MySubmission,
                              collections: [String: String],
                              in db: Database) throws -> YourSpot.Badge {
        if let reason = submission.removalReason {
            return .removed(reason: reason.explanation)
        }
        if let collectionID = submission.collectionID {
            return .private(collection: collections[collectionID])
        }
        return switch submission.status {
        case .pending: .pending
        case .approved: .approved
        case .rejected:
            try .rejected(
                reason: submission.rejectReason.map(Self.rejectReasonTitle),
                wayBack: wayBack(for: submission, in: db),
            )
        }
    }

    private static func city(containing latitude: Double, _ longitude: Double, in cities: [City]) -> City? {
        cities.first { city in
            (city.minLatitude...city.maxLatitude).contains(latitude)
                && (city.minLongitude...city.maxLongitude).contains(longitude)
        }
    }

    func fetch(_ db: Database) throws -> [YourSpot] {
        let cities = try City.all.fetchAll(db)
        let collections = try Dictionary(
            SpotCollection.select { ($0.id, $0.name) }.fetchAll(db),
            uniquingKeysWith: { first, _ in first },
        )
        let drafts = try SubmissionDraft.order { $0.createdAt.desc() }.fetchAll(db)
        let covers = try Dictionary(
            DraftPhoto.where { $0.position.eq(0) }.select { ($0.draftID, $0.thumbhash) }.fetchAll(db),
            uniquingKeysWith: { first, _ in first },
        )
        let unsent = drafts.map { draft in
            YourSpot(
                id: draft.id,
                title: draft.title,
                isEdit: draft.editsSpotID != nil,
                kind: draft.kind,
                cityName: Self.city(containing: draft.latitude, draft.longitude, in: cities)?.localizedName,
                coverKey: nil,
                thumbhash: covers[draft.id],
                badge: Self.badge(for: draft),
                spotID: nil,
                date: draft.createdAt,
                isUnsent: true,
            )
        }
        let sent = try MySubmission.order { $0.createdAt.desc() }.fetchAll(db).map { submission in
            YourSpot(
                id: submission.id,
                title: submission.title,
                isEdit: submission.isEdit,
                kind: submission.kind,
                cityName: (cities.first { $0.id == submission.cityID }
                    ?? Self.city(containing: submission.latitude, submission.longitude, in: cities))?.localizedName,
                coverKey: submission.coverKey,
                thumbhash: submission.coverThumbhash,
                badge: try Self.badge(for: submission, collections: collections, in: db),
                spotID: submission.removalReason == nil && (submission.status == .approved || submission.collectionID != nil)
                    ? submission.spotID
                    : nil,
                date: submission.createdAt,
                isUnsent: false,
            )
        }
        return unsent + sent
    }

}
