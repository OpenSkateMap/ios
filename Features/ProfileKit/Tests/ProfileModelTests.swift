import AccountKit
import CustomDump
import FactoryKit
import Foundation
import PeopleKit
import PhotoUploadKit
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ProfileKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct ProfileModelTests {

    // MARK: Static Properties

    private static let account = Account(
        id: "me",
        name: "Local Rider",
        email: "rider@example.com",
        role: .user,
        createdAt: Date(timeIntervalSince1970: 1_791_590_400),
    )

    nonisolated private static let other = PublicProfile(
        id: "other",
        name: "Other Skater",
        username: "other",
        bio: "",
        stats: PublicProfile.Stats(submitted: 1, approved: 1, cities: 1),
        joinedAt: Date(timeIntervalSince1970: 1_791_590_400),
    )

    // MARK: Functions

    @Test
    func `a profile that failed keeps its message while a retry runs`() async throws {
        let (asked, ask) = AsyncStream.makeStream(of: Void.self)
        let (answers, answer) = AsyncStream.makeStream(of: Result<PublicProfile, PeopleAPIError>.self)
        try await withEnvironment(profile: { _ in
            ask.yield()
            for await result in answers {
                return try result.get()
            }
            throw PeopleAPIError.offline
        }) {
            var requests = asked.makeAsyncIterator()
            let model = PublicProfileModel(userID: Self.other.id)
            answer.yield(.failure(.offline))
            await model.load()
            _ = await requests.next()
            expectNoDifference(model.phase, .failed(PeopleAPIError.offline.message))

            async let retry: Void = model.load()
            _ = await requests.next()
            expectNoDifference(model.phase, .failed(PeopleAPIError.offline.message))
            expectNoDifference(model.isLoading, true)

            answer.yield(.success(Self.other))
            await retry
            expectNoDifference(model.phase, .loaded)
            expectNoDifference(model.isLoading, false)
        }
    }

    private func withEnvironment(profile: @escaping @Sendable (String) async throws -> PublicProfile = { _ in Self.other },
                                 _ body: () async throws -> Void) async throws {
        let database = try AppDatabase.inMemory(schemas: [.people])
        let store = PeopleStore(database: database, now: { Date(timeIntervalSince1970: 1_791_590_400) })
        let api = PeopleAPIManager(
            profile: profile,
            updateMyProfile: { _ in Self.other },
            blockedUsers: { [] },
            setBlocked: { _, _ in },
            report: { _ in },
        )

        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.database.register { database }
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
