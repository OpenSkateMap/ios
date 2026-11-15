public import SQLiteData

@Table("spot_index")
public struct SpotIndex: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var kind: SpotKind
    public var condition: SpotCondition
    public var cityID: String?
    public var latitude: Double
    public var longitude: Double
    public var version: Int
    public var coverKey: String?
    public var coverWidth: Int?
    public var coverHeight: Int?
    public var coverThumbhash: String?
    public var reindexEpoch: Int
    public var isPrivate: Bool
    @Column(as: [String].JSONRepresentation.self)
    public var obstacles: [String]

    public init(id: String,
                title: String,
                kind: SpotKind,
                condition: SpotCondition,
                cityID: String?,
                latitude: Double,
                longitude: Double,
                version: Int,
                coverKey: String? = nil,
                coverWidth: Int? = nil,
                coverHeight: Int? = nil,
                coverThumbhash: String? = nil,
                reindexEpoch: Int = 0,
                isPrivate: Bool = false,
                obstacles: [String] = []) {
        self.id = id
        self.title = title
        self.kind = kind
        self.condition = condition
        self.cityID = cityID
        self.latitude = latitude
        self.longitude = longitude
        self.version = version
        self.coverKey = coverKey
        self.coverWidth = coverWidth
        self.coverHeight = coverHeight
        self.coverThumbhash = coverThumbhash
        self.reindexEpoch = reindexEpoch
        self.isPrivate = isPrivate
        self.obstacles = obstacles
    }
}
