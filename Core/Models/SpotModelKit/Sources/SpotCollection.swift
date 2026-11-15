public import Foundation
public import SQLiteData

// MARK: - SpotCollection

@Table("collection")
public struct SpotCollection: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var about: String
    public var visibility: CollectionVisibility
    public var kind: CollectionKind
    public var color: CollectionColor
    public var photoID: String?
    public var photoKey: String?
    public var photoThumbhash: String?
    public var role: CollectionRole
    public var ownerID: String
    public var ownerName: String
    public var ownerUsername: String?
    public var memberCount: Int
    public var coverKey: String?
    public var coverThumbhash: String?
    public var position: Int
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String,
                name: String,
                about: String,
                visibility: CollectionVisibility,
                kind: CollectionKind,
                look: CollectionLook,
                role: CollectionRole,
                ownerID: String,
                ownerName: String,
                ownerUsername: String?,
                memberCount: Int,
                coverKey: String?,
                coverThumbhash: String?,
                position: Int,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.name = name
        self.about = about
        self.visibility = visibility
        self.kind = kind
        color = look.color
        photoID = look.photo?.id
        photoKey = look.photo?.key
        photoThumbhash = look.photo?.thumbhash
        self.role = role
        self.ownerID = ownerID
        self.ownerName = ownerName
        self.ownerUsername = ownerUsername
        self.memberCount = memberCount
        self.coverKey = coverKey
        self.coverThumbhash = coverThumbhash
        self.position = position
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension SpotCollection {
    public var look: CollectionLook {
        CollectionLook(color: color, photo: photo)
    }

    private var photo: CollectionPhoto? {
        guard let photoID, let photoKey, let photoThumbhash else {
            return nil
        }
        return CollectionPhoto(id: photoID, key: photoKey, thumbhash: photoThumbhash)
    }
}
