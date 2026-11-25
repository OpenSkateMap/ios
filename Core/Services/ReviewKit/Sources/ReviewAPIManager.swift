public import APIClientKit
public import Foundation
public import OpenAPIRuntime
public import SpotModelKit

// MARK: - ReviewQueue

public struct ReviewQueue: Equatable, Codable, Sendable {
    public var cityIDs: [String]?
    public var cards: [ReviewCard]
    public var videos: [VideoReviewCard]
    /// The cities the cards are in, so one made ahead of its first spot (not yet a `City`) still has its name.
    public var cities: [ReviewCity]

    public init(cityIDs: [String]?, cards: [ReviewCard], videos: [VideoReviewCard] = [], cities: [ReviewCity] = []) {
        self.cityIDs = cityIDs
        self.cards = cards
        self.videos = videos
        self.cities = cities
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cityIDs = try container.decodeIfPresent([String].self, forKey: .cityIDs)
        cards = try container.decode([ReviewCard].self, forKey: .cards)
        videos = try container.decode([VideoReviewCard].self, forKey: .videos)
        // A queue cached by an earlier build has none.
        cities = try container.decodeIfPresent([ReviewCity].self, forKey: .cities) ?? []
    }
}

// MARK: - ReviewCity

public struct ReviewCity: Identifiable, Equatable, Codable, Sendable {
    public var localizedName: String {
        City.localizedName(name: name, names: names, preferring: Locale.preferredLanguages)
    }

    public let id: String
    public var name: String
    public var names: [String: String]

    public init(id: String, name: String, names: [String: String]) {
        self.id = id
        self.name = name
        self.names = names
    }

}

// MARK: - VideoDecided

public struct VideoDecided: Equatable, Sendable {
    public var id: String
    public var updatedAt: Date

    public init(id: String, updatedAt: Date) {
        self.id = id
        self.updatedAt = updatedAt
    }
}

// MARK: - ReviewDecided

public struct ReviewDecided: Equatable, Sendable {
    public var id: String
    public var status: SubmissionStatus
    public var spotID: String?
    public var updatedAt: Date

    public init(id: String, status: SubmissionStatus, spotID: String?, updatedAt: Date) {
        self.id = id
        self.status = status
        self.spotID = spotID
        self.updatedAt = updatedAt
    }
}

// MARK: - ReviewAPIManager

public struct ReviewAPIManager: Sendable {
    public var queue: @Sendable (_ cityID: String?, _ limit: Int) async throws -> ReviewQueue
    public var approve: @Sendable (_ id: String, _ edits: SpotEdits, _ seenUpdatedAt: Date) async throws -> ReviewDecided
    public var reject: @Sendable (_ id: String, _ reason: RejectReason, _ seenUpdatedAt: Date) async throws -> ReviewDecided
    public var undo: @Sendable (_ id: String) async throws -> ReviewDecided
    public var approveVideo: @Sendable (_ id: String, _ seenUpdatedAt: Date) async throws -> VideoDecided
    public var rejectVideo: @Sendable (_ id: String, _ reason: VideoRejectReason, _ seenUpdatedAt: Date) async throws
        -> VideoDecided
    public var undoVideo: @Sendable (_ id: String) async throws -> VideoDecided

    public init(queue: @escaping @Sendable (_ cityID: String?, _ limit: Int) async throws -> ReviewQueue,
                approve: @escaping @Sendable (_ id: String, _ edits: SpotEdits, _ seenUpdatedAt: Date) async throws
                    -> ReviewDecided,
                reject: @escaping @Sendable (_ id: String, _ reason: RejectReason, _ seenUpdatedAt: Date) async throws
                    -> ReviewDecided,
                undo: @escaping @Sendable (_ id: String) async throws -> ReviewDecided,
                approveVideo: @escaping @Sendable (_ id: String, _ seenUpdatedAt: Date) async throws -> VideoDecided,
                rejectVideo: @escaping @Sendable (_ id: String, _ reason: VideoRejectReason, _ seenUpdatedAt: Date) async throws
                    -> VideoDecided,
                undoVideo: @escaping @Sendable (_ id: String) async throws -> VideoDecided) {
        self.queue = queue
        self.approve = approve
        self.reject = reject
        self.undo = undo
        self.approveVideo = approveVideo
        self.rejectVideo = rejectVideo
        self.undoVideo = undoVideo
    }
}

