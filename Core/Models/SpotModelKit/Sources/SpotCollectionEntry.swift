public import SQLiteData

@Table("collection_spot")
public struct SpotCollectionEntry: Equatable, Sendable {
    public var collectionID: String
    public var spotID: String
    public var position: Int

    public init(collectionID: String, spotID: String, position: Int) {
        self.collectionID = collectionID
        self.spotID = spotID
        self.position = position
    }
}
