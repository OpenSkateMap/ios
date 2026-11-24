import AccountKit
import CollectionsKit
import ContributionsKit
import FactoryKit
import Foundation
import IdentifiedCollections
import Observation
import os
import PhotoUploadKit
import ReviewKit
import SpotModelKit
import SQLiteData

@MainActor
@Observable
final class NewSpotModel {

    // MARK: Types

    enum Submission: Equatable {
        case saved(id: String)
        case approved
        /// The card left the queue or is newer than what's on screen: these edits can't go out again.
        case cardChanged
        case busy
        case failed
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "new-spot")

    // MARK: Computed Properties

    var destinationName: String? {
        form.collectionID.flatMap { id in privateCollections.first { $0.id == id }?.name }
    }

    var isEditing: Bool {
        if case .edit = form.mode {
            true
        } else {
            false
        }
    }

    /// Whether what's sent waits for a curator; an approval is a curator's own decision.
    var goesToCurators: Bool {
        switch form.mode {
        case .new, .edit: form.collectionID == nil && !authSession.isAdmin
        case .review: false
        }
    }

    /// An approval is out, or over and the sheet is closing on it.
    var isApproving: Bool {
        if case .review = form.mode {
            isSubmitting || isReviewOver
        } else {
            false
        }
    }

    var canSubmit: Bool {
        form.canSubmit && !isSubmitting && !isCreatingCollection
    }

    private var looksUpNearby: Bool {
        switch form.mode {
        case .new: true
        case .edit: false
        case .review(let card): !card.isEdit
        }
    }

    // MARK: Properties

    private(set) var form: NewSpotForm
    private(set) var nearby = [NearbySpot]()
    private(set) var isSubmitting = false
    /// A new private collection is on its way: the spot can't go anywhere until it lands.
    private(set) var isCreatingCollection = false

    @ObservationIgnored
    @FetchAll(
        SpotCollection
            .where { $0.role.eq(CollectionRole.owner) && $0.visibility.eq(CollectionVisibility.private) }
            .order { $0.position }
    ) var privateCollections: [SpotCollection]

    private var isReviewOver = false

    @ObservationIgnored @Injected(\.contributionsSession) private var session
    @ObservationIgnored @Injected(\.authSession) private var authSession
    @ObservationIgnored @LazyInjected(\.collectionsSession) private var collections
    @ObservationIgnored @LazyInjected(\.reviewSession) private var reviews
    @ObservationIgnored @LazyInjected(\.clipPreparer) private var clips
    @ObservationIgnored private var preparing = [UUID: Task<Void, any Error>]()
    @ObservationIgnored private var loadingNearby: Task<Void, Never>?

    // MARK: Lifecycle

    init(editing spot: SpotEditTarget? = nil) {
        form = spot.map(NewSpotForm.init(editing:)) ?? NewSpotForm()
    }

    init(reviewing card: ReviewCard) {
        form = NewSpotForm(reviewing: card)
        nearby = card.nearby
    }

    isolated deinit {
        for task in preparing.values {
            task.cancel()
        }
        loadingNearby?.cancel()
        removeClipFiles()
    }

    // MARK: Static Functions

    private static func removeFile(_ file: URL) {
        try? FileManager.default.removeItem(at: file)
    }

    // MARK: Functions

    func edit(_ change: (inout NewSpotForm) -> Void) {
        change(&form)
    }

    func createPrivateCollection(named name: String) async throws {
        isCreatingCollection = true
        defer { isCreatingCollection = false }
        let id = try await collections.create(CollectionDraft(name: name, visibility: .private))
        form.collectionID = id
    }

    func addPhotos(_ files: [Data?]) {
        for (id, data) in zip(beginPhotos(files.count), files) {
            fillPhoto(id, with: data)
        }
    }

    /// Tiles for photos still loading from the picker, as many as fit; each shows as preparing until `fillPhoto`.
    func beginPhotos(_ count: Int) -> [UUID] {
        var ids = [UUID]()
        for _ in 0..<count {
            let photo = NewSpotForm.Photo()
            guard form.append(photo) else {
                break
            }
            ids.append(photo.id)
        }
        return ids
    }

