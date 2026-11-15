public import Foundation
public import SpotModelKit

public struct VideoReviewCard: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public var spotID: String
    public var spotTitle: String
    public var spotKind: SpotKind
    public var cityID: String?
    public var provider: VideoProvider
    public var url: URL
    public var thumbnailURL: URL?
    public var caption: String
    public var submitterName: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String,
                spotID: String,
                spotTitle: String,
                spotKind: SpotKind,
                cityID: String?,
                provider: VideoProvider,
                url: URL,
                thumbnailURL: URL?,
                caption: String,
                submitterName: String?,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.spotID = spotID
        self.spotTitle = spotTitle
        self.spotKind = spotKind
        self.cityID = cityID
        self.provider = provider
        self.url = url
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.submitterName = submitterName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
