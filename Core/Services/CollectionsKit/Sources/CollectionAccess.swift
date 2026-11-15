public import Foundation
public import IdentifiedCollections
public import SpotModelKit

// MARK: - CollectionAccess

/// Invites and requests come only to the owner and admins.
public struct CollectionAccess: Equatable, Sendable {
    public struct Person: Equatable, Identifiable, Sendable {
        public var id: String
        public var name: String
        public var username: String?
        public var avatarKey: String?
        public var avatarThumbhash: String?

        public init(id: String, name: String, username: String?, avatarKey: String?, avatarThumbhash: String?) {
            self.id = id
            self.name = name
            self.username = username
            self.avatarKey = avatarKey
            self.avatarThumbhash = avatarThumbhash
        }
    }

    public struct Member: Equatable, Identifiable, Sendable {
        public var id: String {
            person.id
        }

        public var person: Person
        public var role: CollectionMemberRole
        public var addedAt: Date

        public init(person: Person, role: CollectionMemberRole, addedAt: Date) {
            self.person = person
            self.role = role
            self.addedAt = addedAt
        }
    }

    /// By @username: `person`; by email: only `email`.
    public struct Invite: Equatable, Identifiable, Sendable {
        public var id: String
        public var email: String?
        public var person: Person?
        public var role: CollectionMemberRole
        public var createdAt: Date

        public init(id: String, email: String?, person: Person?, role: CollectionMemberRole, createdAt: Date) {
            self.id = id
            self.email = email
            self.person = person
            self.role = role
            self.createdAt = createdAt
        }
    }

    public struct Request: Equatable, Identifiable, Sendable {
        public var id: String {
            person.id
        }

        public var person: Person
        public var createdAt: Date

        public init(person: Person, createdAt: Date) {
            self.person = person
            self.createdAt = createdAt
        }
    }

    public var visibility: CollectionVisibility
    public var owner: Person
    public var members: IdentifiedArrayOf<Member>
    public var invites: IdentifiedArrayOf<Invite>
    public var requests: IdentifiedArrayOf<Request>

    public init(visibility: CollectionVisibility, owner: Person, members: [Member], invites: [Invite], requests: [Request]) {
        self.visibility = visibility
        self.owner = owner
        self.members = IdentifiedArray(members) { first, _ in first }
        self.invites = IdentifiedArray(invites) { first, _ in first }
        self.requests = IdentifiedArray(requests) { first, _ in first }
    }
}

// MARK: - CollectionInvitee

public enum CollectionInvitee: Equatable, Sendable {
    case username(String)
    case email(String)

    // MARK: Lifecycle

    public init?(typed: String) {
        let text = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return nil
        }
        if text.dropFirst().contains("@") {
            self = .email(text)
        } else {
            let name = text.hasPrefix("@") ? String(text.dropFirst()) : text
            guard !name.isEmpty else {
                return nil
            }
            self = .username(name)
        }
    }
}
