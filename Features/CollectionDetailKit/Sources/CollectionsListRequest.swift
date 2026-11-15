import SpotModelKit
import SQLiteData

nonisolated struct CollectionsListRequest: FetchKeyRequest {
    func fetch(_ db: Database) throws -> [CollectionRow] {
        let collections = try SpotCollection.order { $0.position }.fetchAll(db)
        let counts = try Dictionary(
            SpotCollectionEntry.group(by: \.collectionID).select { ($0.collectionID, $0.spotID.count()) }.fetchAll(db),
            uniquingKeysWith: { first, _ in first },
        )
        return collections.map { CollectionRow($0, spotCount: counts[$0.id] ?? 0) }
    }
}