extension ReviewAPIManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> ReviewAPIManager {
        ReviewAPIManager(
            queue: { cityID, limit in
                let queue = try await authorized(credentials, makeClient) {
                    try await $0.getReviewQueue(query: .init(cityId: cityID, limit: limit)).ok.body.json.data
                }
                return try ReviewQueue(
                    cityIDs: queue.cityIds,
                    cards: queue.items.map(ReviewCard.init),
                    videos: queue.videos.map(VideoReviewCard.init),
                    cities: queue.cities.map { ReviewCity(id: $0.id, name: $0.name, names: $0.names.additionalProperties) },
                )
            },
            approve: { id, edits, seenUpdatedAt in
                let body = Operations.ApproveSubmission.Input.Body.JsonPayload(
                    edits: edits.isEmpty ? nil : Components.Schemas.SpotEdits(edits),
                    seenUpdatedAt: seenUpdatedAt,
                    wholePhotoList: true,
                )
                return try await ReviewDecided(authorized(credentials, makeClient) {
                    try await $0.approveSubmission(path: .init(submissionId: id), body: .json(body)).ok.body.json.data
                })
            },
            reject: { id, reason, seenUpdatedAt in
                let body = Operations.RejectSubmission.Input.Body.JsonPayload(
                    reason: .init(reason),
                    seenUpdatedAt: seenUpdatedAt,
                )
                return try await ReviewDecided(authorized(credentials, makeClient) {
                    try await $0.rejectSubmission(path: .init(submissionId: id), body: .json(body)).ok.body.json.data
                })
            },
            undo: { id in
                try await ReviewDecided(authorized(credentials, makeClient) {
                    try await $0.undoReviewDecision(path: .init(submissionId: id)).ok.body.json.data
                })
            },
            approveVideo: { id, seenUpdatedAt in
                try await VideoDecided(authorized(credentials, makeClient) {
                    try await $0.approveVideo(path: .init(videoId: id), body: .json(.init(seenUpdatedAt: seenUpdatedAt))).ok.body
                        .json.data
                })
            },
            rejectVideo: { id, reason, seenUpdatedAt in
                try await VideoDecided(authorized(credentials, makeClient) {
                    try await $0.rejectVideo(
                        path: .init(videoId: id),
                        body: .json(.init(reason: .init(reason), seenUpdatedAt: seenUpdatedAt)),
                    ).ok.body.json.data
                })
            },
            undoVideo: { id in
                try await VideoDecided(authorized(credentials, makeClient) {
                    try await $0.undoVideoDecision(path: .init(videoId: id)).ok.body.json.data
                })
            },
        )
    }

    public static let preview = ReviewAPIManager(
        queue: { _, _ in ReviewQueue(cityIDs: nil, cards: []) },
        approve: { id, _, seen in ReviewDecided(id: id, status: .approved, spotID: "preview-spot", updatedAt: seen) },
        reject: { id, _, seen in ReviewDecided(id: id, status: .rejected, spotID: nil, updatedAt: seen) },
        undo: { id in ReviewDecided(id: id, status: .pending, spotID: nil, updatedAt: .now) },
        approveVideo: { id, seen in VideoDecided(id: id, updatedAt: seen) },
        rejectVideo: { id, _, seen in VideoDecided(id: id, updatedAt: seen) },
        undoVideo: { id in VideoDecided(id: id, updatedAt: .now) },
    )
}

// MARK: - Calls

private func authorized<Output>(_ credentials: SessionCredentials,
                                _ makeClient: @Sendable ([any ClientMiddleware]) -> Client,
                                _ call: (Client) async throws -> Output) async throws -> Output {
    try await credentials.authorized(
        makeClient,
        signedOut: ReviewAPIError.unauthorized,
        offline: ReviewAPIError.offline,
        failure: ReviewAPIError.init,
        call,
    )
}

extension ReviewAPIError {
    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 403: self = .forbidden(failure.message ?? "You can't review this")
        case 409: self = .conflict(failure.message ?? "This submission changed")
        case 404, 422: self = .rejected(failure.message ?? ReviewKitStrings.ApiError.refused(failure.status))
        case 429, 500...: self = .unavailable
        default: self = .rejected(ReviewKitStrings.ApiError.refused(failure.status))
        }
    }
}

// MARK: - Mapping

