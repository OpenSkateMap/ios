public import Foundation
public import SQLiteData

@Table("people_sync_state")
public struct PeopleSyncState: Identifiable, Equatable, Sendable {
    public let id: String
    public var blockedLoadedAt: Date?

    public init(id: String, blockedLoadedAt: Date?) {
        self.id = id
        self.blockedLoadedAt = blockedLoadedAt
    }
}
