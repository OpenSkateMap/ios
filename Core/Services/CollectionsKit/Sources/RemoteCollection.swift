public import Foundation
public import SpotModelKit

public struct RemoteCollection: Equatable, Identifiable, Sendable {
    var entries: [SpotCollectionEntry] {
        spotIDs.enumerated().map { SpotCollectionEntry(collectionID: id, spotID: $1, position: $0) }
    }

    public var id: String
    public var name: String
    public var about: String
    public var visibility: CollectionVisibility
    public var kind: CollectionKind
    public var look: CollectionLook
    public var role: CollectionRole
    public var ownerID: String
    public var ownerName: String
    public var ownerUsername: String?
    public var spotIDs: [String]
    public var memberCount: Int
    public var coverKey: String?
    public var coverThumbhash: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String,
                name: String,
                about: String,
                visibility: CollectionVisibility,
                kind: CollectionKind = .custom,
                look: CollectionLook,
                role: CollectionRole,
                ownerID: String,
                ownerName: String,
                ownerUsername: String?,
                spotIDs: [String],
                memberCount: Int,
                coverKey: String?,
                coverThumbhash: String?,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.name = name
        self.about = about
        self.visibility = visibility
        self.kind = kind
        self.look = look
        self.role = role
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.ownerUsername = ownerUsername
        self.spotIDs = spotIDs
        self.memberCount = memberCount
        self.coverKey = coverKey
        self.coverThumbhash = coverThumbhash
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    func row(position: Int) -> SpotCollection {
        SpotCollection(
            id: id,
            name: name,
            about: about,
            visibility: visibility,
            kind: kind,
            look: look,
            role: role,
            ownerID: ownerID,
            ownerName: ownerName,
            ownerUsername: ownerUsername,
            memberCount: memberCount,
            coverKey: coverKey,
            coverThumbhash: coverThumbhash,
            position: position,
            createdAt: createdAt,
            updatedAt: updatedAt,
        )
    }

}
