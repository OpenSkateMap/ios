public import Foundation
public import SQLiteData

// MARK: - CollectionInvitation

@Table("collection_invitation")
public struct CollectionInvitation: Identifiable, Hashable, Sendable {
    public var id: String {
        collectionID
    }

    @Column(primaryKey: true)
    public var collectionID: String
    public var name: String
    public var ownerID: String
    public var ownerName: String
    public var ownerUsername: String?
    public var role: CollectionMemberRole
    public var inviterName: String?
    public var position: Int
    public var createdAt: Date

    public init(collectionID: String,
                name: String,
                ownerID: String,
                ownerName: String,
                ownerUsername: String?,
                role: CollectionMemberRole,
                inviterName: String?,
                position: Int,
                createdAt: Date) {
        self.collectionID = collectionID
        self.name = name
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.ownerUsername = ownerUsername
        self.role = role
        self.inviterName = inviterName
        self.position = position
        self.createdAt = createdAt
    }
}

// MARK: - CollectionRequestSent

/// A collection the account asked to join, not answered yet.
@Table("collection_request")
public struct CollectionRequestSent: Equatable, Sendable {
    @Column(primaryKey: true)
    public var collectionID: String

    public init(collectionID: String) {
        self.collectionID = collectionID
    }
}
