import APIClientKit
public import Foundation
public import Observation
public import PhotoUploadKit

@MainActor
@Observable
public final class ProfileSession {

    // MARK: Computed Properties

    public var accountID: String? {
        viewerID()
    }

    // MARK: Properties

    @ObservationIgnored private let api: PeopleAPIManager
    @ObservationIgnored private let photos: PhotoUploadManager
    @ObservationIgnored private let store: PeopleStore
    @ObservationIgnored private let viewerID: @MainActor () -> String?
    @ObservationIgnored private let blocksChanged: BlocksChangedHandler
    @ObservationIgnored private let makePhotoID: @Sendable () -> String
    @ObservationIgnored private var loading = [String: Task<PublicProfile, any Error>]()
    @ObservationIgnored private var uploadedAvatar: (jpeg: Data, avatar: ProfileUpdate.AvatarUpload)?

    // MARK: Lifecycle

    public init(api: PeopleAPIManager,
                photos: PhotoUploadManager,
                store: PeopleStore,
                viewerID: @escaping @MainActor () -> String?,
                blocksChanged: BlocksChangedHandler = .none,
                makePhotoID: @escaping @Sendable () -> String = { UUID().uuidString.lowercased() }) {
        self.api = api
        self.photos = photos
        self.store = store
        self.viewerID = viewerID
        self.blocksChanged = blocksChanged
        self.makePhotoID = makePhotoID
    }

    // MARK: Static Functions

    private static func peopleError(_ error: any Error) -> any Error {
        switch error as? PhotoUploadError {
        case .unauthorized: PeopleAPIError.unauthorized
        case .offline: PeopleAPIError.offline
        case .unavailable: PeopleAPIError.unavailable
        case .rejected(let message): PeopleAPIError.rejected(message)
        case .refused(let status): PeopleAPIError(APIFailure(status: status))
        case nil: error
        }
    }

    // MARK: Functions

    @discardableResult
    public func load(_ userID: String) async throws -> PublicProfile {
        if let loading = loading[userID] {
            return try await loading.value
        }
        guard let account = viewerID() else {
            throw PeopleAPIError.unauthorized
        }
        let task = Task { [api, store] in
            let generation = await store.generation
            do {
                let profile = try await api.profile(userID)
                await store.save(profile, for: account, from: generation)
                return profile
            } catch PeopleAPIError.notFound {
                await store.forget(userID, for: account, from: generation)
                throw PeopleAPIError.notFound
            }
        }
        loading[userID] = task
        defer { loading[userID] = nil }
        return try await task.value
    }

    public func prepareAvatar(_ imageData: Data) async throws -> PreparedPhoto {
        try await photos.prepare(imageData)
    }

    public func save(_ draft: ProfileDraft, over profile: PublicProfile) async throws -> PublicProfile {
        guard let account = viewerID() else {
            throw PeopleAPIError.unauthorized
        }
        let generation = await store.generation
        var update = ProfileUpdate(from: profile, to: draft)
        if case .replaced(let photo) = draft.avatar {
            update.avatar = try await upload(photo)
        }
        guard !update.isEmpty else {
            return profile
        }
        let saved = try await api.updateMyProfile(update)
        await store.save(saved, for: account, from: generation)
        uploadedAvatar = nil
        return saved
    }

    public func loadBlockedUsers() async throws {
        guard let account = viewerID() else {
            throw PeopleAPIError.unauthorized
        }
        let generation = await store.generation
        let users = try await api.blockedUsers()
        await store.replaceBlocked(users, for: account, from: generation)
    }

    public func setBlocked(_ userID: String, _ blocked: Bool) async throws {
        guard let account = viewerID() else {
            throw PeopleAPIError.unauthorized
        }
        let generation = await store.generation
        try await api.setBlocked(userID, blocked)
        await store.setBlocked(userID, blocked, for: account, from: generation)
        await blocksChanged.run()
    }

    public func report(_ report: Report) async throws {
        try await api.report(report)
    }

    private func upload(_ photo: PreparedPhoto) async throws -> ProfileUpdate.AvatarUpload {
        if let uploadedAvatar, uploadedAvatar.jpeg == photo.jpeg {
            return uploadedAvatar.avatar
        }
        let photoID = makePhotoID()
        do {
            try await photos.upload(photoID, photo.jpeg)
        } catch {
            throw Self.peopleError(error)
        }
        let avatar = ProfileUpdate.AvatarUpload(photoID: photoID, thumbhash: photo.thumbhash)
        uploadedAvatar = (photo.jpeg, avatar)
        return avatar
    }
}
