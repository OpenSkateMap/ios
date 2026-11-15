import Foundation
import SpotModelKit
import SQLiteData

// MARK: - LocalCollection

nonisolated struct LocalCollection: Equatable, Sendable {
    var collection: SpotCollection
    var spots: [SpotIndex]
}

// MARK: - LocalStanding

nonisolated struct LocalStanding: Equatable, Sendable {
    var collection: LocalCollection?
    var invitation: CollectionInvitation?
    var requested = false
}

// MARK: - LocalCollectionRequest

nonisolated struct LocalCollectionRequest: FetchKeyRequest {
    let id: String

    func fetch(_ db: Database) throws -> LocalStanding {
        let invitation = try CollectionInvitation.find(id).fetchOne(db)
        let requested = try CollectionRequestSent.where { $0.collectionID.eq(id) }.fetchCount(db) > 0
        guard let collection = try SpotCollection.find(id).fetchOne(db) else {
            return LocalStanding(invitation: invitation, requested: requested)
        }
        let entries = try SpotCollectionEntry.where { $0.collectionID.eq(id) }.order { $0.position }.fetchAll(db)
        let rows = try SpotIndex.where { $0.id.in(entries.map(\.spotID)) }.fetchAll(db)
        let byID = Dictionary(rows.map { ($0.id, $0) }) { first, _ in first }
        return LocalStanding(
            collection: LocalCollection(collection: collection, spots: entries.compactMap { byID[$0.spotID] }),
            invitation: invitation,
            requested: requested,
        )
    }
}

// MARK: - SavedIn

nonisolated struct SavedIn: Equatable, Sendable {
    var collection: SpotCollection
    var contains: Bool
}

// MARK: - SavedInRequest

nonisolated struct SavedInRequest: FetchKeyRequest {
    let spotID: String

    func fetch(_ db: Database) throws -> [SavedIn] {
        let editable = [CollectionRole.owner, .admin, .editor]
        let mine = try SpotCollection.where { $0.role.in(editable) }.order { $0.position }.fetchAll(db)
        let holding = try Set(SpotCollectionEntry.where { $0.spotID.eq(spotID) }.select(\.collectionID).fetchAll(db))
        return mine.map { SavedIn(collection: $0, contains: holding.contains($0.id)) }
    }
}
