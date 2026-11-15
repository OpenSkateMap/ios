import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Synchronization
import Testing
@testable import PeopleKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ProfileSessionTests {
    private let database: any DatabaseWriter
    private let store: PeopleStore

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.people])
        store = PeopleStore(database: database, now: { Date(timeIntervalSince1970: 1_791_676_800) })
    }

    @Test
    func `saving sends only what changed, with emptied fields as clears`() async throws {
        let saved = PublicProfile.fixture(username: "rider", bio: "Ledges.", handles: Handles([.instagram: "rider_ig"]))
        let server = FakePeopleServer(profiles: [saved])
        let session = session(server)
        var draft = ProfileDraft(saved)
        draft.bio = ""
        draft.handles[.instagram] = ""
        draft.handles[.telegram] = "@rider_tg"

        let result = try await session.save(draft, over: saved)

        expectNoDifference(server.calls, ["patch telegram=rider_tg clear=bio,instagram"])
        expectNoDifference(result.handles, Handles([.telegram: "rider_tg"]))
        expectNoDifference(result.bio, "")
        let value1 = try await cached(saved.id)
        expectNoDifference(value1, result)
    }

    @Test
    func `a new avatar is uploaded before the profile is patched`() async throws {
        let saved = PublicProfile.fixture()
        let server = FakePeopleServer(profiles: [saved])
        let session = session(server)
        var draft = ProfileDraft(saved)
        draft.avatar = try await .replaced(session.prepareAvatar(Data([1, 2, 3])))

        let result = try await session.save(draft, over: saved)

        expectNoDifference(server.calls, ["upload photo-1", "patch avatar=photo-1"])
        expectNoDifference(result.avatar?.key, "photos/photo-1.jpg")
    }

    @Test
    func `a taken username keeps the saved profile, and the retry doesn't upload the avatar again`() async throws {
        let saved = PublicProfile.fixture(username: "rider")
        let server = FakePeopleServer(profiles: [saved])
        let session = session(server)
        var draft = ProfileDraft(saved)
        draft.username = "taken"
        draft.avatar = try await .replaced(session.prepareAvatar(Data([1, 2, 3])))
        server.failNext(PeopleAPIError.usernameUnavailable, on: "patch")

        await #expect(throws: PeopleAPIError.usernameUnavailable) {
            try await session.save(draft, over: saved)
        }
        let value2 = try await cached(saved.id)
        expectNoDifference(value2, nil)

        draft.username = "free"
        let result = try await session.save(draft, over: saved)

        expectNoDifference(server.calls, [
            "upload photo-1",
            "patch username=taken avatar=photo-1",
            "patch username=free avatar=photo-1",
        ])
        expectNoDifference(result.username, "free")
    }

    @Test
    func `blocking marks the profile, adds them to the list and tells the app`() async throws {
        let other = PublicProfile.fixture("other", name: "Other", username: "other")
        let server = FakePeopleServer(profiles: [.fixture(), other])
        let changes = Mutex(0)
        let session = session(server, blocksChanged: BlocksChangedHandler { changes.withLock { $0 += 1 } })
        try await session.loadBlockedUsers()
        try await session.load("other")

        try await session.setBlocked("other", true)

        let value3 = try await cached("other")?.blockedByMe
        expectNoDifference(value3, true)
        let value4 = try await blocked().users.map(\.id)
        expectNoDifference(value4, ["other"])
        expectNoDifference(changes.withLock(\.self), 1)

        try await session.setBlocked("other", false)

        let value5 = try await cached("other")?.blockedByMe
        expectNoDifference(value5, false)
        let value6 = try await blocked().users.map(\.id)
        expectNoDifference(value6, [])
        expectNoDifference(server.calls, ["blocks", "profile other", "block other", "unblock other"])
        expectNoDifference(changes.withLock(\.self), 2)
    }

    @Test
    func `a failed block changes nothing and tells no one`() async throws {
        let server = FakePeopleServer(profiles: [.fixture(), .fixture("other")])
        let changes = Mutex(0)
        let session = session(server, blocksChanged: BlocksChangedHandler { changes.withLock { $0 += 1 } })
        try await session.load("other")
        server.failNext(PeopleAPIError.offline)

        await #expect(throws: PeopleAPIError.offline) {
            try await session.setBlocked("other", true)
        }
        let value7 = try await cached("other")?.blockedByMe
        expectNoDifference(value7, false)
        expectNoDifference(changes.withLock(\.self), 0)
    }

    @Test
    func `a profile that's no longer available is forgotten`() async throws {
        let server = FakePeopleServer(profiles: [.fixture("other")])
        let session = session(server)
        try await session.load("other")
        server.failNext(PeopleAPIError.notFound)

        await #expect(throws: PeopleAPIError.notFound) {
            try await session.load("other")
        }
        let value8 = try await cached("other")
        expectNoDifference(value8, nil)
    }

    @Test
    func `a report goes to the server as written`() async throws {
        let server = FakePeopleServer(profiles: [])
        let session = session(server)

        try await session.report(Report(target: .spot(id: "s1"), reason: .privateProperty, message: "Backyard"))

        expectNoDifference(server.reports, [Report(target: .spot(id: "s1"), reason: .privateProperty, message: "Backyard")])
    }

    @Test
    func `a failed refresh keeps the cached profile`() async throws {
        let other = PublicProfile.fixture("other", name: "Other", username: "other")
        let server = FakePeopleServer(profiles: [other])
        let session = session(server)
        try await session.load("other")
        server.failNext(PeopleAPIError.offline)

        await #expect(throws: PeopleAPIError.offline) {
            try await session.load("other")
        }
        let value9 = try await cached("other")
        expectNoDifference(value9, other)
    }

    @Test
    func `profiles are cached per account`() async throws {
        let server = FakePeopleServer(profiles: [.fixture("other")])
        try await session(server, account: "first").load("other")

        let value10 = try await cached("other", account: "first")?.id
        expectNoDifference(value10, "other")
        let value11 = try await cached("other", account: "second")
        expectNoDifference(value11, nil)
    }

    @Test
    func `the blocked list tells "no one" apart from "not loaded yet"`() async throws {
        let server = FakePeopleServer(profiles: [.fixture()])
        let session = session(server)
        let value12 = try await blocked()
        expectNoDifference(value12, BlockedUsers(users: [], isLoaded: false))

        try await session.loadBlockedUsers()

        let value13 = try await blocked()
        expectNoDifference(value13, BlockedUsers(users: [], isLoaded: true))
    }

    @Test
    func `an answer from before the account ended isn't cached, and the end clears everything`() async throws {
        let server = FakePeopleServer(profiles: [.fixture(), .fixture("other")])
        let session = session(server)
        try await session.load("other")
        try await session.loadBlockedUsers()
        let before = await store.generation

        await store.reset()
        await store.save(.fixture("late"), for: FakePeopleServer.me, from: before)

        let value14 = try await cached("other")
        expectNoDifference(value14, nil)
        let value15 = try await cached("late")
        expectNoDifference(value15, nil)
        let value16 = try await blocked()
        expectNoDifference(value16, BlockedUsers(users: [], isLoaded: false))
    }

    private func session(_ server: FakePeopleServer,
                         account: String = FakePeopleServer.me,
                         blocksChanged: BlocksChangedHandler = .none) -> ProfileSession {
        let ids = Mutex(0)
        return ProfileSession(
            api: server.api,
            photos: server.photos,
            store: store,
            viewerID: { account },
            blocksChanged: blocksChanged,
        ) {
            ids.withLock { id in
                id += 1
                return "photo-\(id)"
            }
        }
    }

    private func cached(_ personID: String, account: String = FakePeopleServer.me) async throws -> PublicProfile? {
        try await database.read { try ProfileRequest(personID: personID, account: account).fetch($0) }
    }

    private func blocked(account: String = FakePeopleServer.me) async throws -> BlockedUsers {
        try await database.read { try BlockedUsersRequest(account: account).fetch($0) }
    }

}
