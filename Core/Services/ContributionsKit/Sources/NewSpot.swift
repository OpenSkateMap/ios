public import PhotoUploadKit
public import SpotModelKit

public struct NewSpot: Equatable, Sendable {
    public struct Photo: Equatable, Sendable {
        public var prepared: PreparedPhoto
        public var credit: PhotoCredit
        /// Plays in the photo's place, the photo being its poster; the outbox moves its file into its own.
        public var clip: PreparedClip?

        public init(prepared: PreparedPhoto, credit: PhotoCredit, clip: PreparedClip? = nil) {
            self.prepared = prepared
            self.credit = credit
            self.clip = clip
        }
    }

    public var title: String
    public var about: String
    public var kind: SpotKind
    public var obstacles: [String]
    public var condition: SpotCondition
    public var latitude: Double
    public var longitude: Double
    public var note: String
    public var collectionID: String?
    public var photos: [Photo]

    public init(title: String,
                about: String,
                kind: SpotKind,
                obstacles: [String],
                condition: SpotCondition,
                latitude: Double,
                longitude: Double,
                note: String,
                collectionID: String? = nil,
                photos: [Photo]) {
        self.title = title
        self.about = about
        self.kind = kind
        self.obstacles = obstacles
        self.condition = condition
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.collectionID = collectionID
        self.photos = photos
    }
}
