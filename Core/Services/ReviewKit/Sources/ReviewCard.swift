public import Foundation
public import SpotModelKit

public struct ReviewCard: Identifiable, Equatable, Codable, Sendable {

    // MARK: Nested Types

    public struct Photo: Identifiable, Equatable, Codable, Sendable {
        /// Who a curator is told took the photo.
        public enum Attribution: Equatable, Sendable {
            /// One of the edited spot's own photos: the server credits its uploader as the submitter.
            case spot
            case submitter
            case someoneElse(name: String)
        }

        public var attribution: Attribution {
            switch credit {
            case .someoneElse(let name, _): .someoneElse(name: name)
            case .submitter where isExisting: .spot
            case .submitter: .submitter
            }
        }

        public let id: String
        public var key: String
        public var width: Int
        public var height: Int
        public var thumbhash: String
        public var credit: PhotoCredit
        /// One of the edited spot's own photos, which the edit keeps; its credit is the spot's.
        public var isExisting: Bool
        /// Plays in the photo's place, the photo being its poster.
        public var clip: SpotClip?

        public init(id: String,
                    key: String,
                    width: Int,
                    height: Int,
                    thumbhash: String,
                    credit: PhotoCredit,
                    isExisting: Bool,
                    clip: SpotClip? = nil) {
            self.id = id
            self.key = key
            self.width = width
            self.height = height
            self.thumbhash = thumbhash
            self.credit = credit
            self.isExisting = isExisting
            self.clip = clip
        }
    }

    public struct Snapshot: Equatable, Codable, Sendable {
        public var title: String
        public var about: String
        public var kind: SpotKind
        public var obstacles: [String]
        public var condition: SpotCondition
        public var latitude: Double
        public var longitude: Double
        public var photoCount: Int
        /// How many of the spot's photos the edit removes; photos the spot gained since stay.
        public var removedPhotoCount: Int

        public init(title: String,
                    about: String,
                    kind: SpotKind,
                    obstacles: [String],
                    condition: SpotCondition,
                    latitude: Double,
                    longitude: Double,
                    photoCount: Int,
                    removedPhotoCount: Int) {
            self.title = title
            self.about = about
            self.kind = kind
            self.obstacles = obstacles
            self.condition = condition
            self.latitude = latitude
            self.longitude = longitude
            self.photoCount = photoCount
            self.removedPhotoCount = removedPhotoCount
        }
    }

    // MARK: Computed Properties

    public var isEdit: Bool {
        !changedFields.isEmpty
    }

    // MARK: Properties

    public let id: String
    public var title: String
    public var about: String
    public var kind: SpotKind
    public var obstacles: [String]
    public var condition: SpotCondition
    public var latitude: Double
    public var longitude: Double
    public var cityID: String?
    public var note: String
    public var photos: [Photo]
    public var submitterName: String?
    public var nearby: [NearbySpot]
    public var spotID: String?
    public var changedFields: [SpotEditField]
    public var current: Snapshot?
    public var createdAt: Date
    public var updatedAt: Date

    // MARK: Lifecycle

    public init(id: String,
                title: String,
                about: String,
                kind: SpotKind,
                obstacles: [String],
                condition: SpotCondition,
                latitude: Double,
                longitude: Double,
                cityID: String?,
                note: String,
                photos: [Photo],
                submitterName: String?,
                nearby: [NearbySpot],
                spotID: String? = nil,
                changedFields: [SpotEditField] = [],
                current: Snapshot? = nil,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.title = title
        self.about = about
        self.kind = kind
        self.obstacles = obstacles
        self.condition = condition
        self.latitude = latitude
        self.longitude = longitude
        self.cityID = cityID
        self.note = note
        self.photos = photos
        self.submitterName = submitterName
        self.nearby = nearby
        self.spotID = spotID
        self.changedFields = changedFields
        self.current = current
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
