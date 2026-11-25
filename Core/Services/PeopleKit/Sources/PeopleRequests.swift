import SpotModelKit
public import SQLiteData

// MARK: - ProfileRequest

public struct ProfileRequest: FetchKeyRequest {
    public let personID: String
    public let account: String?

    public init(personID: String, account: String?) {
        self.personID = personID
        self.account = account
    }

    public func fetch(_ db: Database) throws -> PublicProfile? {
        guard let account,
              var profile = try PeopleProfile.where({ $0.id.eq(personID) && $0.accountID.eq(account) }).fetchOne(db)
                  .map(PublicProfile.init) else {
            return nil
        }
        guard !profile.editorOf.isEmpty else {
            return profile
        }
        let cities = try City.where { $0.id.in(profile.editorOf.map(\.id)) }.fetchAll(db)
        for index in profile.editorOf.indices {
            if let city = cities.first(where: { $0.id == profile.editorOf[index].id }) {
                profile.editorOf[index].name = city.localizedName
            }
        }
        return profile
    }
}

// MARK: - BlockedUsers

public struct BlockedUsers: Equatable, Sendable {
    public var users: [BlockedUser]
    public var isLoaded: Bool

    public init(users: [BlockedUser] = [], isLoaded: Bool = false) {
        self.users = users
        self.isLoaded = isLoaded
    }
}

// MARK: - BlockedUsersRequest

public struct BlockedUsersRequest: FetchKeyRequest {
    public let account: String?

    public init(account: String?) {
        self.account = account
    }

    public func fetch(_ db: Database) throws -> BlockedUsers {
        guard let account else {
            return BlockedUsers()
        }
        let users = try PeopleBlockedUser.where { $0.accountID.eq(account) }
            .order { $0.blockedAt.desc() }
            .fetchAll(db)
            .map { BlockedUser(id: $0.id, name: $0.name, username: $0.username, blockedAt: $0.blockedAt) }
        let state = try PeopleSyncState.find(account).fetchOne(db)
        return BlockedUsers(users: users, isLoaded: state?.blockedLoadedAt != nil)
    }
}
