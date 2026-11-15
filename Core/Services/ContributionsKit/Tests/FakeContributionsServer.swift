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
    private(set) var saves = [String: Int]()
    private(set) var submissions = [String: MySubmission]()
    /// Each suggested edit's last save, as it goes on the wire.
    private(set) var sentEdits = [String: Components.Schemas.SpotEditDraft]()
    private(set) var videos = [String: VideoDraft]()
    private(set) var videoSaves = [String: Int]()

    private var storedPhotos = Set<String>()
    private var losesNextAnswer = false
    private var forgetsPhoto: String?
    private var refusesNext: String?
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

    func refuseNext(because reason: String) {
        refusesNext = reason
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
        uploads[id, default: 0] += 1
        storedPhotos.insert(id)
    }

    private func save(_ draft: SubmissionDraft, _ photos: [DraftPhoto]) throws -> MySubmission {
        try checkReachable()
        saves[draft.id, default: 0] += 1
        if let reason = refusesNext {
            refusesNext = nil
            throw ContributionsAPIError.rejected(reason)
        }
        if let forgotten = forgetsPhoto {
            forgetsPhoto = nil
            storedPhotos.remove(forgotten)
        }
        let missing = photos.map(\.id).filter { !storedPhotos.contains($0) }
        guard missing.isEmpty else {
            throw ContributionsAPIError.missingPhotos(missing)
        }
        if let spotID = draft.editsSpotID {
            sentEdits[draft.id] = Components.Schemas.SpotEditDraft(draft, spotID: spotID, photos)
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
        if let reason = refusesNext {
            refusesNext = nil
            throw ContributionsAPIError.rejected(reason)
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
