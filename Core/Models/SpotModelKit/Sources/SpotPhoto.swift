public import SQLiteData

@Table("spot_photo")
public struct SpotPhoto: Identifiable, Equatable, Sendable {
    public let id: String
    public var spotID: String
    public var key: String
    public var width: Int
    public var height: Int
    public var thumbhash: String
    public var credit: String?
    public var position: Int
    @Column(as: SpotClip.JSONRepresentation?.self)
    public var clip: SpotClip?

    public init(id: String,
                spotID: String,
                key: String,
                width: Int,
                height: Int,
                thumbhash: String,
                credit: String?,
                position: Int,
                clip: SpotClip? = nil) {
        self.id = id
        self.spotID = spotID
        self.key = key
        self.width = width
        self.height = height
        self.thumbhash = thumbhash
        self.credit = credit
        self.position = position
        self.clip = clip
    }
}
