public import SQLiteData

// MARK: - CollectionKind

/// `favorites` is the one every account has, for starred spots: it keeps its name and can't be deleted.
public enum CollectionKind: String, CaseIterable, Codable, Sendable, QueryBindable {
    case custom
    case favorites
}

// MARK: - CollectionColor

/// Eight solid colours, then eight two-tone ones.
public enum CollectionColor: String, CaseIterable, Codable, Sendable, QueryBindable {
    case blue
    case green
    case orange
    case red
    case purple
    case teal
    case pink
    case gray
    case sky
    case lime
    case amber
    case coral
    case violet
    case mint
    case rose
    case silver
}

// MARK: - CollectionPhoto

public struct CollectionPhoto: Hashable, Sendable {
    public var id: String
    public var key: String
    public var thumbhash: String

    public init(id: String, key: String, thumbhash: String) {
        self.id = id
        self.key = key
        self.thumbhash = thumbhash
    }
}

// MARK: - CollectionLook

public struct CollectionLook: Hashable, Sendable {
    public var color: CollectionColor
    public var photo: CollectionPhoto?

    public init(color: CollectionColor, photo: CollectionPhoto? = nil) {
        self.color = color
        self.photo = photo
    }

    // MARK: Functions

    public func pictureKey(cover: String?) -> String? {
        photo?.key ?? cover
    }

    public func pictureThumbhash(cover: String?) -> String? {
        photo?.thumbhash ?? cover
    }
}

// MARK: - CollectionFocus

/// A collection on the Discover map: only its spots.
public struct CollectionFocus: Equatable, Sendable {
    public var id: String
    public var name: String
    public var kind: CollectionKind
    public var spotIDs: [String]

    public init(id: String, name: String, kind: CollectionKind, spotIDs: [String]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.spotIDs = spotIDs
    }
}
