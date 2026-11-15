public import Foundation
public import SQLiteData

@Table("sync_state")
public struct SyncState: Equatable, Sendable {
    public static let rowID = 1

    public let id: Int
    public var cursor: Int
    public var reindexEpoch: Int
    public var resyncNeeded: Bool
    public var reindexCursor: Int
    public var lastSuccessAt: Date?

    public init(id: Int = SyncState.rowID,
                cursor: Int = 0,
                reindexEpoch: Int = 0,
                resyncNeeded: Bool = false,
                reindexCursor: Int = 0,
                lastSuccessAt: Date? = nil) {
        self.id = id
        self.cursor = cursor
        self.reindexEpoch = reindexEpoch
        self.resyncNeeded = resyncNeeded
        self.reindexCursor = reindexCursor
        self.lastSuccessAt = lastSuccessAt
    }
}
