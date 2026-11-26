public struct SpotEditTarget: Equatable, Sendable {
    public var spotID: String
    public var title: String
    public var about: String
    public var kind: SpotKind
    public var obstacles: [String]
    public var condition: SpotCondition
    public var latitude: Double
    public var longitude: Double
    public var address: String?
    /// In display order; the first is the cover. Nil when the editor didn't load them: new photos go after them.
    public var photos: [SpotPhoto]?

    public init(spotID: String,
                title: String,
                about: String,
                kind: SpotKind,
                obstacles: [String],
                condition: SpotCondition,
                latitude: Double,
                longitude: Double,
                address: String?,
                photos: [SpotPhoto]?) {
        self.spotID = spotID
        self.title = title
        self.about = about
        self.kind = kind
        self.obstacles = obstacles
        self.condition = condition
        self.latitude = latitude
        self.longitude = longitude
        self.address = address
        self.photos = photos
    }
}
