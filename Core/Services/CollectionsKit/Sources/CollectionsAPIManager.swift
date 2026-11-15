public import APIClientKit
import Foundation
public import OpenAPIRuntime
public import SpotModelKit
import SpotsKit

// MARK: - SavedLook

/// A look with its photo already uploaded, named by its id.
public struct SavedLook: Equatable, Sendable {
    public struct Photo: Equatable, Sendable {
        public var id: String
        public var thumbhash: String
    }

    public var photo: Photo?
}

// MARK: - CollectionsAPIManager

public struct CollectionsAPIManager: Sendable {
    public var snapshot: @Sendable () async throws -> CollectionsSnapshot
    public var page: @Sendable (_ id: String) async throws -> CollectionPage
    public var spots: @Sendable (_ id: String, _ cursor: String) async throws -> CollectionSpotsPage
    public var save: @Sendable (_ id: String, _ draft: CollectionDraft, _ look: SavedLook?) async throws -> RemoteCollection
    public var star: @Sendable (_ spotID: String, _ starred: Bool) async throws -> RemoteCollection
    public var delete: @Sendable (_ id: String) async throws -> Void
    public var addSpot: @Sendable (_ spotID: String, _ collectionID: String) async throws -> RemoteCollection
    public var removeSpot: @Sendable (_ spotID: String, _ collectionID: String) async throws -> RemoteCollection
    public var access: @Sendable (_ collectionID: String) async throws -> CollectionAccess
    public var share: @Sendable (_ collectionID: String, _ invitee: CollectionInvitee, _ role: CollectionMemberRole) async throws
        -> CollectionAccess
    public var setRole: @Sendable (_ userID: String, _ collectionID: String, _ role: CollectionMemberRole) async throws
        -> CollectionAccess
    public var removeMember: @Sendable (_ userID: String, _ collectionID: String) async throws -> Void
    public var cancelInvite: @Sendable (_ inviteID: String, _ collectionID: String) async throws -> CollectionAccess
    public var acceptInvitation: @Sendable (_ collectionID: String) async throws -> RemoteCollection
    public var declineInvitation: @Sendable (_ collectionID: String) async throws -> Void
    public var requestAccess: @Sendable (_ collectionID: String) async throws -> Void
    public var approveRequest: @Sendable (_ userID: String, _ collectionID: String, _ role: CollectionMemberRole) async throws
        -> CollectionAccess
    public var declineRequest: @Sendable (_ userID: String, _ collectionID: String) async throws -> CollectionAccess
    public var userCollections: @Sendable (_ userID: String) async throws -> [RemoteCollection]

    public init(snapshot: @escaping @Sendable () async throws -> CollectionsSnapshot,
                page: @escaping @Sendable (_ id: String) async throws -> CollectionPage,
                spots: @escaping @Sendable (_ id: String, _ cursor: String) async throws -> CollectionSpotsPage,
                save: @escaping @Sendable (_ id: String, _ draft: CollectionDraft, _ look: SavedLook?) async throws
                    -> RemoteCollection,
                star: @escaping @Sendable (_ spotID: String, _ starred: Bool) async throws -> RemoteCollection,
                delete: @escaping @Sendable (_ id: String) async throws -> Void,
                addSpot: @escaping @Sendable (_ spotID: String, _ collectionID: String) async throws -> RemoteCollection,
                removeSpot: @escaping @Sendable (_ spotID: String, _ collectionID: String) async throws -> RemoteCollection,
                access: @escaping @Sendable (_ collectionID: String) async throws -> CollectionAccess,
                share: @escaping @Sendable (_ collectionID: String, _ invitee: CollectionInvitee, _ role: CollectionMemberRole)
                async throws -> CollectionAccess,
                setRole: @escaping @Sendable (_ userID: String, _ collectionID: String, _ role: CollectionMemberRole) async throws
                    -> CollectionAccess,
                removeMember: @escaping @Sendable (_ userID: String, _ collectionID: String) async throws -> Void,
                cancelInvite: @escaping @Sendable (_ inviteID: String, _ collectionID: String) async throws -> CollectionAccess,
                acceptInvitation: @escaping @Sendable (_ collectionID: String) async throws -> RemoteCollection,
                declineInvitation: @escaping @Sendable (_ collectionID: String) async throws -> Void,
                requestAccess: @escaping @Sendable (_ collectionID: String) async throws -> Void,
                approveRequest: @escaping @Sendable (_ userID: String, _ collectionID: String, _ role: CollectionMemberRole)
                async throws -> CollectionAccess,
                declineRequest: @escaping @Sendable (_ userID: String, _ collectionID: String) async throws -> CollectionAccess,
                userCollections: @escaping @Sendable (_ userID: String) async throws -> [RemoteCollection]) {
        self.snapshot = snapshot
        self.page = page
        self.spots = spots
        self.save = save
        self.star = star
        self.delete = delete
        self.addSpot = addSpot
        self.removeSpot = removeSpot
        self.access = access
        self.share = share
        self.setRole = setRole
        self.removeMember = removeMember
        self.cancelInvite = cancelInvite
        self.acceptInvitation = acceptInvitation
        self.declineInvitation = declineInvitation
        self.requestAccess = requestAccess
        self.approveRequest = approveRequest
        self.declineRequest = declineRequest
        self.userCollections = userCollections
    }
}