    func fillPhoto(_ id: UUID, with data: Data?) {
        guard form.photos[id: id] != nil else {
            return
        }
        guard let data else {
            form.updateAddedPhoto(id) { $0.state = .failed }
            return
        }
        preparing[id] = Task<Void, any Error> { [session] in
            let state: NewSpotForm.Photo.Added.State
            do {
                state = try await .ready(session.prepare(data))
            } catch {
                Self.logger.error("A photo couldn't be prepared: \(String(describing: type(of: error)), privacy: .public)")
                state = .failed
            }
            self.form.updateAddedPhoto(id) { $0.state = state }
            self.preparing[id] = nil
        }
    }

    /// The trimmed video `source`, `duration` seconds long, as the photo `id`: its clip, and the frame at `cover` seconds
    /// as the photo. A clip that can't be made takes its tile away and throws why; `source` stays the caller's.
    func fillClip(_ id: UUID, from source: URL, duration: Double, coverAt cover: Double) async throws {
        guard form.photos[id: id] != nil else {
            return
        }
        let task = Task<Void, any Error> { [clips] in
            do {
                async let clip = clips.prepare(source, 0, duration)
                async let poster = clips.poster(source, cover)
                let (prepared, frame) = try await (clip, poster)
                guard !Task.isCancelled, self.form.photos[id: id] != nil else {
                    Self.removeFile(prepared.file)
                    throw CancellationError()
                }
                self.form.updateAddedPhoto(id) {
                    $0.state = .ready(frame)
                    $0.clip = prepared
                }
            } catch {
                // A cancelled encode may fail with an error of its own.
                if error is CancellationError || Task.isCancelled {
                    throw CancellationError()
                }
                Self.logger.error("A clip couldn't be prepared: \(String(describing: error), privacy: .public)")
                self.form.removePhoto(id)
                throw error
            }
        }
        preparing[id] = task
        defer {
            if preparing[id] == task {
                preparing[id] = nil
            }
        }
        try await task.value
    }

    func removePhoto(_ id: UUID) {
        preparing[id]?.cancel()
        preparing[id] = nil
        if let clip = form.photos[id: id]?.added?.clip {
            Self.removeFile(clip.file)
        }
        form.removePhoto(id)
    }

    func setLocation(_ location: NewSpotForm.Location) {
        form.location = location
        nearby = []
        loadingNearby?.cancel()
        guard looksUpNearby else {
            return
        }
        loadingNearby = Task { [session] in
            let found = await session.nearbySpots(latitude: location.latitude, longitude: location.longitude)
            guard !Task.isCancelled, self.form.location == location else {
                return
            }
            self.nearby = found
        }
    }

    func submit() async -> Submission {
        guard !isSubmitting, !isCreatingCollection else {
            return .busy
        }
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            switch form.mode {
            case .new:
                guard let spot = form.spot() else {
                    return .failed
                }
                return try await .saved(id: session.submit(spot))

            case .edit:
                guard let edit = form.suggestion() else {
                    return .failed
                }
                return try await .saved(id: session.suggest(edit))

            case .review(let card):
                guard let edits = form.approval() else {
                    return .failed
                }
                if await reviews.approve(card.id, edits: edits, seenUpdatedAt: card.updatedAt) {
                    isReviewOver = true
                    return .approved
                }
                guard reviews.cards[id: card.id]?.updatedAt == card.updatedAt else {
                    isReviewOver = true
                    return .cardChanged
                }
                return .failed
            }
        } catch {
            Self.logger.error("The spot couldn't be saved: \(String(describing: type(of: error)), privacy: .public)")
            return .failed
        }
    }

    func reset() {
        for task in preparing.values {
            task.cancel()
        }
        preparing = [:]
        loadingNearby?.cancel()
        removeClipFiles()
        form = NewSpotForm()
        nearby = []
    }

    /// The form's clips are its own until the outbox moves them into its files on submit.
    private func removeClipFiles() {
        for photo in form.photos {
            if let clip = photo.added?.clip {
                Self.removeFile(clip.file)
            }
        }
    }
}
