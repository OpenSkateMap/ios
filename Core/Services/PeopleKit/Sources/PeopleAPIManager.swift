public import APIClientKit
import Foundation
public import OpenAPIRuntime

// MARK: - PeopleAPIManager

public struct PeopleAPIManager: Sendable {
    public var profile: @Sendable (_ userID: String) async throws -> PublicProfile
    public var updateMyProfile: @Sendable (_ update: ProfileUpdate) async throws -> PublicProfile
    public var blockedUsers: @Sendable () async throws -> [BlockedUser]
    public var setBlocked: @Sendable (_ userID: String, _ blocked: Bool) async throws -> Void
    public var report: @Sendable (_ report: Report) async throws -> Void

    public init(profile: @escaping @Sendable (_ userID: String) async throws -> PublicProfile,
                updateMyProfile: @escaping @Sendable (_ update: ProfileUpdate) async throws -> PublicProfile,
                blockedUsers: @escaping @Sendable () async throws -> [BlockedUser],
                setBlocked: @escaping @Sendable (_ userID: String, _ blocked: Bool) async throws -> Void,
                report: @escaping @Sendable (_ report: Report) async throws -> Void) {
        self.profile = profile
        self.updateMyProfile = updateMyProfile
        self.blockedUsers = blockedUsers
        self.setBlocked = setBlocked
        self.report = report
    }
}

extension PeopleAPIManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> PeopleAPIManager {
        PeopleAPIManager(
            profile: { userID in
                try await PublicProfile(authorized(credentials, makeClient) {
                    try await $0.getUserProfile(path: .init(userId: userID)).ok.body.json.data
                })
            },
            updateMyProfile: { update in
                // The one conflict a profile save meets is a username someone else has.
                try await PublicProfile(authorized(credentials, makeClient, failure: { failure in
                    failure.status == 409 ? PeopleAPIError.usernameUnavailable : PeopleAPIError(failure)
                }) {
                    try await $0.updateMyProfile(body: .json(Components.Schemas.ProfileUpdate(update))).ok.body.json.data
                })
            },
            blockedUsers: {
                try await authorized(credentials, makeClient) { try await $0.listBlockedUsers().ok.body.json.data }.users.map {
                    BlockedUser(id: $0.id, name: $0.name, username: $0.username, blockedAt: $0.blockedAt)
                }
            },
            setBlocked: { userID, blocked in
                if blocked {
                    _ = try await authorized(credentials, makeClient) { try await $0.blockUser(path: .init(userId: userID)).ok }
                } else {
                    _ = try await authorized(credentials, makeClient) { try await $0.unblockUser(path: .init(userId: userID)).ok }
                }
            },
            report: { report in
                _ = try await authorized(credentials, makeClient) {
                    try await $0.createReport(body: .json(Components.Schemas.ReportInput(report))).ok
                }
            },
        )
    }

    public static let preview: PeopleAPIManager = {
        let joined = Date(timeIntervalSince1970: 1_791_590_400)
        return PeopleAPIManager(
            profile: { PublicProfile(id: $0, name: "Preview Skater", username: "preview", joinedAt: joined) },
            updateMyProfile: { update in
                PublicProfile(id: "preview", name: update.name ?? "Preview Skater", username: update.username, joinedAt: joined)
            },
            blockedUsers: { [] },
            setBlocked: { _, _ in },
            report: { _ in },
        )
    }()
}

// MARK: - Calls

private func authorized<Output>(_ credentials: SessionCredentials,
                                _ makeClient: @Sendable ([any ClientMiddleware]) -> Client,
                                failure: (APIFailure) -> any Error = PeopleAPIError.init,
                                _ call: (Client) async throws -> Output) async throws -> Output {
    try await credentials.authorized(
        makeClient,
        signedOut: PeopleAPIError.unauthorized,
        offline: PeopleAPIError.offline,
        failure: failure,
        call,
    )
}

extension PeopleAPIError {
    init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 404: self = .notFound
        case 403, 409, 422: self = .rejected(failure.message ?? PeopleKitStrings.ApiError.refused(failure.status))
        case 429, 500...: self = .unavailable
        default: self = .rejected(PeopleKitStrings.ApiError.refused(failure.status))
        }
    }
}

// MARK: - Mapping

extension PublicProfile {
    init(_ profile: Components.Schemas.PublicProfile) {
        let role: Role =
            switch profile.role {
            case .user: .user
            case .editor: .editor
            case .admin: .admin
            }
        let handles = profile.handles
        self.init(
            id: profile.id,
            name: profile.name,
            username: profile.username,
            bio: profile.bio,
            avatar: profile.avatar.map { Avatar(key: $0.key, thumbhash: $0.thumbhash) },
            handles: Handles([
                .instagram: handles.instagram ?? "",
                .tiktok: handles.tiktok ?? "",
                .youtube: handles.youtube ?? "",
                .x: handles.x ?? "",
                .telegram: handles.telegram ?? "",
                .website: handles.website ?? "",
            ]),
            role: role,
            editorOf: profile.editorOf.map { City(id: $0.id, name: $0.name) },
            stats: Stats(submitted: profile.stats.submitted, approved: profile.stats.approved, cities: profile.stats.cities),
            joinedAt: profile.joinedAt,
            blockedByMe: profile.blockedByMe,
        )
    }
}

extension Components.Schemas.ProfileUpdate {
    init(_ update: ProfileUpdate) {
        let handles = update.handles
        self.init(
            name: update.name,
            username: update.username,
            bio: update.bio,
            avatar: update.avatar.map { AvatarPayload(photoId: $0.photoID, thumbhash: $0.thumbhash) },
            handles: handles.isEmpty
                ? nil
                : HandlesPayload(
                    instagram: handles[.instagram],
                    tiktok: handles[.tiktok],
                    youtube: handles[.youtube],
                    x: handles[.x],
                    telegram: handles[.telegram],
                    website: handles[.website],
                ),
            clear: update.clear.isEmpty ? nil : update.clear.map(Components.Schemas.ClearableProfileField.init),
        )
    }
}

extension Components.Schemas.ClearableProfileField {
    init(_ field: ProfileUpdate.Field) {
        switch field {
        case .username: self = .username
        case .bio: self = .bio
        case .avatar: self = .avatar
        case .instagram: self = .instagram
        case .tiktok: self = .tiktok
        case .youtube: self = .youtube
        case .x: self = .x
        case .telegram: self = .telegram
        case .website: self = .website
        }
    }
}

extension Components.Schemas.ReportReason {
    init(_ reason: Report.Reason) {
        switch reason {
        case .inappropriate: self = .inappropriate
        case .spam: self = .spam
        case .wrongInfo: self = .wrongInfo
        case .privateProperty: self = .privateProperty
        case .photoRights: self = .photoRights
        case .harassment: self = .harassment
        case .other: self = .other
        }
    }
}

extension Components.Schemas.ReportInput {
    init(_ report: Report) {
        let target: (TargetKindPayload, String) =
            switch report.target {
            case .spot(let id): (.spot, id)
            case .user(let id): (.user, id)
            }
        let message = report.message.trimmingCharacters(in: .whitespacesAndNewlines)
        self.init(
            targetKind: target.0,
            targetId: target.1,
            reason: Components.Schemas.ReportReason(report.reason),
            message: message.isEmpty ? nil : message,
        )
    }
}