extension CollectionsAPIManager {
    public static func live(credentials: SessionCredentials,
                            makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> CollectionsAPIManager {
        @Sendable
        func call<Output>(_ call: (Client) async throws -> Output) async throws -> Output {
            try await credentials.authorized(
                makeClient,
                signedOut: CollectionsAPIError.unauthorized,
                offline: CollectionsAPIError.offline,
                failure: CollectionsAPIError.init,
                call,
            )
        }

        return CollectionsAPIManager(
            snapshot: { try await CollectionsSnapshot(call { try await $0.getMyCollections().ok.body.json.data }) },
            page: { id in
                try await CollectionPage(call { try await $0.getCollection(path: .init(collectionId: id)).ok.body.json.data })
            },
            spots: { id, cursor in
                try await CollectionSpotsPage(call {
                    try await $0.getCollectionSpots(path: .init(collectionId: id), query: .init(cursor: cursor)).ok.body.json.data
                })
            },
            save: { id, draft, look in
                let body = Components.Schemas.CollectionDraft(
                    name: draft.name,
                    description: draft.about,
                    visibility: .init(draft.visibility),
                    appearance: look.map(Components.Schemas.CollectionAppearanceDraft.init),
                )
                return try await RemoteCollection(call {
                    try await $0.saveCollection(path: .init(collectionId: id), body: .json(body)).ok.body.json.data
                })
            },
            star: { spotID, starred in
                if starred {
                    try await RemoteCollection(call { try await $0.starSpot(path: .init(spotId: spotID)).ok.body.json.data })
                } else {
                    try await RemoteCollection(call { try await $0.unstarSpot(path: .init(spotId: spotID)).ok.body.json.data })
                }
            },
            delete: { id in _ = try await call { try await $0.deleteCollection(path: .init(collectionId: id)).ok } },
            addSpot: { spotID, collectionID in
                try await RemoteCollection(call {
                    try await $0.addSpotToCollection(path: .init(collectionId: collectionID, spotId: spotID)).ok.body.json.data
                })
            },
            removeSpot: { spotID, collectionID in
                try await RemoteCollection(call {
                    try await $0.removeSpotFromCollection(path: .init(collectionId: collectionID, spotId: spotID)).ok.body.json
                        .data
                })
            },
            access: { id in
                try await CollectionAccess(call {
                    try await $0.getCollectionAccess(path: .init(collectionId: id)).ok.body.json.data
                })
            },
            share: { id, invitee, role in
                let body =
                    switch invitee {
                    case .username(let username): Components.Schemas.CollectionInviteDraft(username: username, role: .init(role))
                    case .email(let email): Components.Schemas.CollectionInviteDraft(email: email, role: .init(role))
                    }
                return try await CollectionAccess(call {
                    try await $0.shareCollection(path: .init(collectionId: id), body: .json(body)).ok.body.json.data
                })
            },
            setRole: { userID, collectionID, role in
                try await CollectionAccess(call {
                    try await $0.setCollectionMemberRole(
                        path: .init(collectionId: collectionID, userId: userID),
                        body: .json(.init(role: .init(role))),
                    ).ok.body.json.data
                })
            },
            removeMember: { userID, collectionID in
                _ = try await call {
                    try await $0.removeCollectionMember(path: .init(collectionId: collectionID, userId: userID)).ok
                }
            },
            cancelInvite: { inviteID, collectionID in
                try await CollectionAccess(call {
                    try await $0.cancelCollectionInvite(path: .init(collectionId: collectionID, inviteId: inviteID)).ok.body.json
                        .data
                })
            },
            acceptInvitation: { id in
                try await RemoteCollection(call {
                    try await $0.acceptCollectionInvitation(path: .init(collectionId: id)).ok.body.json.data
                })
            },
            declineInvitation: { id in
                _ = try await call { try await $0.declineCollectionInvitation(path: .init(collectionId: id)).ok }
            },
            requestAccess: { id in
                _ = try await call { try await $0.requestCollectionAccess(path: .init(collectionId: id)).ok }
            },
            approveRequest: { userID, collectionID, role in
                try await CollectionAccess(call {
                    try await $0.approveCollectionRequest(
                        path: .init(collectionId: collectionID, userId: userID),
                        body: .json(.init(role: .init(role))),
                    ).ok.body.json.data
                })
            },
            declineRequest: { userID, collectionID in
                try await CollectionAccess(call {
                    try await $0.declineCollectionRequest(path: .init(collectionId: collectionID, userId: userID)).ok.body.json
                        .data
                })
            },
            userCollections: { userID in
                try await call { try await $0.getUserCollections(path: .init(userId: userID)).ok.body.json.data }.collections
                    .map(RemoteCollection.init)
            },
        )
    }

    public static let preview = CollectionsAPIManager(
        snapshot: { CollectionsSnapshot(collections: [], privateSpots: []) },
        page: { _ in throw CollectionsAPIError.notFound },
        spots: { _, _ in throw CollectionsAPIError.notFound },
        save: { id, draft, _ in
            RemoteCollection(
                id: id,
                name: draft.name,
                about: draft.about,
                visibility: draft.visibility,
                look: CollectionLook(color: .blue),
                role: .owner,
                ownerID: "preview",
                ownerName: "Preview Skater",
                ownerUsername: nil,
                spotIDs: [],
                memberCount: 0,
                coverKey: nil,
                coverThumbhash: nil,
                createdAt: .now,
                updatedAt: .now,
            )
        },
        star: { _, _ in throw CollectionsAPIError.notFound },
        delete: { _ in },
        addSpot: { _, _ in throw CollectionsAPIError.notFound },
        removeSpot: { _, _ in throw CollectionsAPIError.notFound },
        access: { _ in .preview },
        share: { _, _, _ in .preview },
        setRole: { _, _, _ in .preview },
        removeMember: { _, _ in },
        cancelInvite: { _, _ in .preview },
        acceptInvitation: { _ in throw CollectionsAPIError.notFound },
        declineInvitation: { _ in },
        requestAccess: { _ in },
        approveRequest: { _, _, _ in .preview },
        declineRequest: { _, _ in .preview },
        userCollections: { _ in [] },
    )
}

// MARK: - Mapping

extension CollectionVisibility {
    init(_ visibility: Components.Schemas.CollectionVisibility) {
        switch visibility {
        case ._private: self = .private
        case ._public: self = .public
        }
    }
}

extension Components.Schemas.CollectionVisibility {
    init(_ visibility: CollectionVisibility) {
        switch visibility {
        case .private: self = ._private
        case .public: self = ._public
        }
    }
}

extension RemoteCollection {
    init(_ collection: Components.Schemas.Collection) {
        let appearance = collection.appearance
        self.init(
            id: collection.id,
            name: collection.name,
            about: collection.description,
            visibility: CollectionVisibility(collection.visibility),
            kind: CollectionKind(rawValue: collection.kind.rawValue) ?? .custom,
            look: CollectionLook(
                color: CollectionColor(rawValue: appearance.color.rawValue) ?? .blue,
                photo: appearance.photo.map { CollectionPhoto(id: $0.id, key: $0.key, thumbhash: $0.thumbhash) },
            ),
            role: CollectionRole(collection.role),
            ownerID: collection.owner.id,
            ownerName: collection.owner.name,
            ownerUsername: collection.owner.username,
            spotIDs: collection.spotIds,
            memberCount: collection.memberCount,
            coverKey: collection.cover?.key,
            coverThumbhash: collection.cover?.thumbhash,
            createdAt: collection.createdAt,
            updatedAt: collection.updatedAt,
        )
    }
}

extension CollectionRole {
    init(_ role: Components.Schemas.CollectionRole) {
        switch role {
        case .owner: self = .owner
        case .admin: self = .admin
        case .editor: self = .editor
        case .viewer: self = .viewer
        case .guest: self = .guest
        }
    }
}

extension CollectionMemberRole {
    init(_ role: Components.Schemas.CollectionMemberRole) {
        switch role {
        case .viewer: self = .viewer
        case .editor: self = .editor
        case .admin: self = .admin
        }
    }
}

extension Components.Schemas.CollectionMemberRole {
    init(_ role: CollectionMemberRole) {
        switch role {
        case .viewer: self = .viewer
        case .editor: self = .editor
        case .admin: self = .admin
        }
    }
}

extension CollectionsSnapshot {
    init(_ snapshot: Components.Schemas.CollectionsSnapshot) {
        self.init(
            collections: snapshot.collections.map(RemoteCollection.init),
            invitations: snapshot.invitations.enumerated().map { position, invitation in
                CollectionInvitation(
                    collectionID: invitation.collectionId,
                    name: invitation.name,
                    ownerID: invitation.owner.id,
                    ownerName: invitation.owner.name,
                    ownerUsername: invitation.owner.username,
                    role: CollectionMemberRole(invitation.role),
                    inviterName: invitation.invitedBy?.value1.name,
                    position: position,
                    createdAt: invitation.createdAt,
                )
            },
            requestedIDs: snapshot.requestedIds,
            privateSpots: snapshot.privateSpots.map(SpotIndex.init),
        )
    }
}

extension CollectionPage {
    init(_ page: Components.Schemas.CollectionPage) {
        self.init(
            collection: RemoteCollection(page.collection),
            spots: CollectionSpotsPage(spots: page.spots.map(SpotIndex.init), nextCursor: page.nextCursor),
        )
    }
}

extension CollectionSpotsPage {
    init(_ page: Components.Schemas.CollectionSpotsPage) {
        self.init(spots: page.items.map(SpotIndex.init), nextCursor: page.nextCursor)
    }
}

extension CollectionAccess {
    public static let preview = CollectionAccess(
        visibility: .private,
        owner: Person(id: "preview", name: "Preview Skater", username: nil, avatarKey: nil, avatarThumbhash: nil),
        members: [],
        invites: [],
        requests: [],
    )

    init(_ access: Components.Schemas.CollectionAccess) {
        self.init(
            visibility: CollectionVisibility(access.visibility),
            owner: Person(access.owner),
            members: access.members
                .map { Member(person: Person($0.user), role: CollectionMemberRole($0.role), addedAt: $0.addedAt) },
            invites: access.invites.map { invite in
                Invite(
                    id: invite.id,
                    email: invite.email,
                    person: invite.user.map { Person($0.value1) },
                    role: CollectionMemberRole(invite.role),
                    createdAt: invite.createdAt,
                )
            },
            requests: access.requests.map { Request(person: Person($0.user), createdAt: $0.createdAt) },
        )
    }
}

extension CollectionAccess.Person {
    init(_ person: Components.Schemas.CollectionPerson) {
        self.init(
            id: person.id,
            name: person.name,
            username: person.username,
            avatarKey: person.avatar?.key,
            avatarThumbhash: person.avatar?.thumbhash,
        )
    }
}

extension Components.Schemas.CollectionAppearanceDraft {
    init(_ look: SavedLook) {
        self.init(
            photo: look.photo.map { .init(photoId: $0.id, thumbhash: $0.thumbhash) }
        )
    }
}
