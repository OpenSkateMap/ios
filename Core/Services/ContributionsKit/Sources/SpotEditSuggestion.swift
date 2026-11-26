public import SpotModelKit

public struct SpotEditSuggestion: Equatable, Sendable {

    // MARK: Nested Types

    /// The spot's photos as the edit leaves them, or new ones after the spot's own.
    public struct PhotoEdit: Equatable, Sendable {
        public enum Slot: Equatable, Sendable {
            case kept(id: String)
            case added(NewSpot.Photo)
        }

        /// The cover first.
        public let order: [Slot]
        /// The ids the editor showed, so the server keeps any gained since; nil: `order` is new photos, after the spot's.
        public let base: [String]?

        public init(order: [Slot], base: [String]) {
            self.order = order
            self.base = base
        }

        private init(adding photos: [NewSpot.Photo]) {
            order = photos.map { .added($0) }
            base = nil
        }

        public static func adding(_ photos: [NewSpot.Photo]) -> PhotoEdit {
            PhotoEdit(adding: photos)
        }
    }

    // MARK: Computed Properties

    public var changedFields: [SpotEditField] {
        photoEdit == nil ? changedDetails : changedDetails + [.photos]
    }

    // MARK: Properties

    public let spotID: String
    /// The spot's fields as the edit leaves them; its new photos are `photoEdit`'s, so `photos` is empty.
    public let proposed: NewSpot
    /// The fields the edit changes besides the photos.
    public let changedDetails: [SpotEditField]
    /// Nil leaves the spot's photos as they are.
    public let photoEdit: PhotoEdit?

    // MARK: Lifecycle

    public init(spotID: String, proposed: NewSpot, changedDetails: [SpotEditField], photoEdit: PhotoEdit?) {
        var proposed = proposed
        proposed.photos = []
        self.spotID = spotID
        self.proposed = proposed
        self.changedDetails = changedDetails.filter { $0 != .photos }
        self.photoEdit = photoEdit
    }
}
