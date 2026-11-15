public import Foundation
import os
import SpotModelKit
public import SQLiteData

public actor PeopleStore {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "people")

    // MARK: Properties

    public private(set) var generation = 0

    private let database: any DatabaseWriter
    private let now: @Sendable () -> Date

    // MARK: Lifecycle

    public init(database: any DatabaseWriter, now: @escaping @Sendable () -> Date = Date.init) {
        self.database = database
        self.now = now
    }

    // MARK: Functions

    public func save(_ profile: PublicProfile, for account: String, from generation: Int) async {
        let row = profile.row(for: account, fetchedAt: now())
        await write(generation) { db in
            try PeopleProfile.upsert { row }.execute(db)
        }
    }

    public func forget(_ personID: String, for account: String, from generation: Int) async {
        await write(generation) { db in
            try PeopleProfile.where { $0.id.eq(personID) && $0.accountID.eq(account) }.delete().execute(db)
        }
    }

    public func replaceBlocked(_ users: [BlockedUser], for account: String, from generation: Int) async {
        let rows = users.map {
            PeopleBlockedUser(id: $0.id, accountID: account, name: $0.name, username: $0.username, blockedAt: $0.blockedAt)
        }
        let loadedAt = now()
        await write(generation) { db in
            try PeopleBlockedUser.where { $0.accountID.eq(account) }.delete().execute(db)
            if !rows.isEmpty {
                try PeopleBlockedUser.insert { rows }.execute(db)
            }
            try PeopleSyncState.upsert { PeopleSyncState(id: account, blockedLoadedAt: loadedAt) }.execute(db)
        }
    }

    public func setBlocked(_ personID: String, _ blocked: Bool, for account: String, from generation: Int) async {
        let blockedAt = now()
        await write(generation) { db in
            try PeopleProfile.where { $0.id.eq(personID) && $0.accountID.eq(account) }
                .update { $0.blockedByMe = #bind(blocked) }
                .execute(db)
            guard blocked else {
                try PeopleBlockedUser.where { $0.id.eq(personID) && $0.accountID.eq(account) }.delete().execute(db)
                return
            }
            guard let profile = try PeopleProfile.where({ $0.id.eq(personID) && $0.accountID.eq(account) }).fetchOne(db) else {
                return
            }
            let row = PeopleBlockedUser(
                id: personID,
                accountID: account,
                name: profile.name,
                username: profile.username,
                blockedAt: blockedAt,
            )
            try PeopleBlockedUser.upsert { row }.execute(db)
        }
    }

    public func reset() async {
        generation += 1
        do {
            try await database.write { db in
                try PeopleProfile.delete().execute(db)
                try PeopleBlockedUser.delete().execute(db)
                try PeopleSyncState.delete().execute(db)
            }
        } catch {
            Self.logger.error("Could not clear the people cache: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func write(_ generation: Int, _ work: @escaping @Sendable (Database) throws -> Void) async {
        guard generation == self.generation else {
            return
        }
        do {
            try await database.write(work)
        } catch {
            Self.logger.error("Could not write the people cache: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
