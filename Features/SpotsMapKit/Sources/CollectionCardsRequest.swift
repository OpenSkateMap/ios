import Foundation
import SpotModelKit
import SQLiteData

// MARK: - CollectionCard

nonisolated struct CollectionCard: Equatable, Identifiable, Sendable {
    var id: String {
        collection.id
    }

    var collection: SpotCollection
    var spotCount: Int
}

// MARK: - CollectionCardsRequest

nonisolated struct CollectionCardsRequest: FetchKeyRequest {
    func fetch(_ db: Database) throws -> [CollectionCard] {
        let collections = try SpotCollection.order { $0.position }.fetchAll(db)
        let counts = try SpotCollectionEntry.group(by: \.collectionID).select { ($0.collectionID, $0.spotID.count()) }
            .fetchAll(db)
        let countByID = Dictionary(counts) { first, _ in first }
        return collections.map { CollectionCard(collection: $0, spotCount: countByID[$0.id] ?? 0) }
    }
}
