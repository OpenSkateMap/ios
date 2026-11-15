import Foundation
import SpotModelKit

extension PublicProfile {
    init(_ row: PeopleProfile) {
        self.init(
            id: row.id,
            name: row.name,
            username: row.username,
            bio: row.bio,
            avatar: row.avatarKey.flatMap { key in row.avatarThumbhash.map { Avatar(key: key, thumbhash: $0) } },
            handles: Handles(Dictionary(uniqueKeysWithValues: row.handles.compactMap { key, value in
                HandleNetwork(rawValue: key).map { ($0, value) }
            })),
            role: Role(rawValue: row.role) ?? .user,
            editorOf: row.editorOf.map { City(id: $0.id, name: $0.name) },
            stats: Stats(submitted: row.submitted, approved: row.approved, cities: row.cities),
            joinedAt: row.joinedAt,
            blockedByMe: row.blockedByMe,
        )
    }

    func row(for account: String, fetchedAt: Date) -> PeopleProfile {
        PeopleProfile(
            id: id,
            accountID: account,
            name: name,
            username: username,
            bio: bio,
            avatarKey: avatar?.key,
            avatarThumbhash: avatar?.thumbhash,
            handles: Dictionary(uniqueKeysWithValues: handles.filled.map { ($0.network.rawValue, $0.value) }),
            role: role.rawValue,
            editorOf: editorOf.map { PeopleProfile.City(id: $0.id, name: $0.name) },
            submitted: stats.submitted,
            approved: stats.approved,
            cities: stats.cities,
            joinedAt: joinedAt,
            blockedByMe: blockedByMe,
            fetchedAt: fetchedAt,
        )
    }
}
