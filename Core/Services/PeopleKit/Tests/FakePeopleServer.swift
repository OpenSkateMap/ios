import Foundation
import PhotoUploadKit
import Synchronization
@testable import PeopleKit

// MARK: - FakePeopleServer

final class FakePeopleServer: Sendable {

    // MARK: Types

    struct State {
        var profiles = [String: PublicProfile]()
        var blocked = [BlockedUser]()
        var reports = [Report]()
        var calls = [String]()
        var failNext: (call: String, error: any Error & Sendable)?
    }

    // MARK: Static Properties

    static let me = "me"

    // MARK: Computed Properties

    var calls: [String] {
        state.withLock(\.calls)
    }

    var reports: [Report] {
        state.withLock(\.reports)
    }

    var api: PeopleAPIManager {
        PeopleAPIManager(
            profile: { [self] id in
                try record("profile \(id)") { state in
                    guard let profile = state.profiles[id] else {
                        throw PeopleAPIError.notFound
                    }
                    return profile
                }
            },
            updateMyProfile: { [self] update in
                try record("patch \(Self.describe(update))") { state in
                    guard var profile = state.profiles[Self.me] else {
                        throw PeopleAPIError.notFound
                    }
                    if let name = update.name {
                        profile.name = name
                    }
                    if let username = update.username {
                        profile.username = username
                    }
                    if let bio = update.bio {
                        profile.bio = bio
                    }
                    if let avatar = update.avatar {
                        profile.avatar = .init(
                            key: "photos/\(avatar.photoID).jpg",
                            thumbhash: avatar.thumbhash,
                        )
                    }
                    for (network, value) in update.handles { profile.handles[network] = value }
                    for field in update.clear {
                        switch field {
                        case .username: profile.username = nil
                        case .bio: profile.bio = ""
                        case .avatar: profile.avatar = nil
                        case .instagram: profile.handles[.instagram] = nil
                        case .tiktok: profile.handles[.tiktok] = nil
                        case .youtube: profile.handles[.youtube] = nil
                        case .x: profile.handles[.x] = nil
                        case .telegram: profile.handles[.telegram] = nil
                        case .website: profile.handles[.website] = nil
                        }
                    }
                    state.profiles[Self.me] = profile
                    return profile
                }
            },
            blockedUsers: { [self] in
                try record("blocks") { $0.blocked }
            },
            setBlocked: { [self] id, blocked in
                try record("\(blocked ? "block" : "unblock") \(id)") { state in
                    guard let profile = state.profiles[id] else {
                        throw PeopleAPIError.notFound
                    }
                    state.blocked.removeAll { $0.id == id }
                    if blocked {
                        state.blocked.insert(
                            BlockedUser(id: id, name: profile.name, username: profile.username, blockedAt: .now),
                            at: 0,
                        )
                    }
                }
            },
            report: { [self] report in
                try record("report") { $0.reports.append(report) }
            },
        )
    }

    var photos: PhotoUploadManager {
        PhotoUploadManager(
            prepare: { data in PreparedPhoto(jpeg: data, width: 64, height: 64, thumbhash: "1QcSHQRnh493V4dIh4eXh1h4kJUI") },
            upload: { [self] id, _ in
                try record("upload \(id)") { _ in }
            },
        )
    }

    // MARK: Properties

    private let state = Mutex(State())

    // MARK: Lifecycle

    init(profiles: [PublicProfile]) {
        state.withLock { state in
            for profile in profiles {
                state.profiles[profile.id] = profile
            }
        }
    }

    // MARK: Static Functions

    private static func describe(_ update: ProfileUpdate) -> String {
        var parts = [String]()
        if let name = update.name {
            parts.append("name=\(name)")
        }
        if let username = update.username {
            parts.append("username=\(username)")
        }
        if let bio = update.bio {
            parts.append("bio=\(bio)")
        }
        if let avatar = update.avatar {
            parts.append("avatar=\(avatar.photoID)")
        }
        for network in HandleNetwork.allCases {
            if let value = update.handles[network] {
                parts.append("\(network.rawValue)=\(value)")
            }
        }
        if !update.clear.isEmpty {
            parts.append("clear=\(update.clear.map(\.rawValue).joined(separator: ","))")
        }
        return parts.joined(separator: " ")
    }

    // MARK: Functions

    func failNext(_ error: any Error & Sendable, on call: String = "") {
        state.withLock { $0.failNext = (call, error) }
    }

    private func record<T>(_ call: String, _ body: (inout State) throws -> T) throws -> T {
        try state.withLock { state in
            state.calls.append(call)
            if let failure = state.failNext, call.hasPrefix(failure.call) {
                state.failNext = nil
                throw failure.error
            }
            return try body(&state)
        }
    }
}

extension PublicProfile {
    static func fixture(_ id: String = FakePeopleServer.me,
                        name: String = "Rider",
                        username: String? = nil,
                        bio: String = "",
                        handles: Handles = Handles(),
                        avatar: Avatar? = nil) -> PublicProfile {
        PublicProfile(
            id: id,
            name: name,
            username: username,
            bio: bio,
            avatar: avatar,
            handles: handles,
            joinedAt: Date(timeIntervalSince1970: 1_791_590_400),
        )
    }
}
