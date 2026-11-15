public import Foundation

public struct BlockedUser: Equatable, Identifiable, Sendable {
    public var id: String
    public var name: String
    public var username: String?
    public var blockedAt: Date

    public init(id: String, name: String, username: String?, blockedAt: Date) {
        self.id = id
        self.name = name
        self.username = username
        self.blockedAt = blockedAt
    }
}
