public import APIClientKit
import Foundation
public import OpenAPIRuntime
public import SpotModelKit

// MARK: - ContributionsAPIManager

public struct ContributionsAPIManager: Sendable {
    public var save: @Sendable (_ draft: SubmissionDraft, _ photos: [DraftPhoto]) async throws -> MySubmission
    public var mySubmissions: @Sendable () async throws -> [MySubmission]
    public var nearby: @Sendable (_ latitude: Double, _ longitude: Double, _ radiusMeters: Int) async throws -> [NearbySpot]
    public var saveVideo: @Sendable (_ draft: VideoDraft) async throws -> Void

    public init(save: @escaping @Sendable (_ draft: SubmissionDraft, _ photos: [DraftPhoto]) async throws -> MySubmission,
                mySubmissions: @escaping @Sendable () async throws -> [MySubmission],
                nearby: @escaping @Sendable (_ latitude: Double, _ longitude: Double, _ radiusMeters: Int) async throws
                    -> [NearbySpot],
                saveVideo: @escaping @Sendable (_ draft: VideoDraft) async throws -> Void) {
        self.save = save
        self.mySubmissions = mySubmissions
        self.nearby = nearby
        self.saveVideo = saveVideo
    }
}

extension ContributionsAPIManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> ContributionsAPIManager {
        ContributionsAPIManager(
            save: { draft, photos in
                let submission =
                    if let spotID = draft.editsSpotID {
                        try await authorized(credentials, makeClient) {
                            try await $0.saveSpotEdit(
                                path: .init(submissionId: draft.id),
                                body: .json(Components.Schemas.SpotEditDraft(draft, spotID: spotID, photos)),
                            ).ok.body.json.data
                        }
                    } else {
                        try await authorized(credentials, makeClient) {
                            try await $0.saveSubmission(
                                path: .init(submissionId: draft.id),
                                body: .json(Components.Schemas.NewSpotDraft(draft, photos)),
                            ).ok.body.json.data
                        }
                    }
                return MySubmission(submission)
            },
            mySubmissions: {
                try await authorized(credentials, makeClient) { try await $0.getMySubmissions().ok.body.json.data }.submissions
                    .map(MySubmission.init)
            },
            nearby: { latitude, longitude, radius in
                try await authorized(credentials, makeClient) {
                    try await $0.getNearbySpots(query: .init(latitude: latitude, longitude: longitude, radiusMeters: radius)).ok
                        .body.json.data
                }
                .spots.map { NearbySpot(id: $0.id, title: $0.title, kind: SpotKind($0.kind), distanceMeters: $0.distanceMeters) }
            },
            saveVideo: { draft in
                _ = try await authorized(credentials, makeClient) {
                    try await $0.saveVideo(
                        path: .init(spotId: draft.spotID, videoId: draft.id),
                        body: .json(.init(url: draft.url, caption: draft.caption)),
                    ).ok
                }
            },
        )
    }

    public static let preview = ContributionsAPIManager(
        save: { draft, _ in
            MySubmission(
                id: draft.id,
                title: draft.title,
                kind: draft.kind,
                cityID: nil,
                latitude: draft.latitude,
                longitude: draft.longitude,
                status: .pending,
                rejectReason: nil,
                spotID: draft.editsSpotID,
                changedFields: draft.changedFields,
                coverThumbhash: nil,
                createdAt: draft.createdAt,
                updatedAt: draft.createdAt,
            )
        },
        mySubmissions: { [] },
        nearby: { _, _, _ in [] },
        saveVideo: { _ in },
    )
}

// MARK: - Mapping

extension Components.Schemas.NewSpotDraft {
    init(_ draft: SubmissionDraft, _ photos: [DraftPhoto]) {
        self.init(
            kind: .newSpot,
            title: draft.title,
            description: draft.about,
            spotKind: .init(draft.kind),
            obstacles: draft.obstacles,
            condition: .init(draft.condition),
            latitude: draft.latitude,
            longitude: draft.longitude,
            note: draft.note,
            collectionId: draft.collectionID,
            photos: photos.sorted { $0.position < $1.position }.map {
                .init(photoId: $0.id, thumbhash: $0.thumbhash, credit: Components.Schemas.PhotoCredit($0))
            },
        )
    }
}

extension Components.Schemas.SpotEditDraft {
    init(_ draft: SubmissionDraft, spotID: String, _ photos: [DraftPhoto]) {
        let changed = Set(draft.changedFields)
        self.init(
            spotId: spotID,
            changes: .init(
                title: changed.contains(.title) ? draft.title : nil,
                description: changed.contains(.description) ? draft.about : nil,
                spotKind: changed.contains(.spotKind) ? .init(draft.kind) : nil,
                obstacles: changed.contains(.obstacles) ? draft.obstacles : nil,
                condition: changed.contains(.condition) ? .init(draft.condition) : nil,
                latitude: changed.contains(.location) ? draft.latitude : nil,
                longitude: changed.contains(.location) ? draft.longitude : nil,
            ),
            photos: photos.sorted { $0.position < $1.position }.map {
                .init(photoId: $0.id, thumbhash: $0.thumbhash, credit: Components.Schemas.PhotoCredit($0))
            },
            photoEdit: draft.photoOrder.flatMap { order in draft.basePhotoIDs.map { .init(order: order, base: $0) } },
            note: draft.note,
        )
    }
}

extension Components.Schemas.PhotoCredit {
    init(_ photo: DraftPhoto) {
        self = photo.credit.map {
            .someoneElse(.init(takenBy: .someoneElse, credit: $0, hasPermission: true, sourceUrl: photo.sourceURL))
        } ?? .submitter(.init(takenBy: .submitter))
    }
}

extension MySubmission {
    init(_ submission: Components.Schemas.Submission) {
        self.init(
            id: submission.id,
            title: submission.title,
            kind: SpotKind(submission.spotKind),
            cityID: submission.cityId,
            latitude: submission.latitude,
            longitude: submission.longitude,
            status: SubmissionStatus(submission.status),
            rejectReason: submission.rejectReason?.rawValue,
            spotID: submission.spotId,
            collectionID: submission.collectionId,
            changedFields: submission.changedFields.compactMap { SpotEditField(rawValue: $0.rawValue) },
            coverThumbhash: submission.photos.min { $0.position < $1.position }?.thumbhash,
            removalReason: submission.removal.flatMap { SpotRemovalReason(rawValue: $0.reason.rawValue) },
            removedAt: submission.removal?.removedAt,
            createdAt: submission.createdAt,
            updatedAt: submission.updatedAt,
        )
    }
}
