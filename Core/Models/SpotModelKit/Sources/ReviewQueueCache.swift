public import Foundation
public import SQLiteData

@Table("review_queue_cache")
public struct ReviewQueueCache: Identifiable, Equatable, Sendable {
    public static let rowID = "queue"

    public let id: String
    public var payload: Data
    public var savedAt: Date

    public init(id: String = Self.rowID, payload: Data, savedAt: Date) {
        self.id = id
        self.payload = payload
        self.savedAt = savedAt
    }
}
