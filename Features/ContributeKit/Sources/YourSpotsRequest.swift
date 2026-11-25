import ComponentKit
import Foundation
import ReviewKit
import SpotModelKit
import SQLiteData

struct YourSpotsRequest: FetchKeyRequest {
    static func rejectReasonTitle(_ reason: String) -> String {
        RejectReason(rawValue: reason)?.title ?? reason
    }

    private static func badge(for draft: SubmissionDraft) -> YourSpot.Badge {
        switch SubmittedSpotStatus(draft) {
        case .sending, .sent: .sending
        case .waitingForNetwork: .waitingForNetwork
        case .failed(let reason): .failed(reason: reason)
        }
    }

    private static func badge(for submission: MySubmission, collections: [String: String]) -> YourSpot.Badge {
        if let reason = submission.removalReason {
            return .removed(reason: reason.explanation)
        }
        if let collectionID = submission.collectionID {
            return .private(collection: collections[collectionID])
        }
        return switch submission.status {
        case .pending: .pending
        case .approved: .approved
        case .rejected: .rejected(reason: submission.rejectReason.map(Self.rejectReasonTitle))
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
                thumbhash: submission.coverThumbhash,
                badge: Self.badge(for: submission, collections: collections),
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
