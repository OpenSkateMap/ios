public import APIClientKit
import Foundation
public import OpenAPIRuntime
public import SpotModelKit

// MARK: - SpotsAPIManager

public struct SpotsAPIManager: Sendable {
    public var syncPage: @Sendable (_ cursor: Int, _ limit: Int) async throws -> SyncPage
    public var details: @Sendable (_ ids: [String]) async throws -> SpotDetailsPage
    public var cities: @Sendable () async throws -> [City]
    public var vote: @Sendable (_ vote: SpotVote, _ spotID: String) async throws -> SpotVoteTotals
    public var scores: @Sendable () async throws -> [SpotScore]
    public var takeDown: @Sendable (_ spotID: String, _ reason: SpotRemovalReason) async throws -> Void
    public var restore: @Sendable (_ spotID: String) async throws -> Void

    public init(syncPage: @escaping @Sendable (_ cursor: Int, _ limit: Int) async throws -> SyncPage,
                details: @escaping @Sendable (_ ids: [String]) async throws -> SpotDetailsPage,
                cities: @escaping @Sendable () async throws -> [City],
                vote: @escaping @Sendable (_ vote: SpotVote, _ spotID: String) async throws -> SpotVoteTotals,
                scores: @escaping @Sendable () async throws -> [SpotScore] = { [] },
                takeDown: @escaping @Sendable (_ spotID: String, _ reason: SpotRemovalReason) async throws -> Void = { _, _ in },
                restore: @escaping @Sendable (_ spotID: String) async throws -> Void = { _ in }) {
        self.syncPage = syncPage
        self.details = details
        self.cities = cities
        self.vote = vote
        self.scores = scores
        self.takeDown = takeDown
        self.restore = restore
    }
}

extension SpotsAPIManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> SpotsAPIManager {
        @Sendable
        func authorized<Output>(_ call: (Client) async throws -> Output) async throws -> Output {
            try await credentials.authorized(
                makeClient,
                signedOut: SpotsAPIError.unauthorized,
                offline: SpotsAPIError.offline,
                failure: SpotsAPIError.init,
                call,
            )
        }

        return SpotsAPIManager(
            syncPage: { cursor, limit in
                try await SyncPage(authorized {
                    try await $0.syncSpots(query: .init(cursor: cursor, limit: limit)).ok.body.json.data
                })
            },
            details: { ids in
                try await SpotDetailsPage(authorized {
                    try await $0.getSpots(query: .init(ids: ids.joined(separator: ","))).ok.body.json.data
                })
            },
            cities: {
                try await authorized { try await $0.getCities().ok.body.json.data }.cities.map(City.init)
            },
            vote: { vote, spotID in
                try await SpotVoteTotals(authorized {
                    try await $0.voteOnSpot(path: .init(spotId: spotID), body: .json(.init(value: vote.rawValue))).ok.body.json
                        .data
                })
            },
            scores: {
                try await authorized { try await $0.getSpotScores().ok.body.json.data }.items.map {
                    SpotScore(id: $0.spotId, up: $0.up, down: $0.down, score: $0.score)
                }
            },
            takeDown: { spotID, reason in
                _ = try await authorized {
                    try await $0.takeDownSpot(path: .init(spotId: spotID), body: .json(.init(reason: .init(reason)))).ok.body.json
                        .data
                }
            },
            restore: { spotID in
                _ = try await authorized { try await $0.restoreSpot(path: .init(spotId: spotID)).ok.body.json.data }
            },
        )
    }

    public static let preview = SpotsAPIManager(
        syncPage: { cursor, _ in SyncPage(items: [], tombstones: [], nextCursor: cursor, hasMore: false, resetRequired: false) },
        details: { ids in SpotDetailsPage(spots: [], missing: ids) },
        cities: { [] },
        vote: { vote, _ in SpotVoteTotals().voting(vote) },
    )
}

// MARK: - Mapping

extension SpotsAPIError {
    fileprivate init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 429, 500...: self = .unavailable
        default: self = .rejected
        }
    }
}

extension SyncPage {
    init(_ page: Components.Schemas.SyncPage) {
        self.init(
            items: page.items.map(SpotIndex.init),
            tombstones: page.tombstones,
            nextCursor: page.nextCursor,
            hasMore: page.hasMore,
            resetRequired: page.resetRequired,
        )
    }
}

extension SpotIndex {
    /// The one mapping of the API's index row, for the sync and for collections; whoever writes it sets the epoch and
    /// `isPrivate`.
    public init(_ row: Components.Schemas.SpotIndexRow) {
        self.init(
            id: row.id,
            title: row.title,
            kind: SpotKind(row.kind),
            condition: SpotCondition(row.condition),
            cityID: row.cityId,
            latitude: row.latitude,
            longitude: row.longitude,
            version: row.version,
            coverKey: row.cover?.key,
            coverWidth: row.cover?.width,
            coverHeight: row.cover?.height,
            coverThumbhash: row.cover?.thumbhash,
            obstacles: row.obstacles,
        )
    }
}

extension SpotDetailsPage {
    init(_ page: Components.Schemas.SpotDetails) {
        self.init(spots: page.spots.map(RemoteSpotDetail.init), missing: page.missing)
    }
}

extension RemoteSpotDetail {
    init(_ detail: Components.Schemas.SpotDetail) {
        self.init(
            id: detail.id,
            about: detail.description,
            obstacles: detail.obstacles,
            addedByID: detail.addedBy?.id,
            addedByName: detail.addedBy?.name,
            createdAt: detail.createdAt,
            version: detail.version,
            photos: detail.photos.map {
                Photo(
                    id: $0.id,
                    key: $0.key,
                    width: $0.width,
                    height: $0.height,
                    thumbhash: $0.thumbhash,
                    credit: $0.credit,
                    position: $0.position,
                    clip: $0.clip.map(SpotClip.init),
                )
            },
            videos: detail.videos.map {
                Video(
                    id: $0.id,
                    provider: VideoProvider($0.provider),
                    url: $0.url,
                    thumbnailURL: $0.thumbnailUrl,
                    caption: $0.caption,
                    addedByID: $0.addedBy?.id,
                    addedByName: $0.addedBy?.name,
                )
            },
            votes: SpotVoteTotals(detail.votes),
        )
    }
}

extension SpotVoteTotals {
    init(_ votes: Components.Schemas.SpotVotes) {
        self.init(up: votes.up, down: votes.down, mine: SpotVote(sign: votes.mine))
    }
}

extension SpotVote {
    init(sign: Int) {
        self = sign > 0 ? .up : sign < 0 ? .down : .none
    }
}

extension City {
    init(_ city: Components.Schemas.City) {
        self.init(
            id: city.id,
            slug: city.slug,
            name: city.name,
            countryCode: city.countryCode,
            minLatitude: city.bounds.minLatitude,
            minLongitude: city.bounds.minLongitude,
            maxLatitude: city.bounds.maxLatitude,
            maxLongitude: city.bounds.maxLongitude,
        )
    }
}

extension Components.Schemas.SpotRemovalReason {
    init(_ reason: SpotRemovalReason) {
        switch reason {
        case .duplicate: self = .duplicate
        case .privateProperty: self = .privateProperty
        case .unsafeOrGone: self = .unsafeOrGone
        case .notASpot: self = .notASpot
        case .other: self = .other
        }
    }
}
