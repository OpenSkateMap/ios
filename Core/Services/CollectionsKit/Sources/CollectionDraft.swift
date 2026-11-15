public import PhotoUploadKit
public import SpotModelKit

// MARK: - CollectionDraft

public struct CollectionDraft: Equatable, Sendable {
    public var name: String
    public var about: String
    public var visibility: CollectionVisibility
    /// `nil` keeps the look as it is.
    public var look: CollectionLookDraft?

    public init(name: String, about: String = "", visibility: CollectionVisibility = .private, look: CollectionLookDraft? = nil) {
        self.name = name
        self.about = about
        self.visibility = visibility
        self.look = look
    }
}

// MARK: - CollectionLookDraft

/// Saved whole: the server keeps picking the colour.
public struct CollectionLookDraft: Equatable, Sendable {
    public enum Photo: Equatable, Sendable {
        case none
        case kept(CollectionPhoto)
        case new(PreparedPhoto)
    }

    public var photo: Photo

    public init(photo: Photo) {
        self.photo = photo
    }

    public init(_ look: CollectionLook) {
        self.init(photo: look.photo.map(Photo.kept) ?? .none)
    }
}
