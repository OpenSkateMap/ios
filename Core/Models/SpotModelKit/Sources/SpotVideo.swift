public import SQLiteData

@Table("spot_video")
public struct SpotVideo: Identifiable, Equatable, Sendable {
    public let id: String
    public var spotID: String
    public var provider: VideoProvider
    public var url: String
    public var thumbnailURL: String?
    public var caption: String
    public var addedByID: String?
    public var addedByName: String?
    public var position: Int

    public init(id: String,
                spotID: String,
                provider: VideoProvider,
                url: String,
                thumbnailURL: String?,
                caption: String,
                addedByID: String?,
                addedByName: String?,
                position: Int) {
        self.id = id
        self.spotID = spotID
        self.provider = provider
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.addedByID = addedByID
        self.addedByName = addedByName
        self.position = position
    }
}
