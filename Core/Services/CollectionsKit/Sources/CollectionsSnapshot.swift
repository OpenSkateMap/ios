public import SpotModelKit

// MARK: - CollectionsSnapshot

public struct CollectionsSnapshot: Equatable, Sendable {
    public var collections: [RemoteCollection]
    /// Newest first.
    public var invitations: [CollectionInvitation]
    public var requestedIDs: [String]
    public var privateSpots: [SpotIndex]

    public init(collections: [RemoteCollection],
                invitations: [CollectionInvitation] = [],
                requestedIDs: [String] = [],
                privateSpots: [SpotIndex]) {
        self.collections = collections
        self.invitations = invitations
        self.requestedIDs = requestedIDs
        self.privateSpots = privateSpots
    }
}

// MARK: - CollectionPage

public struct CollectionPage: Equatable, Sendable {
    public var collection: RemoteCollection
    /// The first page of its spots; `nextCursor` asks for the rest (`CollectionsSession.spots(of:after:)`).
    public var spots: CollectionSpotsPage

    public init(collection: RemoteCollection, spots: CollectionSpotsPage) {
        self.collection = collection
        self.spots = spots
    }
}

// MARK: - CollectionSpotsPage

public struct CollectionSpotsPage: Equatable, Sendable {
    public var spots: [SpotIndex]
    /// Opaque; nil on the last page.
    public var nextCursor: String?

    public init(spots: [SpotIndex], nextCursor: String?) {
        self.spots = spots
        self.nextCursor = nextCursor
    }
}
