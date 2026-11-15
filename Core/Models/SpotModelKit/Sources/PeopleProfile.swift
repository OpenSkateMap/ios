public import Foundation
public import SQLiteData

// MARK: - PeopleProfile

@Table("people_profile")
public struct PeopleProfile: Identifiable, Equatable, Sendable {

    // MARK: Types

    public struct City: Codable, Equatable, Sendable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    // MARK: Properties

    public let id: String
    public var accountID: String
    public var name: String
    public var username: String?
    public var bio: String
    public var avatarKey: String?
    public var avatarThumbhash: String?
    @Column(as: [String: String].JSONRepresentation.self)
    public var handles: [String: String]
    public var role: String
    @Column(as: [City].JSONRepresentation.self)
    public var editorOf: [City]
    public var submitted: Int
    public var approved: Int
    public var cities: Int
    public var joinedAt: Date
    public var blockedByMe: Bool
    public var fetchedAt: Date

    // MARK: Lifecycle

    public init(id: String,
                accountID: String,
                name: String,
                username: String?,
                bio: String,
                avatarKey: String?,
                avatarThumbhash: String?,
                handles: [String: String],
                role: String,
                editorOf: [City],
                submitted: Int,
                approved: Int,
                cities: Int,
                joinedAt: Date,
                blockedByMe: Bool,
                fetchedAt: Date) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.username = username
        self.bio = bio
        self.avatarKey = avatarKey
        self.avatarThumbhash = avatarThumbhash
        self.handles = handles
        self.role = role
        self.editorOf = editorOf
        self.submitted = submitted
        self.approved = approved
        self.cities = cities
        self.joinedAt = joinedAt
        self.blockedByMe = blockedByMe
        self.fetchedAt = fetchedAt
    }
}
