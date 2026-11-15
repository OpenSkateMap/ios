public import Foundation

// MARK: - Account

public struct Account: Codable, Equatable, Identifiable, Sendable {
    public enum Role: String, Codable, Sendable {
        case user
        case editor
        case admin
    }

    public var id: String
    public var name: String
    public var email: String
    public var role: Role
    public var createdAt: Date
    public var pushIdentity: String?

    public init(id: String, name: String, email: String, role: Role, createdAt: Date, pushIdentity: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.role = role
        self.createdAt = createdAt
        self.pushIdentity = pushIdentity
    }
}

extension Account {
    public static let preview = Account(
        id: "preview",
        name: "Preview Skater",
        email: "preview@privaterelay.appleid.com",
        role: .user,
        createdAt: Date(timeIntervalSince1970: 1_791_590_400),
    )
}
