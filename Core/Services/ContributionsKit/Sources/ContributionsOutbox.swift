public import Foundation
import os
public import PhotoUploadKit
public import SpotModelKit
public import SQLiteData

// MARK: - ContributionsOutbox

public actor ContributionsOutbox {

    // MARK: Types

    private enum SendOutcome {
        case sent
        case refused
        case again
        case stop
    }

    // MARK: Static Properties

    public static let nearbyRadiusMeters = 150

    private static let orphanAge: TimeInterval = 10 * 60

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "outbox")

    // MARK: Properties

    private(set) var generation = 0

    private(set) var scheduledWakeup: Duration?

    private let api: ContributionsAPIManager
    private let photos: PhotoUploadManager
    private let database: any DatabaseWriter
    private let files: OutboxFiles
    private let spotPublished: PublishedSpotHandler
    private let backgroundTime: BackgroundTime
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date
    private let jitter: @Sendable () -> Double
    private var draining: Task<Void, Never>?
    private var drainAgain = false
    private var hasResumed = false
    private var wakeup: Task<Void, Never>?
    /// Photos and clips sent again this pass because the server said it hadn't got them.
    private var reuploaded = Set<String>()
    private var shown: ShownProgress?

    // MARK: Lifecycle

    public init(api: ContributionsAPIManager,
                photos: PhotoUploadManager,
                database: any DatabaseWriter,
                files: OutboxFiles,
                spotPublished: PublishedSpotHandler = .none,
                backgroundTime: BackgroundTime = .none,
                clock: any Clock<Duration> = ContinuousClock(),
                now: @escaping @Sendable () -> Date = Date.init,
                jitter: @escaping @Sendable () -> Double = { Double.random(in: 0.5...1) }) {
        self.api = api
        self.photos = photos
        self.database = database
        self.files = files
        self.spotPublished = spotPublished
        self.backgroundTime = backgroundTime
        self.clock = clock
        self.now = now
        self.jitter = jitter
    }

    // MARK: Static Functions

    static func backoff(afterAttempts attempts: Int, jitter: Double) -> Duration {
        let seconds = min(60, pow(2, Double(max(0, attempts - 1))))
        return .milliseconds(Int((seconds * jitter * 1000).rounded()))
    }

    // MARK: Functions

    @discardableResult
    public func add(_ spot: NewSpot) async throws -> String {
        try await insert(spot, editing: nil, changedFields: [], photos: spot.photos.map { .added($0) }, base: nil)
    }

    @discardableResult
    public func add(_ edit: SpotEditSuggestion) async throws -> String {
        try await insert(
            edit.proposed,
            editing: edit.spotID,
            changedFields: edit.changedFields,
            photos: edit.photoEdit?.order ?? [],
            base: edit.photoEdit?.base,
        )
    }

    @discardableResult
    public func addVideo(spotID: String, url: String, caption: String) async throws -> String {
        let draft = VideoDraft(id: UUID().uuidString.lowercased(), spotID: spotID, url: url, caption: caption, createdAt: now())
        try await database.write { db in
            try VideoDraft.insert { draft }.execute(db)
        }
        kick()
        return draft.id
    }

    public func retryVideo(_ id: String) async throws {
        try await database.write { db in
            try VideoDraft
                .where { $0.id.eq(id) && $0.status.eq(OutboxStatus.failed) }
                .update {
                    $0.status = #bind(OutboxStatus.pending)
                    $0.problem = #bind(OutboxProblem?.none)
                    $0.attempts = #bind(0)
                    $0.nextAttemptAt = #bind(Date?.none)
                }
                .execute(db)
        }
        kick()
    }

    public func discardVideo(_ id: String) async throws {
        try await database.write { db in
            try VideoDraft.where { $0.id.eq(id) && $0.status.neq(OutboxStatus.uploading) }.delete().execute(db)
        }
    }

    public func retry(_ id: String) async throws {
        let hasPhotosToSend = try await database.write { db in
            try SubmissionDraft
                .where { $0.id.eq(id) && $0.status.eq(OutboxStatus.failed) }
                .update {
                    $0.status = #bind(OutboxStatus.pending)
                    $0.problem = #bind(OutboxProblem?.none)
                    $0.attempts = #bind(0)
                    $0.nextAttemptAt = #bind(Date?.none)
                }
                .execute(db)
            return try DraftPhoto.where { $0.draftID.eq(id) }.fetchAll(db).contains { !$0.isFullyUploaded }
        }
        kick(showingProgress: hasPhotosToSend)
    }

    /// False when it's already uploading, or gone: an upload in flight isn't taken back.
    @discardableResult
    public func discard(_ id: String) async throws -> Bool {
        let fileNames = try await database.write { db -> [String]? in
            guard let draft = try SubmissionDraft.find(id).fetchOne(db), draft.status != .uploading else {
                return nil
            }
            let names = try DraftPhoto.where { $0.draftID.eq(id) }.fetchAll(db).flatMap(\.fileNames)
            try SubmissionDraft.find(id).delete().execute(db)
            return names
        }
        guard let fileNames else {
            return false
        }
        files.remove(fileNames)
        return true
    }

    public func start() {
        kick()
    }

    public func kick() {
        kick(showingProgress: false)
    }

    @discardableResult
    public func refreshHistory() async -> Bool {
        let generation = generation
        do {
            let known = try await database.read { db in try MySubmission.select(\.id).fetchAll(db) }
            let rows = try await api.mySubmissions()
            guard generation == self.generation else {
                return false
            }
            let listed = Set(rows.map(\.id))
            let gone = known.filter { !listed.contains($0) }
            try await database.write { db in
                if !gone.isEmpty {
                    try MySubmission.where { $0.id.in(gone) }.delete().execute(db)
                }
                // Only what changed, so an unchanged history doesn't wake Contribute's list.
                let stored = try MySubmission.where { $0.id.in(rows.map(\.id)) }.fetchAll(db)
                let changed = rows.filter { !stored.contains($0) }
                if !changed.isEmpty {
                    try MySubmission.upsert { changed }.execute(db)
                }
            }
            return true
        } catch {
            // A refusal's message is the server's text, and a ClientError describes the request, its token included.
            let kind =
                switch error {
                case ContributionsAPIError.rejected: "rejected"
                case let error as ContributionsAPIError: String(describing: error)
                default: String(describing: type(of: error))
                }
            Self.logger.notice("Submission history not refreshed: \(kind, privacy: .public)")
            return false
        }
    }

    public func nearby(latitude: Double, longitude: Double) async -> [NearbySpot] {
        do {
            return try await api.nearby(latitude, longitude, Self.nearbyRadiusMeters)
        } catch {
            return []
        }
    }

    public func reset() async {
        generation += 1
        draining?.cancel()
        draining = nil
        drainAgain = false
        shown = nil
        wakeup?.cancel()
        wakeup = nil
        scheduledWakeup = nil
        hasResumed = false
        do {
            try await database.write { db in
                try SubmissionDraft.delete().execute(db)
                try VideoDraft.delete().execute(db)
                try MySubmission.delete().execute(db)
            }
        } catch {
            Self.logger.error("Could not clear the outbox: \(String(describing: type(of: error)), privacy: .public)")
        }
        files.removeAll()
    }

    func drain() async {
        _ = await drain(generation)
    }

    func idle() async {
        while let draining {
            await draining.value
        }
    }

    /// A pass a person started by sending photos shows its progress, so the system can let it run on outside the app.
    private func kick(showingProgress: Bool) {
        wakeup?.cancel()
        wakeup = nil
        scheduledWakeup = nil
        guard draining == nil else {
            drainAgain = true
            return
        }
        let generation = generation
        draining = Task {
            // A submit made just before leaving the app still goes out.
            if showingProgress {
                await backgroundTime.run(shownAs: ContributionsKitStrings.Outbox.Upload.title) { progress in
                    await self.drainLoop(generation, progress: progress)
                } expired: {
                    await self.stopDraining()
                }
            } else {
                await backgroundTime.run {
                    await self.drainLoop(generation, progress: nil)
                } expired: {
                    await self.stopDraining()
                }
            }
        }
    }

    /// `base` is set for an edit that sends the spot's whole photo list, `photos` in its order.
    private func insert(_ spot: NewSpot,
                        editing spotID: String?,
                        changedFields: [SpotEditField],
                        photos: [SpotEditSuggestion.PhotoEdit.Slot],
                        base: [String]?) async throws -> String {
        let id = UUID().uuidString.lowercased()
        let createdAt = now()
        var rows = [DraftPhoto]()
        do {
            var order = [String]()
            for slot in photos {
                switch slot {
                case .kept(let photoID):
                    order.append(photoID)

                case .added(let photo):
                    let row = try write(photo, draftID: id, position: rows.count)
                    rows.append(row)
                    order.append(row.id)
                }
            }
            let draft = SubmissionDraft(
                id: id,
                title: spot.title,
                about: spot.about,
                kind: spot.kind,
                obstacles: spot.obstacles,
                condition: spot.condition,
                latitude: spot.latitude,
                longitude: spot.longitude,
                note: spot.note,
                collectionID: spot.collectionID,
                editsSpotID: spotID,
                changedFields: changedFields,
                photoOrder: base == nil ? nil : order,
                basePhotoIDs: base,
                createdAt: createdAt,
            )
            let photoRows = rows
            try await database.write { db in
                try SubmissionDraft.insert { draft }.execute(db)
                if !photoRows.isEmpty {
                    try DraftPhoto.insert { photoRows }.execute(db)
                }
            }
        } catch {
            files.remove(rows.flatMap(\.fileNames))
            throw error
        }
        kick(showingProgress: !rows.isEmpty)
        return id
    }

    private func write(_ photo: NewSpot.Photo, draftID: String, position: Int) throws -> DraftPhoto {
        let photoID = UUID().uuidString.lowercased()
        let fileName = "\(photoID).jpg"
        try files.write(photo.prepared.jpeg, named: fileName)
        let clip: DraftClip?
        do {
            clip = try photo.clip.map(store)
        } catch {
            files.remove([fileName])
            throw error
        }
        let credit: (name: String?, source: String?) =
            switch photo.credit {
            case .submitter: (nil, nil)
            case .someoneElse(let name, let sourceURL): (name, sourceURL?.absoluteString)
            }
        return DraftPhoto(
            id: photoID,
            draftID: draftID,
            position: position,
            fileName: fileName,
            width: photo.prepared.width,
            height: photo.prepared.height,
            thumbhash: photo.prepared.thumbhash,
            credit: credit.name,
            sourceURL: credit.source,
            clip: clip,
        )
    }

    /// The clip's id is minted here, with its photo's, and its file moves into the outbox.
    private func store(_ clip: PreparedClip) throws -> DraftClip {
        let clipID = UUID().uuidString.lowercased()
        let fileName = "\(clipID).mp4"
        try files.move(clip.file, named: fileName)
        return DraftClip(
            id: clipID,
            fileName: fileName,
            width: clip.width,
            height: clip.height,
            durationMs: clip.durationMs,
            bytes: clip.bytes,
        )
    }

    private func drainLoop(_ generation: Int, progress: BackgroundProgress?) async {
        shown = progress.map(ShownProgress.init)
        if !hasResumed {
            hasResumed = await resume(generation)
        }
        var sent = false
        repeat {
            drainAgain = false
            sent = await drain(generation) || sent
        } while drainAgain && !Task.isCancelled && generation == self.generation
        guard generation == self.generation else {
            return
        }
        draining = nil
        shown = nil
        await scheduleWakeup()
        if sent {
            await refreshHistory()
        }
    }

    private func stopDraining() {
        draining?.cancel()
    }

    /// Whether it ran to the end; a pass cancelled this early leaves it to the next one.
    private func resume(_ generation: Int) async -> Bool {
        do {
            let kept = try await database.write { db -> Set<String> in
                try SubmissionDraft.where { $0.status.eq(OutboxStatus.uploading) }
                    .update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
                try VideoDraft.where { $0.status.eq(OutboxStatus.uploading) }
                    .update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
                return try Set(DraftPhoto.fetchAll(db).flatMap(\.fileNames))
            }
            guard generation == self.generation else {
                return false
            }
            // An entry being added writes its photos before its rows; a file that new may still get one.
            files.removeOrphans(keeping: kept, olderThan: now().addingTimeInterval(-Self.orphanAge))
            return true
        } catch {
            Self.logger.error("Could not resume the outbox: \(String(describing: type(of: error)), privacy: .public)")
            return false
        }
    }

    private func drain(_ generation: Int) async -> Bool {
        var sent = false
        reuploaded = []
        while !Task.isCancelled, generation == self.generation {
            let due: (SubmissionDraft, [DraftPhoto])?
            do {
                if shown != nil {
                    try await countWhatsLeft()
                }
                due = try await nextDue()
            } catch {
                Self.logger.error("Could not read the outbox: \(String(describing: type(of: error)), privacy: .public)")
                return sent
            }
            guard let (draft, photos) = due else {
                break
            }
            switch await send(draft, photos, generation) {
            case .sent: sent = true
            case .refused, .again: continue
            case .stop: return sent
            }
        }
        return await drainVideos(generation) || sent
    }

    private func drainVideos(_ generation: Int) async -> Bool {
        var sent = false
        while !Task.isCancelled, generation == self.generation {
            let due: VideoDraft?
            do {
                let now = now()
                due = try await database.read { db in
                    try VideoDraft
                        .where { $0.status.eq(OutboxStatus.pending) }
                        .order(by: \.createdAt)
                        .fetchAll(db)
                        .first { ($0.nextAttemptAt ?? now) <= now }
                }
            } catch {
                Self.logger.error("Could not read the video outbox: \(String(describing: type(of: error)), privacy: .public)")
                return sent
            }
            guard let draft = due else {
                return sent
            }
            switch await send(draft, generation) {
            case .sent: sent = true
            case .refused, .again: continue
            case .stop: return sent
            }
        }
        return sent
    }

    private func send(_ draft: VideoDraft, _ generation: Int) async -> SendOutcome {
        do {
            try await write(generation) { db in
                try VideoDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.uploading) }.execute(db)
            }
            try await api.saveVideo(draft)
            try await write(generation) { db in
                try VideoDraft.find(draft.id).delete().execute(db)
            }
            return .sent
        } catch let error as ContributionsAPIError {
            let next: (status: OutboxStatus, problem: OutboxProblem?, attempts: Int, nextAttemptAt: Date?)
            let outcome: SendOutcome
            switch error {
            case .offline, .unavailable:
                let attempts = draft.attempts + 1
                next = (.pending, nil, attempts, nextAttempt(afterAttempts: attempts))
                outcome = .stop

            case .unauthorized:
                next = (.pending, draft.problem, draft.attempts, draft.nextAttemptAt)
                outcome = .stop

            case .rejected(let status, let message):
                Self.logger.notice("Video refused (\(status, privacy: .public)): \(message ?? "", privacy: .public)")
                next = (.failed, status == 409 ? .videoAlreadyThere : .video, draft.attempts, draft.nextAttemptAt)
                outcome = .refused

            case .missingPhotos, .missingClips:
                next = (.failed, .video, draft.attempts, draft.nextAttemptAt)
                outcome = .refused
            }
            try? await write(generation) { db in
                try VideoDraft.find(draft.id).update {
                    $0.status = #bind(next.status)
                    $0.problem = #bind(next.problem)
                    $0.attempts = #bind(next.attempts)
                    $0.nextAttemptAt = #bind(next.nextAttemptAt)
                }
                .execute(db)
            }
            return outcome
        } catch is CancellationError {
            await writeDespiteCancellation(generation) { db in
                try VideoDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
            }
            return .stop
        } catch {
            Self.logger.error("Video can't be sent: \(String(describing: type(of: error)), privacy: .public)")
            try? await write(generation) { db in
                try VideoDraft.find(draft.id).update {
                    $0.status = #bind(OutboxStatus.failed)
                    $0.problem = #bind(OutboxProblem.video)
                }
                .execute(db)
            }
            return .refused
        }
    }

    private func countWhatsLeft() async throws {
        let now = now()
        let left = try await database.read { db -> (entries: Int, photos: Int) in
            let due = try SubmissionDraft
                .where { $0.status.eq(OutboxStatus.pending) }
                .fetchAll(db)
                .filter { ($0.nextAttemptAt ?? now) <= now }
                .map(\.id)
            let photos = try DraftPhoto.where { $0.draftID.in(due) }.fetchAll(db).count { !$0.isFullyUploaded }
            return (due.count, photos)
        }
        shown?.left(entries: left.entries, photos: left.photos)
    }

    private func nextDue() async throws -> (SubmissionDraft, [DraftPhoto])? {
        let now = now()
        return try await database.read { db in
            let pending = try SubmissionDraft
                .where { $0.status.eq(OutboxStatus.pending) }
                .order(by: \.createdAt)
                .fetchAll(db)
            guard let draft = pending.first(where: { ($0.nextAttemptAt ?? now) <= now }) else {
                return nil
            }
            let photos = try DraftPhoto.where { $0.draftID.eq(draft.id) }.order(by: \.position).fetchAll(db)
            return (draft, photos)
        }
    }

    private func send(_ draft: SubmissionDraft, _ photos: [DraftPhoto], _ generation: Int) async -> SendOutcome {
        do {
            try await write(generation) { db in
                try SubmissionDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.uploading) }.execute(db)
            }
            // Each photo, then its clip: the two are one progress step.
            for photo in photos where !photo.isFullyUploaded {
                if !photo.isUploaded {
                    try await upload(refusedAs: .photo) { try await self.photos.upload(photo.id, files.read(photo.fileName)) }
                    try await write(generation) { db in
                        try DraftPhoto.find(photo.id).update { $0.isUploaded = #bind(true) }.execute(db)
                    }
                }
                if let clip = photo.clip, !clip.isUploaded {
                    try await upload(refusedAs: .clip) {
                        try await self.photos.uploadClip(clip.id, PreparedClip(
                            file: files.url(clip.fileName),
                            width: clip.width,
                            height: clip.height,
                            durationMs: clip.durationMs,
                            bytes: clip.bytes,
                        ))
                    }
                    var uploaded = clip
                    uploaded.isUploaded = true
                    try await write(generation) { [uploaded] db in
                        try DraftPhoto.find(photo.id).update { $0.clip = #bind(uploaded) }.execute(db)
                    }
                }
                shown?.sentPhoto()
            }
            let saved = try await api.save(draft, photos)
            guard generation == self.generation else {
                return .stop
            }
            try await database.write { db in
                try SubmissionDraft.find(draft.id).delete().execute(db)
                try MySubmission.upsert { saved }.execute(db)
            }
            shown?.sentEntry()
            files.remove(photos.flatMap(\.fileNames))
            if saved.status == .approved {
                let visibility: PublishedSpotHandler.Visibility = saved.collectionID == nil ? .public : .private
                Task { [spotPublished] in await spotPublished.run(visibility) }
            }
            return .sent
        } catch let refused as UploadRefused {
            return await handle(
                .rejected(status: refused.status, message: refused.message),
                refusedAs: refused.problem,
                for: draft,
                generation,
            )
        } catch let error as ContributionsAPIError {
            return await handle(error, refusedAs: .refused, for: draft, generation)
        } catch is CancellationError {
            await writeDespiteCancellation(generation) { db in
                try SubmissionDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
            }
            return .stop
        } catch {
            Self.logger.error("Outbox entry can't be sent: \(String(describing: type(of: error)), privacy: .public)")
            try? await write(generation) { db in
                try SubmissionDraft.find(draft.id).update {
                    $0.status = #bind(OutboxStatus.failed)
                    $0.problem = #bind(OutboxProblem.device)
                }
                .execute(db)
            }
            return .refused
        }
    }

    private func handle(_ error: ContributionsAPIError,
                        refusedAs problem: OutboxProblem,
                        for draft: SubmissionDraft,
                        _ generation: Int) async -> SendOutcome {
        do {
            switch error {
            case .missingPhotos(let ids) where !reuploaded.isSuperset(of: ids),
                 .missingClips(let ids) where !reuploaded.isSuperset(of: ids):
                reuploaded.formUnion(ids)
                try await write(generation) { db in
                    try DraftPhoto.where { $0.id.in(ids) }.update { $0.isUploaded = #bind(false) }.execute(db)
                    for photo in try DraftPhoto.where({ $0.draftID.eq(draft.id) }).fetchAll(db) {
                        guard var clip = photo.clip, ids.contains(clip.id) else {
                            continue
                        }
                        clip.isUploaded = false
                        try DraftPhoto.find(photo.id).update { [clip] in $0.clip = #bind(clip) }.execute(db)
                    }
                    try SubmissionDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
                }
                return .again

            case .offline, .unavailable, .missingPhotos, .missingClips:
                let attempts = draft.attempts + 1
                let next = nextAttempt(afterAttempts: attempts)
                try await write(generation) { db in
                    try SubmissionDraft.find(draft.id).update {
                        $0.status = #bind(OutboxStatus.pending)
                        $0.attempts = #bind(attempts)
                        $0.nextAttemptAt = #bind(next)
                    }
                    .execute(db)
                }
                return .stop

            case .unauthorized:
                try await write(generation) { db in
                    try SubmissionDraft.find(draft.id).update { $0.status = #bind(OutboxStatus.pending) }.execute(db)
                }
                return .stop

            case .rejected(let status, let message):
                Self.logger.notice(
                    "Outbox entry refused at \(problem.rawValue, privacy: .public) (\(status, privacy: .public)): \(message ?? "", privacy: .public)"
                )
                try await write(generation) { db in
                    try SubmissionDraft.find(draft.id).update {
                        $0.status = #bind(OutboxStatus.failed)
                        $0.problem = #bind(problem)
                    }
                    .execute(db)
                }
                return .refused
            }
        } catch {
            return .stop
        }
    }

    /// An upload fails the way the rest of a send does, except that a refusal says which upload it was.
    private func upload(refusedAs problem: OutboxProblem, _ transfer: () async throws -> Void) async throws {
        do {
            try await transfer()
        } catch PhotoUploadError.rejected(let status, let message) {
            throw UploadRefused(problem: problem, status: status, message: message)
        } catch let error as PhotoUploadError {
            throw ContributionsAPIError(error)
        }
    }

    private func nextAttempt(afterAttempts attempts: Int) -> Date {
        let delay = Self.backoff(afterAttempts: attempts, jitter: jitter())
        return now().addingTimeInterval(Double(delay.components.seconds) + Double(delay.components.attoseconds) / 1e18)
    }

    private func write(_ generation: Int, _ work: @escaping @Sendable (Database) throws -> Void) async throws {
        guard generation == self.generation else {
            throw CancellationError()
        }
        try await database.write(work)
    }

    /// A cancelled task's database writes throw, which would leave the entry `uploading` until the next launch.
    private func writeDespiteCancellation(_ generation: Int, _ work: @escaping @Sendable (Database) throws -> Void) async {
        await Task { try? await write(generation, work) }.value
    }

    private func scheduleWakeup() async {
        let next = try? await database.read { db in
            try (SubmissionDraft.where { $0.status.eq(OutboxStatus.pending) }.fetchAll(db).compactMap(\.nextAttemptAt)
                + VideoDraft.where { $0.status.eq(OutboxStatus.pending) }.fetchAll(db).compactMap(\.nextAttemptAt)).min()
        }
        guard let next else {
            scheduledWakeup = nil
            return
        }
        let delay = Duration.milliseconds(max(0, Int((next.timeIntervalSince(now()) * 1000).rounded())))
        scheduledWakeup = delay
        wakeup?.cancel()
        wakeup = Task { [clock] in
            do {
                try await clock.sleep(for: delay)
            } catch {
                return
            }
            self.kick()
        }
    }
}

// MARK: - UploadRefused

private struct UploadRefused: Error {
    let problem: OutboxProblem
    let status: Int
    let message: String?
}

// MARK: - ShownProgress

/// What a pass someone can follow has sent, and what it still has to: each photo is a step, then each entry's save.
private struct ShownProgress {

    // MARK: Properties

    private let sink: BackgroundProgress
    private var photosSent = 0
    private var entriesSent = 0
    private var photosLeft = 0
    private var entriesLeft = 0

    // MARK: Lifecycle

    init(_ sink: BackgroundProgress) {
        self.sink = sink
    }

    // MARK: Functions

    mutating func left(entries: Int, photos: Int) {
        entriesLeft = entries
        photosLeft = photos
        report()
    }

    mutating func sentPhoto() {
        photosSent += 1
        photosLeft = max(0, photosLeft - 1)
        report()
    }

    mutating func sentEntry() {
        entriesSent += 1
        entriesLeft = max(0, entriesLeft - 1)
        report()
    }

    private func report() {
        let photos = photosSent + photosLeft
        sink.report(
            completed: photosSent + entriesSent,
            of: photos + entriesSent + entriesLeft,
            subtitle: photos > 0 ? ContributionsKitStrings.Outbox.Upload.photo(min(photosSent + 1, photos), photos) : "",
        )
    }
}
