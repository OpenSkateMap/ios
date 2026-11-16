import CollectionsKit
import ComponentKit
import CustomDump
import FactoryKit
import Foundation
import ImageKit
import SnapshotTesting
import SpotModelKit
import SpotsKit
import SQLiteData
import SQLiteKit
import Testing
import UIKit
@testable import CollectionDetailKit

// MARK: - CollectionSnapshotTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct CollectionSnapshotTests {

    // MARK: Static Properties

    private static let date = Date(timeIntervalSince1970: 1_791_590_400)
    private static let thumbhash = "1QcSHQRnh493V4dIh4eXh1h4kJUI"

    private static let spots = [
        SpotIndex(
            id: "s1",
            title: "Southbank Undercroft",
            kind: .plaza,
            condition: .skateable,
            cityID: nil,
            latitude: 51.506,
            longitude: -0.116,
            version: 1,
            coverThumbhash: thumbhash,
        ),
        SpotIndex(
            id: "s2",
            title: "Garage Ledge",
            kind: .diy,
            condition: .skateable,
            cityID: nil,
            latitude: 51.52,
            longitude: -0.1,
            version: 2,
            isPrivate: true,
        ),
        SpotIndex(
            id: "s3",
            title: "Stockwell Skatepark",
            kind: .park,
            condition: .skateable,
            cityID: nil,
            latitude: 51.47,
            longitude: -0.12,
            version: 3,
        ),
    ]

    private static let collections = [
        collection(
            "favorites",
            "Favorites",
            .private,
            .owner,
            members: 0,
            kind: .favorites,
            look: CollectionLook(color: .amber),
            position: 0,
        ),
        collection(
            "night",
            "Night Sessions",
            .private,
            .owner,
            members: 2,
            look: CollectionLook(color: .violet),
            position: 1,
        ),
        collection("london", "London Lines", .public, .owner, members: 0, look: CollectionLook(color: .sky), position: 2),
        collection(
            "crew",
            "Crew DIYs",
            .private,
            .viewer,
            members: 4,
            owner: "Ana",
            look: CollectionLook(color: .coral),
            position: 3,
        ),
    ]

    private static let entries = [
        SpotCollectionEntry(collectionID: "night", spotID: "s2", position: 0),
        SpotCollectionEntry(collectionID: "night", spotID: "s1", position: 1),
        SpotCollectionEntry(collectionID: "london", spotID: "s1", position: 0),
        SpotCollectionEntry(collectionID: "london", spotID: "s3", position: 1),
        SpotCollectionEntry(collectionID: "crew", spotID: "s3", position: 0),
    ]

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Static Functions

    private static func collection(_ id: String,
                                   _ name: String,
                                   _ visibility: CollectionVisibility,
                                   _ role: CollectionRole,
                                   members: Int,
                                   owner: String = "Local Rider",
                                   kind: CollectionKind = .custom,
                                   look: CollectionLook,
                                   position: Int) -> SpotCollection {
        SpotCollection(
            id: id,
            name: name,
            about: id == "night" ? "Lit spots for after dark, with security that doesn't mind." : "",
            visibility: visibility,
            kind: kind,
            look: look,
            role: role,
            ownerID: role == .owner ? "rider" : "ana",
            ownerName: owner,
            ownerUsername: role == .owner ? "local_rider" : "ana",
            memberCount: members,
            coverKey: nil,
            coverThumbhash: id == "london" ? thumbhash : nil,
            position: position,
            createdAt: date,
            updatedAt: date,
        )
    }

    private static func image(_ direction: UITraitEnvironmentLayoutDirection = .leftToRight)
        -> Snapshotting<UIViewController, UIImage> {
        let traits = UITraitCollection {
            $0.displayScale = 1
            $0.layoutDirection = direction
        }
        return .image(on: .iPhone13Pro, precision: 0.995, perceptualPrecision: 0.98, traits: traits)
    }

    private static func navigation(_ root: UIViewController) -> UINavigationController {
        UINavigationController(rootViewController: root)
    }

    private static func invitation(_ id: String, position: Int) -> CollectionInvitation {
        CollectionInvitation(
            collectionID: id,
            name: id.capitalized,
            ownerID: "owner",
            ownerName: "Local Rider",
            ownerUsername: "rider",
            role: .editor,
            inviterName: nil,
            position: position,
            createdAt: Date(timeIntervalSince1970: 0),
        )
    }

    private static func person(_ id: String) -> CollectionAccess.Person {
        CollectionAccess.Person(id: id, name: id.capitalized, username: id, avatarKey: nil, avatarThumbhash: nil)
    }

    private static func accessModel() -> CollectionAccessModel {
        CollectionAccessModel(
            collectionID: "night",
            role: .owner,
            draft: CollectionDraft(name: "Night Sessions", visibility: .private),
            privateSpotCount: 0,
        )
    }

    nonisolated private static func remoteCollection(_ id: String, spots: [String]) -> RemoteCollection {
        RemoteCollection(
            id: id,
            name: "Far Away",
            about: "",
            visibility: .public,
            look: CollectionLook(color: .sky),
            role: .guest,
            ownerID: "ana",
            ownerName: "Ana",
            ownerUsername: "ana",
            spotIDs: spots,
            memberCount: 0,
            coverKey: nil,
            coverThumbhash: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
        )
    }

    nonisolated private static func remoteSpot(_ id: String) -> SpotIndex {
        SpotIndex(
            id: id,
            title: "Spot \(id)",
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: 41.38,
            longitude: 2.17,
            version: 1,
        )
    }

    // MARK: Functions

    @Test(.tags(.snapshot))
    func `invitations, your collections, then the ones shared with you`() async throws {
        try await withEnvironment(invitations: [Self.invitation("downtown ledges", position: 0)]) {
            assertSnapshot(of: Self.navigation(CollectionScreens.list()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `no collections yet`() async throws {
        try await withEnvironment(
            seeded: false,
            api: { $0.snapshot = { CollectionsSnapshot(collections: [], privateSpots: []) } },
        ) {
            await Container.shared.collectionsSession().syncNow()
            assertSnapshot(of: Self.navigation(CollectionScreens.list()), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `an empty collection says how to add spots`() async throws {
        try await withEnvironment {
            let navigation = Self.navigation(CollectionViewController(id: "favorites"))
            navigation.navigationBar.prefersLargeTitles = true
            assertSnapshot(of: navigation, as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `a collection with a private spot`() async throws {
        try await withEnvironment {
            let navigation = Self.navigation(CollectionViewController(id: "night"))
            navigation.navigationBar.prefersLargeTitles = true
            assertSnapshot(of: navigation, as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `a collection right to left, its hero unmirrored`() async throws {
        try await withEnvironment {
            let navigation = Self.navigation(CollectionViewController(id: "night"))
            navigation.navigationBar.prefersLargeTitles = true
            assertSnapshot(of: navigation, as: Self.image(.rightToLeft))
        }
    }

    @Test(.tags(.snapshot))
    func `save to collection, with the spot in one of them`() async throws {
        try await withEnvironment {
            // The sheet alone: with its Done button, inside a navigation controller this hostless render draws nothing.
            assertSnapshot(of: CollectionPickerViewController(spotID: "s1"), as: Self.image())
        }
    }

    @Test(.tags(.snapshot))
    func `share sheet with people and an invite`() async throws {
        let person = { (id: String, name: String, username: String?) in
            CollectionAccess.Person(id: id, name: name, username: username, avatarKey: nil, avatarThumbhash: nil)
        }
        let access = CollectionAccess(
            visibility: .private,
            owner: person("rider", "Local Rider", "local_rider"),
            members: [
                .init(person: person("ana", "Ana", "ana"), role: .admin, addedAt: Self.date),
                .init(person: person("tom", "Tom Penny", nil), role: .viewer, addedAt: Self.date),
            ],
            invites: [
                .init(id: "i1", email: "friend@example.com", person: nil, role: .viewer, createdAt: Self.date),
                .init(id: "i2", email: nil, person: person("kai", "Kai", "kai"), role: .editor, createdAt: Self.date),
            ],
            requests: [.init(person: person("sam", "Sam", "sam"), createdAt: Self.date)],
        )
        try await withEnvironment(access: access) {
            let model = CollectionAccessModel(
                collectionID: "night",
                role: .owner,
                draft: CollectionDraft(name: "Night Sessions", visibility: .private),
                privateSpotCount: 1,
            )
            await model.load()
            assertSnapshot(of: CollectionAccessViewController(model: model), as: Self.image())
        }
    }

    @Test
    func `collections you edit or run are listed as shared with you`() async throws {
        let collections = [
            Self.collection("mine", "Mine", .private, .owner, members: 0, look: CollectionLook(color: .sky), position: 0),
            Self.collection("run", "Run", .private, .admin, members: 3, look: CollectionLook(color: .sky), position: 1),
            Self.collection("edit", "Edit", .private, .editor, members: 2, look: CollectionLook(color: .sky), position: 2),
            Self.collection("view", "View", .private, .viewer, members: 1, look: CollectionLook(color: .sky), position: 3),
        ]
        try await withEnvironment(collections: collections, entries: []) {
            let model = CollectionsListModel(source: .mine)

            expectNoDifference(model.own.map(\.id), ["mine"])
            expectNoDifference(model.shared.map(\.id), ["run", "edit", "view"])
            expectNoDifference(model.shared.map(\.subtitle), Array(repeating: "Shared by Local Rider · 0 spots", count: 3))
        }
    }

    @Test
    func `invitations are listed in order`() async throws {
        let invitations = [Self.invitation("later", position: 1), Self.invitation("first", position: 0)]
        try await withEnvironment(collections: [], entries: [], invitations: invitations) {
            let model = CollectionsListModel(source: .mine)

            expectNoDifference(model.invitations.map(\.id), ["first", "later"])
            expectNoDifference(model.invitations.map(\.detail), Array(repeating: "@rider invited you as Editor", count: 2))
        }
    }

    @Test
    func `a collection fetched online asks for each next page once`() async throws {
        let (asked, ask) = AsyncStream.makeStream(of: String.self)
        try await withEnvironment(seeded: false, api: { api in
            api.page = { id in
                CollectionPage(
                    collection: Self.remoteCollection(id, spots: ["a", "b"]),
                    spots: CollectionSpotsPage(spots: [Self.remoteSpot("a")], nextCursor: "after-a"),
                )
            }
            api.spots = { _, cursor in
                ask.yield(cursor)
                return CollectionSpotsPage(spots: [Self.remoteSpot("b")], nextCursor: nil)
            }
        }) {
            let model = CollectionModel(id: "far")
            await model.loadIfNeeded()
            async let first: Void = model.loadMoreSpots()
            async let second: Void = model.loadMoreSpots()
            _ = try await (first, second)
            try await model.loadMoreSpots()
            ask.finish()

            var cursors = [String]()
            for await cursor in asked {
                cursors.append(cursor)
            }
            expectNoDifference(cursors, ["after-a"])
            expectNoDifference(model.shown?.spots.map(\.id), ["a", "b"])
        }
    }

    @Test
    func `who sees a collection changes only once the owner confirms, either way`() {
        let goingPublic = CollectionAccessModel(
            collectionID: "night",
            role: .owner,
            draft: CollectionDraft(name: "Night Sessions", visibility: .private),
            privateSpotCount: 2,
        )
        expectNoDifference(goingPublic.confirmation(for: .public), .makePublic(privateSpotCount: 2))
        expectNoDifference(goingPublic.confirmation(for: .private), nil)

        let goingPrivate = CollectionAccessModel(
            collectionID: "night",
            role: .owner,
            draft: CollectionDraft(name: "Night Sessions", visibility: .public),
            privateSpotCount: 0,
        )
        expectNoDifference(goingPrivate.confirmation(for: .private), .makePrivate)
        expectNoDifference(goingPrivate.confirmation(for: .public), nil)
    }

    @Test
    func `a visibility change shows as in progress until the server answers`() async throws {
        let (started, start) = AsyncStream.makeStream(of: Void.self)
        let (answer, release) = AsyncStream.makeStream(of: Void.self)
        let person = CollectionAccess.Person(id: "rider", name: "Rider", username: nil, avatarKey: nil, avatarThumbhash: nil)
        let access = CollectionAccess(visibility: .public, owner: person, members: [], invites: [], requests: [])
        try await withEnvironment(api: { api in
            api.save = { id, _, _ in
                start.yield()
                for await _ in answer {
                    break
                }
                return Self.remoteCollection(id, spots: [])
            }
        }, access: access) {
            let model = CollectionAccessModel(
                collectionID: "night",
                role: .owner,
                draft: CollectionDraft(name: "Night Sessions", visibility: .private),
                privateSpotCount: 0,
            )
            async let confirmed: Void = model.confirm(.makePublic(privateSpotCount: 0))
            for await _ in started {
                break
            }
            expectNoDifference(model.changingVisibility, .public)
            expectNoDifference(model.confirmation(for: .public), nil)
            release.yield()
            try await confirmed
            expectNoDifference(model.changingVisibility, nil)
            expectNoDifference(model.draft.visibility, .public)
        }
    }

    @Test
    func `a private collection offers its link once someone is in it or invited`() async throws {
        let person = CollectionAccess.Person(id: "ana", name: "Ana", username: "ana", avatarKey: nil, avatarThumbhash: nil)
        let member = CollectionAccess.Member(person: person, role: .viewer, addedAt: Self.date)
        let invite = CollectionAccess.Invite(
            id: "i1",
            email: "friend@example.com",
            person: nil,
            role: .viewer,
            createdAt: Self.date,
        )
        let cases: [(CollectionVisibility, [CollectionAccess.Member], [CollectionAccess.Invite], Bool)] = [
            (.private, [], [], false),
            (.private, [], [invite], true),
            (.private, [member], [], true),
            (.public, [], [], true),
        ]
        for (visibility, members, invites, showsLinks) in cases {
            let access = CollectionAccess(visibility: visibility, owner: person, members: members, invites: invites, requests: [])
            try await withEnvironment(access: access) {
                let model = CollectionAccessModel(
                    collectionID: "night",
                    role: .owner,
                    draft: CollectionDraft(name: "Night Sessions", visibility: visibility),
                    privateSpotCount: 0,
                )
                await model.load()
                expectNoDifference(model.showsLinks, showsLinks)
            }
        }
    }

    @Test
    func `the Share sheet shows the newest answer, and reads again once an older one lands late`() async throws {
        let owner = Self.person("rider")
        let member = CollectionAccess.Member(person: Self.person("ana"), role: .viewer, addedAt: Self.date)
        var promoted = member
        promoted.role = .editor
        let invite = CollectionAccess.Invite(
            id: "i1",
            email: "friend@example.com",
            person: nil,
            role: .viewer,
            createdAt: Self.date,
        )
        let opened = CollectionAccess(visibility: .private, owner: owner, members: [member], invites: [invite], requests: [])
        let promotedAnswer = CollectionAccess(
            visibility: .private,
            owner: owner,
            members: [promoted],
            invites: [invite],
            requests: [],
        )
        let cancelledAnswer = CollectionAccess(visibility: .private, owner: owner, members: [member], invites: [], requests: [])
        let latest = CollectionAccess(visibility: .private, owner: owner, members: [promoted], invites: [], requests: [])
        let reads = Counter()
        let (started, start) = AsyncStream.makeStream(of: Void.self)
        let (answer, release) = AsyncStream.makeStream(of: Void.self)
        try await withEnvironment(api: { api in
            api.access = { _ in await reads.next() == 1 ? opened : latest }
            api.setRole = { _, _, _ in
                start.yield()
                for await _ in answer {
                    break
                }
                return promotedAnswer
            }
            api.cancelInvite = { _, _ in cancelledAnswer }
        }) {
            let model = Self.accessModel()
            await model.load()
            async let promoting: Void = model.setRole(.editor, of: member)
            for await _ in started {
                break
            }
            expectNoDifference(model.changes, [.member("ana")])
            try await model.cancel(invite)
            expectNoDifference(model.phase, .loaded(cancelledAnswer))
            release.yield()
            try await promoting
            expectNoDifference(model.phase, .loaded(latest))
            expectNoDifference(model.changes, [])
        }
    }

    @Test
    func `someone removed stays removed when the read after it fails`() async throws {
        let owner = Self.person("rider")
        let member = CollectionAccess.Member(person: Self.person("ana"), role: .viewer, addedAt: Self.date)
        let opened = CollectionAccess(visibility: .private, owner: owner, members: [member], invites: [], requests: [])
        let reads = Counter()
        try await withEnvironment(api: { api in
            api.access = { _ in
                guard await reads.next() == 1 else {
                    throw CollectionsAPIError.offline
                }
                return opened
            }
            api.removeMember = { _, _ in }
        }) {
            let model = Self.accessModel()
            await model.load()
            try await model.remove(member)
            expectNoDifference(
                model.phase,
                .loaded(CollectionAccess(visibility: .private, owner: owner, members: [], invites: [], requests: [])),
            )
        }
    }

    @Test
    func `an invitation's answer goes out once and shows while it's on its way`() async throws {
        let (asked, ask) = AsyncStream.makeStream(of: String.self)
        let (answer, release) = AsyncStream.makeStream(of: Void.self)
        try await withEnvironment(invitations: [Self.invitation("downtown ledges", position: 0)], api: { api in
            api.acceptInvitation = { id in
                ask.yield(id)
                for await _ in answer {
                    break
                }
                return Self.remoteCollection(id, spots: [])
            }
        }) {
            let model = CollectionModel(id: "downtown ledges")
            async let accepting: Void = model.accept()
            var requests = asked.makeAsyncIterator()
            _ = await requests.next()
            expectNoDifference(model.action, .accept)
            try await model.accept()
            release.yield()
            try await accepting
            ask.finish()
            let more = await requests.next()
            expectNoDifference(more, nil)
            expectNoDifference(model.action, nil)
        }
    }

    @Test
    func `a failing next page is reported once until a page loads`() async throws {
        let calls = Counter()
        try await withEnvironment(seeded: false, api: { api in
            api.page = { id in
                CollectionPage(
                    collection: Self.remoteCollection(id, spots: ["a", "b", "c"]),
                    spots: CollectionSpotsPage(spots: [Self.remoteSpot("a")], nextCursor: "after-a"),
                )
            }
            api.spots = { _, _ in
                guard await calls.next() == 3 else {
                    throw CollectionsAPIError.offline
                }
                return CollectionSpotsPage(spots: [Self.remoteSpot("b")], nextCursor: "after-b")
            }
        }) {
            let model = CollectionModel(id: "far")
            await model.loadIfNeeded()
            await #expect(throws: CollectionsAPIError.offline) { try await model.loadMoreSpots() }
            try await model.loadMoreSpots()
            try await model.loadMoreSpots()
            expectNoDifference(model.shown?.spots.map(\.id), ["a", "b"])
            await #expect(throws: CollectionsAPIError.offline) { try await model.loadMoreSpots() }
        }
    }

    @Test
    func `your collections wait for the first pull when nothing is stored, and say when it failed`() async throws {
        let (pulled, pull) = AsyncStream.makeStream(of: Void.self)
        let (answer, release) = AsyncStream.makeStream(of: Void.self)
        try await withEnvironment(seeded: false, api: { api in
            api.snapshot = {
                pull.yield()
                for await _ in answer {
                    break
                }
                throw CollectionsAPIError.offline
            }
        }) {
            let model = CollectionsListModel(source: .mine)
            expectNoDifference(model.phase, .loaded)
            async let refreshed = model.refresh()
            for await _ in pulled {
                break
            }
            expectNoDifference(model.phase, .loading)
            release.yield()
            let failure = await refreshed
            expectNoDifference(failure as? CollectionsAPIError, .offline)
            expectNoDifference(model.phase, .failed)
        }
    }

    private func withEnvironment(seeded: Bool = true,
                                 collections: [SpotCollection] = Self.collections,
                                 entries: [SpotCollectionEntry] = Self.entries,
                                 invitations: [CollectionInvitation] = [],
                                 api configure: (inout CollectionsAPIManager) -> Void = { _ in },
                                 access: CollectionAccess = .preview,
                                 _ body: () async throws -> Void) async throws {
        let database = try AppDatabase.inMemory(schemas: [.spots])
        if seeded {
            let spots = Self.spots
            try await database.write { db in
                try SpotIndex.insert { spots }.execute(db)
                try SpotCollection.insert { collections }.execute(db)
                try SpotCollectionEntry.insert { entries }.execute(db)
                try CollectionInvitation.insert { invitations }.execute(db)
            }
        }
        var api = CollectionsAPIManager.preview
        api.snapshot = { throw CollectionsAPIError.offline }
        api.access = { _ in access }
        configure(&api)
        let sync = CollectionsSync(api: api, spots: SpotSyncEngine(api: .preview, database: database), database: database)

        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.database.register { database }
        container.thumbHashRenderer.register { ThumbHashRenderer() }
        container.imageLoader.register { .placeholder }
        container.collectionsSession.register { CollectionsSession(sync: sync, api: api) { "rider" } }
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await body()
        }
    }
}

// MARK: - Counter

private actor Counter {

    // MARK: Properties

    private var count = 0

    // MARK: Functions

    func next() -> Int {
        count += 1
        return count
    }
}
