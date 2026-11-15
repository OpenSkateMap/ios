public import Foundation
public import Observation
public import PhotoUploadKit
public import SpotModelKit

@MainActor
@Observable
public final class CollectionsSession {

    // MARK: Computed Properties

    public var isSyncing: Bool {
        pullsRunning > 0
    }

    // MARK: Properties

    public private(set) var lastOutcome: CollectionsSync.Outcome?

    @ObservationIgnored private let sync: CollectionsSync
    @ObservationIgnored private let api: CollectionsAPIManager
    @ObservationIgnored private let photos: PhotoUploadManager
    @ObservationIgnored private let makePhotoID: @Sendable () -> String
    @ObservationIgnored private let accountID: @MainActor () -> String?
    private var pullsRunning = 0

    // MARK: Lifecycle

    public init(sync: CollectionsSync,
                api: CollectionsAPIManager,
                photos: PhotoUploadManager = .preview,
                makePhotoID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() },
                accountID: @escaping @MainActor () -> String?) {
        self.sync = sync
        self.api = api
        self.photos = photos
        self.makePhotoID = makePhotoID
        self.accountID = accountID
    }

    // MARK: Functions

    /// `joining`: launch and foreground take a pull already under way (`CollectionsSync.pull(joining:)`).
    public func syncNow(joining: Bool = false) async {
        pullsRunning += 1
        let outcome = await sync.pull(joining: joining)
        pullsRunning -= 1
        lastOutcome = outcome
    }

    @discardableResult
    public func create(_ draft: CollectionDraft) async throws -> String {
        let id = UUID().uuidString.lowercased()
        try await update(id, to: draft)
        return id
    }

    public func update(_ collectionID: String, to draft: CollectionDraft) async throws {
        let look: SavedLook? =
            if let draftLook = draft.look {
                try await uploaded(draftLook)
            } else {
                nil
            }
        try await apply { [api] in try await api.save(collectionID, draft, look) }
    }

    public func setStarred(_ starred: Bool, spotID: String) async throws {
        try await apply { [api] in try await api.star(spotID, starred) }
    }

    public func prepare(photo imageData: Data) async throws -> PreparedPhoto {
        try await photos.prepare(imageData)
    }

    public func delete(_ collectionID: String) async throws {
        try await api.delete(collectionID)
        try await sync.remove(collectionID)
        Task { await syncNow() }
    }

    public func add(_ spotID: String, to collectionID: String) async throws {
        try await apply { [api] in try await api.addSpot(spotID, collectionID) }
    }

    public func remove(_ spotID: String, from collectionID: String) async throws {
        try await apply { [api] in try await api.removeSpot(spotID, collectionID) }
    }

    public func leave(_ collectionID: String) async throws {
        guard let accountID = accountID() else {
            throw CollectionsAPIError.unauthorized
        }
        try await api.removeMember(accountID, collectionID)
        try await sync.remove(collectionID)
        Task { await syncNow() }
    }

    public func access(of collectionID: String) async throws -> CollectionAccess {
        try await api.access(collectionID)
    }

    public func share(_ collectionID: String,
                      with invitee: CollectionInvitee,
                      as role: CollectionMemberRole) async throws -> CollectionAccess {
        let access = try await api.share(collectionID, invitee, role)
        Task { await syncNow() }
        return access
    }

    public func setRole(_ role: CollectionMemberRole,
                        of userID: String,
                        in collectionID: String) async throws -> CollectionAccess {
        try await api.setRole(userID, collectionID, role)
    }

    public func removeMember(_ userID: String, from collectionID: String) async throws {
        try await api.removeMember(userID, collectionID)
        Task { await syncNow() }
    }

    public func cancelInvite(_ inviteID: String, to collectionID: String) async throws -> CollectionAccess {
        try await api.cancelInvite(inviteID, collectionID)
    }

    public func accept(invitationTo collectionID: String) async throws {
        let generation = await sync.generation
        let collection = try await api.acceptInvitation(collectionID)
        try await sync.answered(collectionID, joined: collection, requestedIn: generation)
        Task { await syncNow() }
    }

    public func decline(invitationTo collectionID: String) async throws {
        let generation = await sync.generation
        try await api.declineInvitation(collectionID)
        try await sync.answered(collectionID, joined: nil, requestedIn: generation)
        Task { await syncNow() }
    }

    public func requestAccess(to collectionID: String) async throws {
        let generation = await sync.generation
        try await api.requestAccess(collectionID)
        try await sync.requested(collectionID, requestedIn: generation)
    }

    public func approve(_ userID: String,
                        into collectionID: String,
                        as role: CollectionMemberRole) async throws -> CollectionAccess {
        let access = try await api.approveRequest(userID, collectionID, role)
        Task { await syncNow() }
        return access
    }

    public func decline(_ userID: String, askingFor collectionID: String) async throws -> CollectionAccess {
        try await api.declineRequest(userID, collectionID)
    }

    /// Cached, or fetched for one the account doesn't keep (a public link); `nil` when it can't be opened.
    public func focus(of collectionID: String) async -> CollectionFocus? {
        if let local = await sync.focus(of: collectionID) {
            return local
        }
        guard let page = try? await api.page(collectionID) else {
            return nil
        }
        let collection = page.collection
        return CollectionFocus(id: collection.id, name: collection.name, kind: collection.kind, spotIDs: collection.spotIDs)
    }

    public func page(of collectionID: String) async throws -> CollectionPage {
        try await api.page(collectionID)
    }

    public func spots(of collectionID: String, after cursor: String) async throws -> CollectionSpotsPage {
        try await api.spots(collectionID, cursor)
    }

    public func collections(of userID: String) async throws -> [RemoteCollection] {
        try await api.userCollections(userID)
    }

    private func uploaded(_ look: CollectionLookDraft) async throws -> SavedLook {
        let photo: SavedLook.Photo? =
            switch look.photo {
            case .none: nil
            case .kept(let photo): SavedLook.Photo(id: photo.id, thumbhash: photo.thumbhash)
            case .new(let prepared): try await upload(prepared)
            }
        return SavedLook(photo: photo)
    }

    private func upload(_ prepared: PreparedPhoto) async throws -> SavedLook.Photo {
        let id = makePhotoID()
        do {
            try await photos.upload(id, prepared.jpeg)
        } catch {
            throw CollectionsAPIError.unavailable
        }
        return SavedLook.Photo(id: id, thumbhash: prepared.thumbhash)
    }

    /// The answer is applied only if the account is still the one that asked.
    private func apply(_ write: () async throws -> RemoteCollection) async throws {
        let generation = await sync.generation
        let collection = try await write()
        try await sync.apply(collection, requestedIn: generation)
        Task { await syncNow() }
    }
}