extension ReviewCard {
    init(_ card: Components.Schemas.ReviewCard) {
        let submission = card.value1
        self.init(
            id: submission.id,
            title: submission.title,
            about: submission.description,
            kind: SpotKind(submission.spotKind),
            obstacles: submission.obstacles,
            condition: SpotCondition(submission.condition),
            latitude: submission.latitude,
            longitude: submission.longitude,
            cityID: submission.cityId,
            note: submission.note,
            photos: submission.photos.sorted { $0.position < $1.position }.map(Photo.init),
            submitterName: card.value2.submitter?.name,
            nearby: card.value2.nearby.map {
                NearbySpot(id: $0.id, title: $0.title, kind: SpotKind($0.kind), distanceMeters: $0.distanceMeters)
            },
            spotID: submission.spotId,
            changedFields: submission.changedFields.compactMap { SpotEditField(rawValue: $0.rawValue) },
            current: card.value2.current.map {
                Snapshot(
                    title: $0.title,
                    about: $0.description,
                    kind: SpotKind($0.spotKind),
                    obstacles: $0.obstacles,
                    condition: SpotCondition($0.condition),
                    latitude: $0.latitude,
                    longitude: $0.longitude,
                    photoCount: $0.photoCount,
                    removedPhotoCount: $0.removedPhotoCount,
                )
            },
            createdAt: submission.createdAt,
            updatedAt: submission.updatedAt,
        )
    }
}

extension ReviewCard.Photo {
    init(_ photo: Components.Schemas.SubmissionPhoto) {
        let credit: PhotoCredit =
            switch photo.credit {
            case .submitter: .submitter
            case .someoneElse(let other): .someoneElse(name: other.credit, sourceURL: other.sourceUrl.flatMap(URL.init(string:)))
            }
        self.init(
            id: photo.photoId,
            key: photo.key,
            width: photo.width,
            height: photo.height,
            thumbhash: photo.thumbhash,
            credit: credit,
            isExisting: photo.existing,
            clip: photo.clip.map(SpotClip.init),
        )
    }
}

extension VideoReviewCard {
    init(_ card: Components.Schemas.VideoReviewCard) throws {
        // `allOf`: the video in `value1`, its spot and sender in `value2` (as `ReviewCard`).
        let video = card.value1
        let context = card.value2
        guard let url = URL(string: video.url) else {
            throw ReviewAPIError.rejected(ReviewKitStrings.ApiError.videoWithoutLink)
        }
        self.init(
            id: video.id,
            spotID: context.spot.id,
            spotTitle: context.spot.title,
            spotKind: SpotKind(context.spot.kind),
            cityID: context.spot.cityId,
            provider: VideoProvider(video.provider),
            url: url,
            thumbnailURL: video.thumbnailUrl.flatMap(URL.init(string:)),
            caption: video.caption,
            submitterName: context.submitter?.name,
            createdAt: video.createdAt,
            updatedAt: video.updatedAt,
        )
    }
}

extension VideoDecided {
    init(_ video: Components.Schemas.VideoSubmission) {
        self.init(id: video.id, updatedAt: video.updatedAt)
    }
}

extension Components.Schemas.VideoRejectReason {
    init(_ reason: VideoRejectReason) {
        switch reason {
        case .duplicate: self = .duplicate
        case .wrongSpot: self = .wrongSpot
        case .notSkating: self = .notSkating
        case .inappropriate: self = .inappropriate
        }
    }
}

extension ReviewDecided {
    init(_ submission: Components.Schemas.Submission) {
        self.init(
            id: submission.id,
            status: SubmissionStatus(submission.status),
            spotID: submission.spotId,
            updatedAt: submission.updatedAt,
        )
    }
}

extension Components.Schemas.SpotEdits {
    init(_ edits: SpotEdits) {
        self.init(
            title: edits.title,
            description: edits.about,
            spotKind: edits.kind.map(Components.Schemas.SpotKind.init),
            obstacles: edits.obstacles,
            condition: edits.condition.map(Components.Schemas.SpotCondition.init),
            latitude: edits.coordinate?.latitude,
            longitude: edits.coordinate?.longitude,
            photoIds: edits.photoIDs,
        )
    }
}

extension Components.Schemas.RejectReason {
    init(_ reason: RejectReason) {
        switch reason {
        case .duplicate: self = .duplicate
        case .notASpot: self = .notASpot
        case .wrongLocation: self = .wrongLocation
        case .privateProperty: self = .privateProperty
        case .photoRights: self = .photoRights
        }
    }
}
