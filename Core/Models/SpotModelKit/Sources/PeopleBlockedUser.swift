public import Foundation
public import SQLiteData

@Table("people_blocked_user")
public struct PeopleBlockedUser: Identifiable, Equatable, Sendable {
    public let id: String
    public var accountID: String
    public var name: String
    public var username: String?
    public var blockedAt: Date

    public init(id: String, accountID: String, name: String, username: String?, blockedAt: Date) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.username = username
        self.blockedAt = blockedAt
    }
}
