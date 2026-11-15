import CustomDump
import Foundation
import GRDB
import SpotModelKit
import SpotsKit
import SQLiteData
import SQLiteKit
import Testing
@testable import CollectionsKit

// MARK: - CollectionsSyncTests

@Suite(.timeLimit(.minutes(1)))
struct CollectionsSyncTests {
    private static let publicSpot = SpotIndex(
        id: "public",
        title: "Undercroft",
        kind: .plaza,
        condition: .skateable,
        cityID: nil,
        latitude: 51.5,
        longitude: -0.1,
        version: 1,
    )

    private let server = FakeCollectionsServer()
    private let database: any DatabaseWriter
    private let sync: CollectionsSync

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert { Self.publicSpot }.execute(db)
        }
        let spots = SpotSyncEngine(api: .preview, database: database)
        sync = CollectionsSync(api: server.api, spots: spots, database: database)
    }

    private static func privateSpot(_ id: String, version: Int = 1) -> SpotIndex {
        SpotIndex(
            id: id,
            title: "Garage",
            kind: .diy,
            condition: .skateable,
            cityID: nil,
            latitude: 51.52,
            longitude: -0.1,
            version: version,
        )
    }

    private static func collection(_ id: String, role: CollectionRole = .owner, spots: [String]) -> RemoteCollection {
        RemoteCollection(
            id: id,
            name: "Night spots \(id)",
            about: "",
            visibility: .private,
            look: CollectionLook(color: .blue),
            role: role,
            ownerID: "owner",
            ownerName: "Owner",
            ownerUsername: nil,
            spotIDs: spots,
            memberCount: 1,
            coverKey: nil,
            coverThumbhash: nil,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0),
        )
    }

    private static func standing(of id: String, _ db: Database) throws -> String {
        switch try (CollectionInvitation.find(id).fetchOne(db), SpotCollection.find(id).fetchOne(db)) {
        case (_, .some): "joined"
        case (.some, nil): "invited"
        case (nil, nil): "neither"
        }
    }

    private static func shown(of id: String, _ db: Database) throws -> String {
        guard try SpotCollection.find(id).fetchOne(db) != nil else {
            return "no \(id)"
        }
        let listed = try SpotCollectionEntry.where { $0.collectionID.eq(id) }.select(\.spotID).fetchAll(db)
        let stored = try SpotIndex.where { $0.id.in(listed) }.fetchCount(db)
        return "\(id) shows \(stored) of \(listed.count)"
    }

    @Test
    func `a pull stores the collections, their spots and the private spots`() async throws {
        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1", "public"]), Self.collection("b", role: .viewer, spots: ["p2"])],
            privateSpots: [Self.privateSpot("p1"), Self.privateSpot("p2")],
        ))

        #expect(await sync.pull() == .synced)

        let state = try stored()
        expectNoDifference(state.collections, ["a", "b"])
        expectNoDifference(state.entries, ["a/p1", "a/public", "b/p2"])
        expectNoDifference(state.privateSpots, ["p1", "p2"])
        expectNoDifference(state.publicSpots, ["public"])
    }

    @Test
    func `losing access takes the collection and its private spots off the device`() async throws {
        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1"]), Self.collection("b", role: .viewer, spots: ["p2"])],
            privateSpots: [Self.privateSpot("p1"), Self.privateSpot("p2")],
        ))
        _ = await sync.pull()

        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1"])],
            privateSpots: [Self.privateSpot("p1")],
        ))
        #expect(await sync.pull() == .synced)

        let state = try stored()
        expectNoDifference(state.collections, ["a"])
        expectNoDifference(state.privateSpots, ["p1"])
        expectNoDifference(state.publicSpots, ["public"])
    }

    @Test
    func `a failed pull keeps what's cached`() async throws {
        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1"])],
            privateSpots: [Self.privateSpot("p1")],
        ))
        _ = await sync.pull()

        await server.fail(with: .offline)
        #expect(await sync.pull() == .failed(.offline))

        let state = try stored()
        expectNoDifference(state.collections, ["a"])
        expectNoDifference(state.privateSpots, ["p1"])
    }

    @Test
    func `a write's answer lands at once, a new collection on top`() async throws {
        await server.set(CollectionsSnapshot(collections: [Self.collection("a", spots: [])], privateSpots: []))
        _ = await sync.pull()

        let generation = await sync.generation
        try await sync.apply(Self.collection("new", spots: ["public"]), requestedIn: generation)
        try await sync.apply(Self.collection("a", spots: ["public"]), requestedIn: generation)

        let state = try stored()
        expectNoDifference(state.collections, ["new", "a"])
        expectNoDifference(state.entries, ["a/public", "new/public"])
    }

    @Test
    func `an ended account leaves no collections`() async throws {
        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1"])],
            privateSpots: [Self.privateSpot("p1")],
        ))
        _ = await sync.pull()

        await sync.reset()

        expectNoDifference(try stored().collections, [])
    }

    @Test
    func `a write's answer that comes back after the account ended is dropped`() async throws {
        let generation = await sync.generation

        await sync.reset()
        try await sync.apply(Self.collection("theirs", spots: ["public"]), requestedIn: generation)

        expectNoDifference(try stored().collections, [])
    }

    @Test
    func `a pull stores invitations and requests; answering an invitation takes it away at once`() async throws {
        let invitation = CollectionInvitation(
            collectionID: "c",
            name: "Crew",
            ownerID: "owner",
            ownerName: "Owner",
            ownerUsername: "owner",
            role: .editor,
            inviterName: "Ana",
            position: 0,
            createdAt: Date(timeIntervalSince1970: 0),
        )
        await server.set(CollectionsSnapshot(collections: [], invitations: [invitation], requestedIDs: ["r"], privateSpots: []))

        let outcome = await sync.pull()
        expectNoDifference(outcome, .synced)
        let pulled = try await database.read { db in
            (try CollectionInvitation.fetchAll(db), try CollectionRequestSent.fetchAll(db).map(\.collectionID))
        }
        expectNoDifference(pulled.0, [invitation])
        expectNoDifference(pulled.1, ["r"])

        let generation = await sync.generation
        try await sync.answered("c", joined: Self.collection("c", role: .editor, spots: []), requestedIn: generation)
        let answered = try await database.read { db in try CollectionInvitation.fetchAll(db) }
        expectNoDifference(answered, [])
        expectNoDifference(try stored().collections, ["c"])
    }

    @Test
    func `accepting an invitation swaps it for the collection in one step`() async throws {
        let invitation = CollectionInvitation(
            collectionID: "c",
            name: "Crew",
            ownerID: "owner",
            ownerName: "Owner",
            ownerUsername: "owner",
            role: .editor,
            inviterName: "Ana",
            position: 0,
            createdAt: Date(timeIntervalSince1970: 0),
        )
        await server.set(CollectionsSnapshot(collections: [], invitations: [invitation], privateSpots: []))
        #expect(await sync.pull() == .synced)
        var standings = ValueObservation.tracking { db in try Self.standing(of: "c", db) }
            .values(in: database)
            .makeAsyncIterator()
        let invited = try await standings.next()

        let generation = await sync.generation
        try await sync.answered("c", joined: Self.collection("c", role: .editor, spots: []), requestedIn: generation)
        let answered = try await standings.next()

        expectNoDifference([invited, answered], ["invited", "joined"])
    }

    @Test
    func `a pull stores a collection's private spots before the collection`() async throws {
        var shown = ValueObservation.tracking { db in try Self.shown(of: "a", db) }
            .removeDuplicates()
            .values(in: database)
            .makeAsyncIterator()
        var seen = try await [shown.next()]
        await server.set(CollectionsSnapshot(
            collections: [Self.collection("a", spots: ["p1", "p2"])],
            privateSpots: [Self.privateSpot("p1"), Self.privateSpot("p2")],
        ))

        #expect(await sync.pull() == .synced)
        while seen.last != "a shows 2 of 2" {
            try await seen.append(shown.next())
        }

        expectNoDifference(seen, ["no a", "a shows 2 of 2"])
    }

    @Test
    func `a typed username or email becomes the right invitee`() {
        expectNoDifference(CollectionInvitee(typed: " @rider_1 "), .username("rider_1"))
        expectNoDifference(CollectionInvitee(typed: "rider_1"), .username("rider_1"))
        expectNoDifference(CollectionInvitee(typed: "Rider@Example.com"), .email("Rider@Example.com"))
        expectNoDifference(CollectionInvitee(typed: "  "), nil)
        expectNoDifference(CollectionInvitee(typed: "@"), nil)
    }

    private func stored() throws -> (collections: [String], entries: [String], privateSpots: [String], publicSpots: [String]) {
        try database.read { db in
            (
                try SpotCollection.order { $0.position }.fetchAll(db).map(\.id),
                try SpotCollectionEntry.order { ($0.collectionID, $0.position) }.fetchAll(db)
                    .map { "\($0.collectionID)/\($0.spotID)" },
                try SpotIndex.where { $0.isPrivate.eq(true) }.order { $0.id }.fetchAll(db).map(\.id),
                try SpotIndex.where { $0.isPrivate.eq(false) }.order { $0.id }.fetchAll(db).map(\.id),
            )
        }
    }

}

// MARK: - FakeCollectionsServer

actor FakeCollectionsServer {

    // MARK: Computed Properties

    nonisolated var api: CollectionsAPIManager {
        var api = CollectionsAPIManager.preview
        api.snapshot = { try await self.current() }
        return api
    }

    // MARK: Properties

    private var snapshot = CollectionsSnapshot(collections: [], privateSpots: [])
    private var failure: CollectionsAPIError?

    // MARK: Functions

    func set(_ snapshot: CollectionsSnapshot) {
        self.snapshot = snapshot
        failure = nil
    }

    func fail(with error: CollectionsAPIError) {
        failure = error
    }

    func current() throws -> CollectionsSnapshot {
        if let failure {
            throw failure
        }
        return snapshot
    }

}
