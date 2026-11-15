public import Foundation
public import SQLiteData

/// `id` is also the server's video id, sent unchanged on every retry, so the server keeps one video.
@Table("video_draft")
public struct VideoDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public var spotID: String
    public var url: String
    public var caption: String
    public var status: OutboxStatus
    public var problem: String?
    public var attempts: Int
    public var nextAttemptAt: Date?
    public var createdAt: Date

    public init(id: String,
                spotID: String,
                url: String,
                caption: String,
                status: OutboxStatus = .pending,
                problem: String? = nil,
                attempts: Int = 0,
                nextAttemptAt: Date? = nil,
                createdAt: Date) {
        self.id = id
        self.spotID = spotID
        self.url = url
        self.caption = caption
        self.status = status
        self.problem = problem
        self.attempts = attempts
        self.nextAttemptAt = nextAttemptAt
        self.createdAt = createdAt
    }
}
