import APIClientKit
import Foundation
import PhotoUploadKit
import SpotModelKit
@testable import ContributionsKit

actor FakeContributionsServer {

    // MARK: Types

    enum Reachability {
        case online
        case offline
        case unavailable
    }

    /// What reached the server, in order.
    enum Request: Equatable {
        case photo(String)
        case clip(String)
        case save(String)
    }

    // MARK: Computed Properties

    nonisolated var api: ContributionsAPIManager {
        ContributionsAPIManager(
            save: { try await self.save($0, $1) },
            mySubmissions: { try await self.history() },
            nearby: { _, _, _ in [] },
            saveVideo: { try await self.saveVideo($0) },
        )
    }

    nonisolated var photos: PhotoUploadManager {
        PhotoUploadManager(
            prepare: { _ in PreparedPhoto(jpeg: Data(), width: 1, height: 1, thumbhash: "") },
            upload: { id, _ in try await self.upload(id) },
            uploadClip: { id, clip in try await self.uploadClip(id, Data(contentsOf: clip.file)) },
        )
    }

    nonisolated var historyHeld: AsyncStream<Void> {
        historyRequests.stream
    }

    nonisolated var uploadHeld: AsyncStream<Void> {
        uploadRequests.stream
    }

    // MARK: Properties

    var reachability = Reachability.online
    private(set) var uploads = [String: Int]()
    private(set) var requests = [Request]()
    /// Each clip's bytes as they arrived.
    private(set) var clips = [String: Data]()
    private(set) var saves = [String: Int]()
    private(set) var submissions = [String: MySubmission]()
    /// Each suggested edit's last save, as it goes on the wire.
    private(set) var sentEdits = [String: Components.Schemas.SpotEditDraft]()
    /// Each new spot's last save, as it goes on the wire.
    private(set) var sentSpots = [String: Components.Schemas.NewSpotDraft]()
    private(set) var videos = [String: VideoDraft]()
    private(set) var videoSaves = [String: Int]()

    private var storedPhotos = Set<String>()
    private var losesNextAnswer = false
    private var forgetsPhoto: String?
    private var forgetsClip: String?
    private var failsNextClip = false
    private var refusesNextClip: String?
    private var refusesNext: (status: Int, message: String)?
    private var approvesSaves = false
    private var garblesNextVideo = false
    private var holdsHistory = false
    private var heldHistory: CheckedContinuation<Void, Never>?
    private let historyRequests = AsyncStream<Void>.makeStream()
    private var holdsUpload = false
    private var heldUpload: CheckedContinuation<Void, any Error>?
    private let uploadRequests = AsyncStream<Void>.makeStream()

    // MARK: Functions

    func set(_ reachability: Reachability) {
        self.reachability = reachability
    }

    func loseNextAnswer() {
        losesNextAnswer = true
    }

    func forget(photo id: String) {
        forgetsPhoto = id
    }

    func forget(clip id: String) {
        forgetsClip = id
    }

    /// The next clip upload reaches the server and fails as a dropped connection would.
    func failNextClip() {
        failsNextClip = true
    }

    /// The next clip upload is refused for good, with the server's words.
    func refuseNextClip(because message: String) {
        refusesNextClip = message
    }

    func refuseNext(status: Int = 422, because message: String) {
        refusesNext = (status, message)
    }

    /// Answers every save as approved, as the server does for an admin; a private spot always is.
    func approveSaves() {
        approvesSaves = true
    }

    func garbleNextVideo() {
        garblesNextVideo = true
    }

    func holdNextHistory() {
        holdsHistory = true
    }

    func releaseHistory() {
        heldHistory?.resume()
        heldHistory = nil
    }

    /// The next upload waits until its task is cancelled, as a request in flight would, and then throws.
    func holdNextUpload() {
        holdsUpload = true
    }

    private func cancelHeldUpload() {
        heldUpload?.resume(throwing: CancellationError())
        heldUpload = nil
    }

    private func checkReachable() throws {
        switch reachability {
        case .online: return
        case .offline: throw ContributionsAPIError.offline
        case .unavailable: throw ContributionsAPIError.unavailable
        }
    }

    private func upload(_ id: String) async throws {
        switch reachability {
        case .online: break
        case .offline: throw PhotoUploadError.offline
        case .unavailable: throw PhotoUploadError.unavailable
        }
        if holdsUpload {
            holdsUpload = false
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    heldUpload = continuation
                    uploadRequests.continuation.yield()
                }
            } onCancel: {
                Task { await self.cancelHeldUpload() }
            }
        }
        requests.append(.photo(id))
        uploads[id, default: 0] += 1
        storedPhotos.insert(id)
    }

    private func uploadClip(_ id: String, _ mp4: Data) throws {
        switch reachability {
        case .online: break
        case .offline: throw PhotoUploadError.offline
        case .unavailable: throw PhotoUploadError.unavailable
        }
        requests.append(.clip(id))
        if failsNextClip {
            failsNextClip = false
            throw PhotoUploadError.offline
        }
        if let message = refusesNextClip {
            refusesNextClip = nil
            throw PhotoUploadError.rejected(status: 422, message: message)
        }
        clips[id] = mp4
    }

    private func save(_ draft: SubmissionDraft, _ photos: [DraftPhoto]) throws -> MySubmission {
        try checkReachable()
        requests.append(.save(draft.id))
        saves[draft.id, default: 0] += 1
        if let refusal = refusesNext {
            refusesNext = nil
            throw ContributionsAPIError.rejected(status: refusal.status, message: refusal.message)
        }
        if let forgotten = forgetsPhoto {
            forgetsPhoto = nil
            storedPhotos.remove(forgotten)
        }
        if let forgotten = forgetsClip {
            forgetsClip = nil
            clips[forgotten] = nil
        }
        let missing = photos.map(\.id).filter { !storedPhotos.contains($0) }
        guard missing.isEmpty else {
            throw ContributionsAPIError.missingPhotos(missing)
        }
        let missingClips = photos.compactMap(\.clip?.id).filter { clips[$0] == nil }
        guard missingClips.isEmpty else {
            throw ContributionsAPIError.missingClips(missingClips)
        }
        if let spotID = draft.editsSpotID {
            sentEdits[draft.id] = Components.Schemas.SpotEditDraft(draft, spotID: spotID, photos)
        } else {
            sentSpots[draft.id] = Components.Schemas.NewSpotDraft(draft, photos)
        }
        let saved = submissions[draft.id] ?? MySubmission(
            id: draft.id,
            title: draft.title,
            kind: draft.kind,
            cityID: nil,
            latitude: draft.latitude,
            longitude: draft.longitude,
            status: approvesSaves || draft.collectionID != nil ? .approved : .pending,
            rejectReason: nil,
            spotID: draft.editsSpotID,
            collectionID: draft.collectionID,
            changedFields: draft.changedFields,
            coverThumbhash: photos.first?.thumbhash,
            createdAt: draft.createdAt,
            updatedAt: draft.createdAt,
        )
        submissions[draft.id] = saved
        if losesNextAnswer {
            losesNextAnswer = false
            throw ContributionsAPIError.offline
        }
        return saved
    }

    private func saveVideo(_ draft: VideoDraft) throws {
        try checkReachable()
        videoSaves[draft.id, default: 0] += 1
        if garblesNextVideo {
            garblesNextVideo = false
            throw CocoaError(.coderReadCorrupt)
        }
        if let refusal = refusesNext {
            refusesNext = nil
            throw ContributionsAPIError.rejected(status: refusal.status, message: refusal.message)
        }
        videos[draft.id] = draft
    }

    private func history() async throws -> [MySubmission] {
        try checkReachable()
        let answer = submissions.values.sorted { $0.createdAt > $1.createdAt }
        if holdsHistory {
            holdsHistory = false
            await withCheckedContinuation { continuation in
                heldHistory = continuation
                historyRequests.continuation.yield()
            }
        }
        return answer
    }
}
