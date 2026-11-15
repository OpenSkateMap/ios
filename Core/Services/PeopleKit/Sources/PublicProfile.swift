public import Foundation

// MARK: - PublicProfile

public struct PublicProfile: Equatable, Identifiable, Sendable {

    // MARK: Types

    public enum Role: String, Equatable, Sendable {
        case user
        case editor
        case admin
    }

    public struct Avatar: Equatable, Sendable {
        public var key: String
        public var thumbhash: String

        public init(key: String, thumbhash: String) {
            self.key = key
            self.thumbhash = thumbhash
        }
    }

    public struct Stats: Equatable, Sendable {
        public var submitted: Int
        public var approved: Int
        public var cities: Int

        public init(submitted: Int, approved: Int, cities: Int) {
            self.submitted = submitted
            self.approved = approved
            self.cities = cities
        }
    }

    public struct City: Equatable, Identifiable, Sendable {
        public var id: String
        public var name: String

        public init(id: String, name: String) {
            self.id = id
            self.name = name
        }
    }

    // MARK: Properties

    public var id: String
    public var name: String
    public var username: String?
    public var bio: String
    public var avatar: Avatar?
    public var handles: Handles
    public var role: Role
    public var editorOf: [City]
    public var stats: Stats
    public var joinedAt: Date
    public var blockedByMe: Bool

    // MARK: Lifecycle

    public init(id: String,
                name: String,
                username: String? = nil,
                bio: String = "",
                avatar: Avatar? = nil,
                handles: Handles = Handles(),
                role: Role = .user,
                editorOf: [City] = [],
                stats: Stats = Stats(submitted: 0, approved: 0, cities: 0),
                joinedAt: Date,
                blockedByMe: Bool = false) {
        self.id = id
        self.name = name
        self.username = username
        self.bio = bio
        self.avatar = avatar
        self.handles = handles
        self.role = role
        self.editorOf = editorOf
        self.stats = stats
        self.joinedAt = joinedAt
        self.blockedByMe = blockedByMe
    }
}
