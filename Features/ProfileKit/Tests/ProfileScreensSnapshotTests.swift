import AccountKit
import ComponentKit
import FactoryKit
import Foundation
import ImageKit
import PeopleKit
import PhotoUploadKit
import SnapshotTesting
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
import UIKit
@testable import ProfileKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)), .tags(.snapshot))
struct ProfileScreensSnapshotTests {

    // MARK: Static Properties

    // Relative, so the age tiles read the same any day: 100 days is always 3 months, 400 always 1 year.
    private static let joined = Date.now.addingTimeInterval(-100 * 24 * 60 * 60)
    private static let otherJoined = Date.now.addingTimeInterval(-400 * 24 * 60 * 60)
    private static let account = Account(
        id: "me",
        name: "Local Rider",
        email: "rider@example.com",
        role: .admin,
        createdAt: joined,
    )

    private static let cachedProfile = PublicProfile(
        id: "me",
        name: "Local Rider",
        username: "local_rider",
        bio: "Ledges, banks, late sessions at Southbank.",
        handles: Handles([.instagram: "local.rider"]),
        role: .admin,
        stats: PublicProfile.Stats(submitted: 3, approved: 1, cities: 1),
        joinedAt: joined,
    )

    private static let other = PublicProfile(
        id: "other",
        name: "Other Skater",
        username: "other",
        bio: "Barcelona, mostly MACBA.",
        stats: PublicProfile.Stats(submitted: 12, approved: 9, cities: 2),
        joinedAt: otherJoined,
    )

    private static var refreshedProfile: PublicProfile {
        var profile = cachedProfile
        profile.stats = PublicProfile.Stats(submitted: 4, approved: 2, cities: 1)
        profile.handles[.youtube] = "localrider"
        return profile
    }

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Static Functions

    private static func phone(_ direction: UITraitEnvironmentLayoutDirection = .leftToRight)
        -> Snapshotting<UIViewController, UIImage> {
        .image(
            on: .iPhone13Pro,
            precision: 0.995,
            perceptualPrecision: 0.98,
            traits: UITraitCollection {
                $0.displayScale = 1
                $0.preferredContentSizeCategory = .large
                $0.layoutDirection = direction
            },
        )
    }

    private static func profileTab() -> UIViewController {
        let navigation = UINavigationController(rootViewController: ProfileViewController())
        navigation.navigationBar.prefersLargeTitles = true
        return navigation
    }

    /// Unwrapped: this host draws a wrapping navigation bar blank, and skips `updateProperties()`, so it runs here.
    private static func publicProfile() -> UIViewController {
        let profile = PublicProfileViewController(userID: other.id)
        profile.loadViewIfNeeded()
        profile.updatePropertiesIfNeeded()
        return profile
    }

    // MARK: Functions

    @Test
    func `cold, the profile tab shows the account's details and dashes in the loaded layout`() async throws {
        try await withEnvironment(cached: nil, server: Self.cachedProfile) {
            assertSnapshot(of: Self.profileTab(), as: Self.phone())
        }
    }

    @Test
    func `cached, the profile tab opens on the last copy`() async throws {
        try await withEnvironment(cached: Self.cachedProfile, server: Self.refreshedProfile) {
            assertSnapshot(of: Self.profileTab(), as: Self.phone())
        }
    }

    @Test
    func `right to left, the profile card leads with the avatar on the right`() async throws {
        try await withEnvironment(cached: Self.cachedProfile, server: Self.refreshedProfile) {
            assertSnapshot(of: Self.profileTab(), as: Self.phone(.rightToLeft))
        }
    }

    @Test
    func `a refresh changes the cached profile in place`() async throws {
        try await withEnvironment(cached: Self.cachedProfile, server: Self.refreshedProfile) {
            let tab = Self.profileTab()
            try await Container.shared.profileSession().load(Self.account.id)
            // The model's key: the same shared value, read again after the refresh's write.
            try await Fetch(wrappedValue: nil, ProfileRequest(personID: Self.account.id, account: Self.account.id)).load()
            assertSnapshot(of: tab, as: Self.phone())
        }
    }

    @Test
    func `cold, a public profile shows placeholders in the loaded layout`() async throws {
        try await withEnvironment(cached: nil, server: Self.other) {
            assertSnapshot(of: Self.publicProfile(), as: Self.phone())
        }
    }

    @Test
    func `cached, a public profile opens on the last copy`() async throws {
        try await withEnvironment(cached: Self.other, server: Self.other) {
            assertSnapshot(of: Self.publicProfile(), as: Self.phone())
        }
    }

    private func withEnvironment(cached: PublicProfile?,
                                 server: PublicProfile,
                                 _ body: () async throws -> Void) async throws {
        let database = try AppDatabase.inMemory(schemas: [.people])
        let now = Self.joined
        let store = PeopleStore(database: database, now: { now })
        if let cached {
            await store.save(cached, for: Self.account.id, from: await store.generation)
        }
        let api = PeopleAPIManager(
            profile: { _ in server },
            updateMyProfile: { _ in server },
            blockedUsers: { [] },
            setBlocked: { _, _ in },
            report: { _ in },
        )

        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.database.register { database }
        // A fresh renderer: the shared one caches by hash, which would make these pixels depend on test order.
        container.thumbHashRenderer.register { ThumbHashRenderer() }
        container.authSession.register {
            AuthSession(apple: .preview, api: .preview, keychain: .preview(signedInAs: Self.account), endAccountScope: { })
        }
        container.profileSession.register {
            ProfileSession(api: api, photos: .preview, store: store, viewerID: { Self.account.id })
        }
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await body()
        }
    }
}
