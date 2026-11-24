public import Foundation
public import SpotModelKit

public struct RemoteSpotDetail: Equatable, Sendable {
    public struct Photo: Equatable, Sendable {
        public var id: String
        public var key: String
        public var width: Int
        public var height: Int
        public var thumbhash: String
        public var credit: String?
        public var position: Int
        public var clip: SpotClip?

        public init(id: String,
                    key: String,
                    width: Int,
                    height: Int,
                    thumbhash: String,
                    credit: String?,
                    position: Int,
                    clip: SpotClip? = nil) {
            self.id = id
            self.key = key
            self.width = width
            self.height = height
            self.thumbhash = thumbhash
            self.credit = credit
            self.position = position
            self.clip = clip
        }
    }

    public struct Video: Equatable, Sendable {
        public var id: String
        public var provider: VideoProvider
        public var url: String
        public var thumbnailURL: String?
        public var caption: String
        public var addedByID: String?
        public var addedByName: String?

        public init(id: String,
                    provider: VideoProvider,
                    url: String,
                    thumbnailURL: String?,
                    caption: String,
                    addedByID: String?,
                    addedByName: String?) {
            self.id = id
            self.provider = provider
            self.url = url
            self.thumbnailURL = thumbnailURL
            self.caption = caption
            self.addedByID = addedByID
            self.addedByName = addedByName
        }
    }

    public var id: String
    public var about: String
    public var obstacles: [String]
    public var addedByID: String?
    public var addedByName: String?
    public var createdAt: Date
    public var version: Int
    public var photos: [Photo]
    public var videos: [Video]
    public var votes: SpotVoteTotals

    public init(id: String,
                about: String,
                obstacles: [String],
                addedByID: String?,
                addedByName: String?,
                createdAt: Date,
                version: Int,
                photos: [Photo],
                videos: [Video] = [],
                votes: SpotVoteTotals = SpotVoteTotals()) {
        self.id = id
        self.about = about
        self.obstacles = obstacles
        self.addedByID = addedByID
        self.addedByName = addedByName
        self.createdAt = createdAt
        self.version = version
        self.photos = photos
        self.videos = videos
        self.votes = votes
    }

    func row(fetchedAt: Date) -> SpotDetail {
        SpotDetail(
            id: id,
            about: about,
            obstacles: obstacles,
            addedByID: addedByID,
            addedByName: addedByName,
            createdAt: createdAt,
            version: version,
            fetchedAt: fetchedAt,
            upvotes: votes.up,
            downvotes: votes.down,
            myVote: votes.mine,
        )
    }

    func videoRows() -> [SpotVideo] {
        videos.enumerated().map { position, video in
            SpotVideo(
                id: video.id,
                spotID: id,
                provider: video.provider,
                url: video.url,
                thumbnailURL: video.thumbnailURL,
                caption: video.caption,
                addedByID: video.addedByID,
                addedByName: video.addedByName,
                position: position,
            )
        }
    }

    func photoRows() -> [SpotPhoto] {
        photos.map {
            SpotPhoto(
                id: $0.id,
                spotID: id,
                key: $0.key,
                width: $0.width,
                height: $0.height,
                thumbhash: $0.thumbhash,
                credit: $0.credit,
                position: $0.position,
                clip: $0.clip,
            )
        }
    }
}
