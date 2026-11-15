public import SpotModelKit

public struct ReviewDraft: Equatable, Sendable {

    // MARK: Properties

    public var title: String
    public var about: String
    public var kind: SpotKind
    public var obstacles: [String]
    public var condition: SpotCondition
    public var latitude: Double
    public var longitude: Double
    public var photoIDs: [String]

    // MARK: Lifecycle

    public init(_ card: ReviewCard) {
        title = card.title
        about = card.about
        kind = card.kind
        obstacles = card.obstacles
        condition = card.condition
        latitude = card.latitude
        longitude = card.longitude
        photoIDs = card.photos.map(\.id)
    }
}
