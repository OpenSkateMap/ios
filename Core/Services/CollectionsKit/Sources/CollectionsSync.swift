import Foundation
import os
import SpotModelKit
public import SpotsKit
public import SQLiteData

public actor CollectionsSync {

    // MARK: Types

    public enum Outcome: Equatable, Sendable {
        case synced
        case failed(CollectionsAPIError)
        case cancelled
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "collections")

    // MARK: Properties

    /// Moves on every `reset()`: answers to requests made before it belong to an ended account.
    public private(set) var generation = 0

    private let api: CollectionsAPIManager
    private let spots: SpotSyncEngine
    private let database: any DatabaseWriter
    private let passes = PassQueue<Outcome>()

    // MARK: Lifecycle

    public init(api: CollectionsAPIManager, spots: SpotSyncEngine, database: any DatabaseWriter) {
        self.api = api
        self.spots = spots
        self.database = database
    }

    // MARK: Static Functions

    static func replace(with snapshot: CollectionsSnapshot, _ db: Database) throws {
        try replace(with: snapshot.collections, db)
        let storedInvitations = try CollectionInvitation.order { $0.position }.fetchAll(db)
        if storedInvitations != snapshot.invitations {
            try CollectionInvitation.delete().execute(db)
            if !snapshot.invitations.isEmpty {
                try CollectionInvitation.insert { snapshot.invitations }.execute(db)
            }
        }
        let requested = snapshot.requestedIDs.sorted().map(CollectionRequestSent.init)
        let storedRequests = try CollectionRequestSent.order { $0.collectionID }.fetchAll(db)
        if storedRequests != requested {
            try CollectionRequestSent.delete().execute(db)
            if !requested.isEmpty {
                try CollectionRequestSent.insert { requested }.execute(db)
            }
        }
    }

    static func replace(with collections: [RemoteCollection], _ db: Database) throws {
        let rows = collections.enumerated().map { $1.row(position: $0) }
        let entries = collections.flatMap(\.entries)
        let storedRows = try SpotCollection.order { $0.position }.fetchAll(db)
        let storedEntries = try SpotCollectionEntry.order { ($0.collectionID, $0.position) }.fetchAll(db)
        let sortedEntries = entries.sorted { ($0.collectionID, $0.position) < ($1.collectionID, $1.position) }
        guard storedRows != rows || storedEntries != sortedEntries else {
            return
        }
        try SpotCollectionEntry.delete().execute(db)
        try SpotCollection.delete().execute(db)
        if !rows.isEmpty {
            try SpotCollection.insert { rows }.execute(db)
        }
        if !entries.isEmpty {
            try SpotCollectionEntry.insert { entries }.execute(db)
        }
    }

    static func upsert(_ collection: RemoteCollection, _ db: Database) throws {
        let stored = try SpotCollection.find(collection.id).fetchOne(db)
        let top = try SpotCollection.order { $0.position }.limit(1).fetchOne(db)?.position ?? 0
        let position = stored?.position ?? top - 1
        try SpotCollection.upsert { collection.row(position: position) }.execute(db)
        try SpotCollectionEntry.where { $0.collectionID.eq(collection.id) }.delete().execute(db)
        let entries = collection.entries
        if !entries.isEmpty {
            try SpotCollectionEntry.insert { entries }.execute(db)
        }
    }

    // MARK: Functions

    /// `joining`: a pull already under way answers (launch, foreground); otherwise the next one, which sees every
    /// change made before the call.
    public func pull(joining: Bool = false) async -> Outcome {
        await passes.run(joining: joining) { await self.pass() }
    }

    public func apply(_ collection: RemoteCollection, requestedIn generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        try await database.write { db in try Self.upsert(collection, db) }
    }

    public func remove(_ collectionID: String) async throws {
        try await database.write { db in
            try SpotCollection.find(collectionID).delete().execute(db)
        }
    }

    public func answered(_ collectionID: String, joined collection: RemoteCollection?, requestedIn generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        // One transaction: between two, the collection's page would see neither and say it's no longer available.
        try await database.write { db in
            try CollectionInvitation.find(collectionID).delete().execute(db)
            if let collection {
                try Self.upsert(collection, db)
            }
        }
    }

    /// The next snapshot confirms it.
    public func requested(_ collectionID: String, requestedIn generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        try await database.write { db in
            try CollectionRequestSent.upsert { CollectionRequestSent(collectionID: collectionID) }.execute(db)
        }
    }

    public func reset() async {
        generation += 1
        await passes.cancel()
        do {
            try await database.write { db in
                try SpotCollectionEntry.delete().execute(db)
                try SpotCollection.delete().execute(db)
                try CollectionInvitation.delete().execute(db)
                try CollectionRequestSent.delete().execute(db)
            }
        } catch {
            Self.logger.error("Clearing collections failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    func focus(of collectionID: String) async -> CollectionFocus? {
        try? await database.read { db in
            guard let collection = try SpotCollection.find(collectionID).fetchOne(db) else {
                return nil
            }
            let spotIDs = try SpotCollectionEntry.where { $0.collectionID.eq(collectionID) }
                .order { $0.position }
                .select(\.spotID)
                .fetchAll(db)
            return CollectionFocus(id: collection.id, name: collection.name, kind: collection.kind, spotIDs: spotIDs)
        }
    }

    private func pass() async -> Outcome {
        let requested = generation
        let spotGeneration = await spots.generation
        do {
            let snapshot = try await api.snapshot()
            guard requested == generation, !Task.isCancelled else {
                return .cancelled
            }
            // Spots first: a collection written before its private spots would show without them.
            try await spots.replacePrivateSpots(with: snapshot.privateSpots, requestedIn: spotGeneration)
            try await database.write { db in try Self.replace(with: snapshot, db) }
            return .synced
        } catch let error as CollectionsAPIError {
            // A refusal's message is the server's text; only its kind goes to the log.
            let kind =
                if case .refused = error {
                    "refused"
                } else {
                    String(describing: error)
                }
            Self.logger.notice("Collections didn't pull: \(kind, privacy: .public)")
            return .failed(error)
        } catch is CancellationError {
            return .cancelled
        } catch {
            Self.logger.error("Applying collections failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failed(.unavailable)
        }
    }
}
