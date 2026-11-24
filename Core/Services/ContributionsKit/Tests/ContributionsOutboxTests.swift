import APIClientKit
import Clocks
import CustomDump
import Foundation
import PhotoUploadKit
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributionsKit

@Suite(.timeLimit(.minutes(1)))
struct ContributionsOutboxTests {
    private let server = FakeContributionsServer()
    private let time = TestTime()
    private let database: any DatabaseWriter
    private let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: "Outbox Files \(UUID().uuidString)"))
    private let outbox: ContributionsOutbox

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        outbox = ContributionsOutbox(
            api: server.api,
            photos: server.photos,
            database: database,
            files: files,
            clock: TestClock(),
            now: { [time] in time.now },
            jitter: { 1 },
        )
    }

    @Test
    func `a new spot goes out once, photos first, and moves to the history`() async throws {
        let id = try await outbox.add(spot(photos: 2))
        await outbox.idle()

        let photoIDs = await Set(server.uploads.keys)
        #expect(await server.uploads.values.sorted() == [1, 1])
        #expect(await server.saves == [id: 1])
        expectNoDifference(try entries(), [])
        expectNoDifference(try history().map(\.id), [id])
        #expect(photoIDs.count == 2)
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path(percentEncoded: false)).isEmpty)
    }

    @Test
    func `a history the server answers unchanged writes nothing`() async throws {
        _ = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        #expect(await outbox.refreshHistory())
        let before = try await database.read { db in db.totalChangesCount }

        #expect(await outbox.refreshHistory())

        let written = try await database.read { db in db.totalChangesCount } - before
        expectNoDifference(written, 0)
    }

    @Test
    func `a retry after a lost answer sends the same ids and makes no second submission`() async throws {
        await server.loseNextAnswer()
        let id = try await outbox.add(spot(photos: 1))
        await outbox.idle()

        let waiting = try #require(try entries().first)
        expectNoDifference(waiting.status, .pending)
        expectNoDifference(waiting.attempts, 1)
        expectNoDifference(waiting.problem, nil)

        time.advance(by: 1)
        await outbox.drain()

        #expect(await server.saves == [id: 2])
        #expect(await server.submissions.keys.sorted() == [id])
        #expect(await server.uploads.values.sorted() == [1])
        expectNoDifference(try entries(), [])
    }

    @Test
    func `photos the server says are missing go up again and the submission follows`() async throws {
        let id = try await addWhileOffline(spot(photos: 1))
        let photoID = try #require(try await database.read { db in try DraftPhoto.fetchAll(db) }.first?.id)
        await server.forget(photo: photoID)
        await outbox.kick()
        await outbox.idle()

        #expect(await server.uploads == [photoID: 2])
        #expect(await server.saves == [id: 2])
        expectNoDifference(try history().map(\.id), [id])
    }

    @Test
    func `a photo's clip goes up right after its photo, under the id the submission names it by`() async throws {
        let spot = spot(photos: 2, clips: [0])
        let source = try #require(spot.photos[0].clip?.file)
        let mp4 = try Data(contentsOf: source)

        let id = try await outbox.add(spot)
        #expect(!FileManager.default.fileExists(atPath: source.path(percentEncoded: false)))
        await outbox.idle()

        let sent = try #require(await server.sentSpots[id])
        let photoIDs = sent.photos.map(\.photoId)
        let clipID = try #require(sent.photos.first?.clipId)
        expectNoDifference(sent.photos.map(\.clipId), [clipID, nil])
        let requests = await server.requests
        expectNoDifference(requests, [.photo(photoIDs[0]), .clip(clipID), .photo(photoIDs[1]), .save(id)])
        let uploaded = await server.clips[clipID]
        expectNoDifference(uploaded, mp4)
        expectNoDifference(try history().map(\.id), [id])
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path(percentEncoded: false)).isEmpty)
    }

    @Test
    func `a clip that failed to go up is sent again under the same id, and its photo isn't`() async throws {
        await server.failNextClip()
        let id = try await outbox.add(spot(photos: 1, clips: [0]))
        await outbox.idle()

        let waiting = try #require(try entries().first)
        expectNoDifference(waiting.status, .pending)
        expectNoDifference(waiting.attempts, 1)
        let photo = try #require(try photoRows().first)
        let clip = try #require(photo.clip)
        #expect(photo.isUploaded)
        #expect(!clip.isUploaded)

        time.advance(by: 1)
        await outbox.drain()

        let requests = await server.requests
        expectNoDifference(requests, [.photo(photo.id), .clip(clip.id), .clip(clip.id), .save(id)])
        let sent = await server.sentSpots[id]
        expectNoDifference(sent?.photos.map(\.clipId), [clip.id])
        expectNoDifference(try history().map(\.id), [id])
    }

    @Test
    func `clips the server says are missing go up again and the submission follows`() async throws {
        let id = try await addWhileOffline(spot(photos: 1, clips: [0]))
        let photo = try #require(try photoRows().first)
        let clipID = try #require(photo.clip?.id)
        await server.forget(clip: clipID)
        await outbox.kick()
        await outbox.idle()

        let requests = await server.requests
        expectNoDifference(requests, [.photo(photo.id), .clip(clipID), .save(id), .clip(clipID), .save(id)])
        expectNoDifference(try history().map(\.id), [id])
    }

    @Test
    func `backoff doubles from one second to a minute, scaled by jitter`() {
        let seconds = (1...8).map { ContributionsOutbox.backoff(afterAttempts: $0, jitter: 1) }
        expectNoDifference(seconds, [1, 2, 4, 8, 16, 32, 60, 60].map { Duration.seconds($0) })
        expectNoDifference(ContributionsOutbox.backoff(afterAttempts: 3, jitter: 0.5), .seconds(2))
    }

    @Test
    func `offline entries wait out their backoff and are tried again when due`() async throws {
        await server.set(.offline)
        let id = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        expectNoDifference(try entries().first?.nextAttemptAt, time.now.addingTimeInterval(1))
        #expect(await outbox.scheduledWakeup == .seconds(1))

        await outbox.drain()
        #expect(await server.uploads == [:])

        time.advance(by: 1)
        await outbox.drain()
        expectNoDifference(try entries().first?.attempts, 2)
        expectNoDifference(try entries().first?.nextAttemptAt, time.now.addingTimeInterval(2))

        await server.set(.online)
        time.advance(by: 2)
        await outbox.drain()
        #expect(await server.saves == [id: 1])
        expectNoDifference(try entries(), [])
    }

    @Test
    func `a refusal marks the entry failed with the reason, and a retry sends it again`() async throws {
        await server.refuseNext(because: "Use 1 to 120 characters")
        let id = try await outbox.add(spot(photos: 1))
        await outbox.idle()

        let failed = try #require(try entries().first)
        expectNoDifference(failed.status, .failed)
        expectNoDifference(failed.problem, "Use 1 to 120 characters")
        await outbox.drain()
        #expect(await server.saves == [id: 1])

        try await outbox.retry(id)
        await outbox.idle()
        #expect(await server.saves == [id: 2])
        expectNoDifference(try history().map(\.id), [id])
    }

    @Test
    func `an entry left mid-send by the last process is sent again on start`() async throws {
        let id = try await addWhileOffline(spot(photos: 1))
        try await database.write { db in
            try SubmissionDraft.find(id).update { $0.status = #bind(OutboxStatus.uploading) }.execute(db)
        }

        let relaunched = relaunchedOutbox()
        await relaunched.start()
        await relaunched.idle()

        #expect(await server.saves == [id: 1])
        expectNoDifference(try entries(), [])
    }

    @Test
    func `the first pass after a launch removes old photo files no entry uses, and keeps the rest`() async throws {
        await server.set(.offline)
        _ = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        let kept = try FileManager.default.contentsOfDirectory(atPath: files.directory.path(percentEncoded: false))
        let directory = files.directory
        let orphan = directory.appending(path: "orphan.jpg")
        let fresh = directory.appending(path: "being-added.jpg")
        try Data([0xFF]).write(to: orphan)
        try Data([0xFF]).write(to: fresh)
        try FileManager.default.setAttributes(
            [.modificationDate: time.now.addingTimeInterval(-3600)],
            ofItemAtPath: orphan.path(percentEncoded: false),
        )
        try FileManager.default.setAttributes([.modificationDate: time.now], ofItemAtPath: fresh.path(percentEncoded: false))

        let relaunched = relaunchedOutbox()
        await relaunched.start()
        await relaunched.idle()

        let left = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        expectNoDifference(Set(left), Set(kept + ["being-added.jpg"]))
    }

    @Test
    func `ending the account stops sending and forgets every entry, file and history row`() async throws {
        _ = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        await server.set(.offline)
        _ = try await outbox.add(spot(photos: 2))
        await outbox.idle()
        #expect(try !entries().isEmpty)
        #expect(try !history().isEmpty)
        let generation = await outbox.generation

        await outbox.reset()

        expectNoDifference(try entries(), [])
        expectNoDifference(try history(), [])
        let photoRows = try await database.read { db in try DraftPhoto.fetchCount(db) }
        expectNoDifference(photoRows, 0)
        #expect(!FileManager.default.fileExists(atPath: files.directory.path(percentEncoded: false)))
        #expect(await outbox.generation == generation + 1)
        #expect(await outbox.scheduledWakeup == nil)
    }

    @Test
    func `discarding removes a waiting entry and its photo files`() async throws {
        await server.set(.offline)
        let id = try await outbox.add(spot(photos: 2))
        await outbox.idle()

        let discarded = try await outbox.discard(id)

        #expect(discarded)
        expectNoDifference(try entries(), [])
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.directory.path(percentEncoded: false)).isEmpty)
    }

    @Test
    func `discarding removes a waiting photo's clip file with it`() async throws {
        await server.set(.offline)
        let id = try await outbox.add(spot(photos: 1, clips: [0]))
        await outbox.idle()
        let directory = files.directory.path(percentEncoded: false)
        expectNoDifference(try FileManager.default.contentsOfDirectory(atPath: directory).count, 2)

        #expect(try await outbox.discard(id))

        #expect(try FileManager.default.contentsOfDirectory(atPath: directory).isEmpty)
    }

    @Test
    func `an entry already uploading isn't discarded, and says so`() async throws {
        await server.set(.offline)
        let id = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        try await database.write { db in
            try SubmissionDraft.find(id).update { $0.status = #bind(OutboxStatus.uploading) }.execute(db)
        }

        let discarded = try await outbox.discard(id)

        #expect(!discarded)
        expectNoDifference(try entries().map(\.id), [id])
    }

    @Test
    func `a video goes out under its id, after a failed attempt too, and leaves the outbox`() async throws {
        await server.set(.offline)
        let id = try await outbox.addVideo(spotID: "spot-1", url: "https://youtu.be/dQw4w9WgXcQ", caption: "Kickflip")
        await outbox.idle()

        let waiting = try #require(try videos().first)
        expectNoDifference(waiting.status, .pending)
        expectNoDifference(waiting.problem, nil)
        expectNoDifference(waiting.attempts, 1)

        await server.set(.online)
        time.advance(by: 1)
        await outbox.drain()

        #expect(await server.videoSaves == [id: 1])
        let sent = await server.videos[id]
        expectNoDifference(sent?.url, "https://youtu.be/dQw4w9WgXcQ")
        expectNoDifference(sent?.spotID, "spot-1")
        expectNoDifference(try videos(), [])
    }

    @Test
    func `a refused video stays failed with the server's reason until it's retried or discarded`() async throws {
        await server.refuseNext(because: "This video is already on the spot, or waiting for review")
        let id = try await outbox.addVideo(spotID: "spot-1", url: "https://youtu.be/dQw4w9WgXcQ", caption: "")
        await outbox.idle()

        let failed = try #require(try videos().first)
        expectNoDifference(failed.status, .failed)
        expectNoDifference(failed.problem, "This video is already on the spot, or waiting for review")

        try await outbox.retryVideo(id)
        await outbox.idle()
        #expect(await server.videoSaves == [id: 2])
        expectNoDifference(try videos(), [])

        await server.refuseNext(because: "No such spot")
        let other = try await outbox.addVideo(spotID: "gone", url: "https://youtu.be/9bZkp7q19f0", caption: "")
        await outbox.idle()
        try await outbox.discardVideo(other)
        expectNoDifference(try videos(), [])
    }

    @Test
    func `a suggested edit goes out as an edit of its spot and lands in the history as one`() async throws {
        let edit = SpotEditSuggestion(
            spotID: "spot-9",
            proposed: spot(photos: 0),
            changedDetails: [.condition],
            photoEdit: SpotEditSuggestion.PhotoEdit(order: photos(1).map { .added($0) }, base: []),
        )
        let id = try await outbox.add(edit)
        await outbox.idle()

        #expect(await server.saves == [id: 1])
        let sent = try #require(try history().first)
        expectNoDifference(sent.spotID, "spot-9")
        expectNoDifference(sent.changedFields, [.condition, .photos])
        #expect(sent.isEdit)
    }

    @Test
    func `an edit sends the spot's photos as it leaves them, its new ones under the ids they were uploaded with`() async throws {
        let added = photos(2)
        let edit = SpotEditSuggestion(
            spotID: "spot-9",
            proposed: spot(photos: 0),
            changedDetails: [],
            photoEdit: SpotEditSuggestion.PhotoEdit(
                order: [.added(added[0]), .kept(id: "cover"), .added(added[1])],
                base: ["cover", "gone"],
            ),
        )
        let id = try await outbox.add(edit)
        await outbox.idle()

        let sent = try #require(await server.sentEdits[id])
        let ids = try #require(sent.photos).map(\.photoId)
        #expect(ids.count == 2)
        expectNoDifference(sent.photoEdit?.order, [ids[0], "cover", ids[1]])
        expectNoDifference(sent.photoEdit?.base, ["cover", "gone"])
        expectNoDifference(try history().first { $0.id == id }?.changedFields, [.photos])

        let unchanged = try await outbox.add(SpotEditSuggestion(
            spotID: "spot-9",
            proposed: spot(photos: 0),
            changedDetails: [.title],
            photoEdit: nil,
        ))
        await outbox.idle()
        let unchangedEdit = try #require(await server.sentEdits[unchanged])
        #expect(unchangedEdit.photoEdit == nil)
        expectNoDifference(unchangedEdit.photos, [])
    }

    @Test
    func `an edit's new photo sends its clip with it`() async throws {
        let edit = SpotEditSuggestion(
            spotID: "spot-9",
            proposed: spot(photos: 0),
            changedDetails: [],
            photoEdit: SpotEditSuggestion.PhotoEdit(
                order: [.kept(id: "cover"), .added(photos(1, clips: [0])[0])],
                base: ["cover"],
            ),
        )
        let id = try await outbox.add(edit)
        await outbox.idle()

        let sent = try #require(await server.sentEdits[id])
        let added = try #require(sent.photos?.first)
        let clipID = try #require(added.clipId)
        let requests = await server.requests
        expectNoDifference(requests, [.photo(added.photoId), .clip(clipID), .save(id)])
        expectNoDifference(sent.photoEdit?.order, ["cover", added.photoId])
    }

    @Test
    func `a spot the server publishes at once asks for a sync: the spot sync for a public one, collections for a private one`() async throws {
        let (published, report) = AsyncStream<PublishedSpotHandler.Visibility>.makeStream()
        var reports = published.makeAsyncIterator()
        let outbox = ContributionsOutbox(
            api: server.api,
            photos: server.photos,
            database: database,
            files: files,
            spotPublished: PublishedSpotHandler { report.yield($0) },
            clock: TestClock(),
            now: { [time] in time.now },
            jitter: { 1 },
        )

        _ = try await outbox.add(spot(photos: 0))
        await outbox.idle()
        await server.approveSaves()
        _ = try await outbox.add(spot(photos: 0))
        await outbox.idle()
        #expect(await reports.next() == .public)

        var mine = spot(photos: 0)
        mine.collectionID = "collection-1"
        _ = try await outbox.add(mine)
        await outbox.idle()
        #expect(await reports.next() == .private)
    }

    @Test
    func `a history refresh keeps an entry sent while it was out, and drops what the server no longer lists`() async throws {
        let first = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        try await database.write { db in
            try MySubmission.insert {
                MySubmission(
                    id: "withdrawn",
                    title: "Gone",
                    kind: .street,
                    cityID: nil,
                    latitude: 0,
                    longitude: 0,
                    status: .pending,
                    rejectReason: nil,
                    spotID: nil,
                    coverThumbhash: nil,
                    createdAt: time.now,
                    updatedAt: time.now,
                )
            }
            .execute(db)
        }

        await server.holdNextHistory()
        var requests = server.historyHeld.makeAsyncIterator()
        let refresh = Task { await outbox.refreshHistory() }
        _ = await requests.next()
        let second = try await outbox.add(spot(photos: 1))
        await outbox.idle()
        await server.releaseHistory()
        #expect(await refresh.value)

        expectNoDifference(Set(try history().map(\.id)), [first, second])
    }

    @Test
    func `a video whose answer makes no sense fails without holding up the next one`() async throws {
        await server.garbleNextVideo()
        let garbled = try await outbox.addVideo(spotID: "spot-1", url: "https://youtu.be/dQw4w9WgXcQ", caption: "")
        let next = try await outbox.addVideo(spotID: "spot-1", url: "https://youtu.be/9bZkp7q19f0", caption: "")
        await outbox.idle()

        let failed = try #require(try videos().first)
        expectNoDifference(failed.id, garbled)
        expectNoDifference(failed.status, .failed)
        expectNoDifference(failed.problem, ContributionsKitStrings.Outbox.Problem.video)
        #expect(await server.videos[next] != nil)
    }

    @Test
    func `an entry without photos, or a pass nobody started, keeps plain background time until it's done`() async throws {
        let background = FakeBackgroundTime()
        let outbox = relaunchedOutbox(backgroundTime: background.backgroundTime)
        var events = background.events.makeAsyncIterator()

        let id = try await outbox.add(spot(photos: 0))
        await outbox.idle()
        await outbox.start()
        await outbox.idle()

        #expect(await events.next() == .began)
        #expect(await events.next() == .ended)
        #expect(await events.next() == .began)
        #expect(await events.next() == .ended)
        #expect(await server.saves == [id: 1])
    }

    @Test
    func `photos someone sends report progress the system can show, to the last step`() async throws {
        let background = FakeBackgroundTime()
        let outbox = relaunchedOutbox(backgroundTime: background.backgroundTime)

        let id = try await outbox.add(spot(photos: 2))
        await outbox.idle()

        var events = [FakeBackgroundTime.Event]()
        for await event in background.events {
            events.append(event)
            if event == .ended {
                break
            }
        }
        let first = ContributionsKitStrings.Outbox.Upload.photo(1, 2)
        let second = ContributionsKitStrings.Outbox.Upload.photo(2, 2)
        expectNoDifference(events, [
            .beganShown(ContributionsKitStrings.Outbox.Upload.title),
            .progress(completed: 0, total: 3, subtitle: first),
            .progress(completed: 1, total: 3, subtitle: second),
            .progress(completed: 2, total: 3, subtitle: second),
            .progress(completed: 3, total: 3, subtitle: second),
            .progress(completed: 3, total: 3, subtitle: second),
            .ended,
        ])
        #expect(await server.saves == [id: 1])
    }

    @Test
    func `when the time runs out or the person cancels the upload, the pass stops and the entry waits to be sent`() async throws {
        let background = FakeBackgroundTime()
        let outbox = relaunchedOutbox(backgroundTime: background.backgroundTime)
        var held = server.uploadHeld.makeAsyncIterator()
        await server.holdNextUpload()

        let id = try await outbox.add(spot(photos: 1))
        await held.next()
        await background.expire()
        await outbox.idle()

        expectNoDifference(try entries().map(\.status), [.pending])
        expectNoDifference(try entries().map(\.attempts), [0])
        #expect(await server.saves == [:])

        await outbox.kick()
        await outbox.idle()
        #expect(await server.saves == [id: 1])
    }

    // MARK: Helpers

    private func relaunchedOutbox(backgroundTime: BackgroundTime = .none) -> ContributionsOutbox {
        ContributionsOutbox(
            api: server.api,
            photos: server.photos,
            database: database,
            files: files,
            backgroundTime: backgroundTime,
            clock: TestClock(),
            now: { [time] in time.now },
            jitter: { 1 },
        )
    }

    private func addWhileOffline(_ spot: NewSpot) async throws -> String {
        await server.set(.offline)
        let id = try await outbox.add(spot)
        await outbox.idle()
        await server.set(.online)
        time.advance(by: 1)
        return id
    }

    private func spot(photos count: Int, clips: Set<Int> = []) -> NewSpot {
        NewSpot(
            title: "Undercroft",
            about: "",
            kind: .plaza,
            obstacles: ["ledges"],
            condition: .skateable,
            latitude: 51.5066,
            longitude: -0.1169,
            note: "",
            photos: photos(count, clips: clips),
        )
    }

    /// `clips` are the indexes of the photos that get one, each in a file of its own as `ClipPreparer` leaves it.
    private func photos(_ count: Int, clips: Set<Int> = []) -> [NewSpot.Photo] {
        (0..<count).map { index in
            NewSpot.Photo(
                prepared: PreparedPhoto(
                    jpeg: Data([0xFF, 0xD8, UInt8(index)]),
                    width: 10,
                    height: 10,
                    thumbhash: "1QcSHQRnh493V4dIh4eXh1h4kJUI",
                ),
                credit: index == 0 ? .submitter : .someoneElse(name: "@lens", sourceURL: nil),
                clip: clips.contains(index) ? clip(index) : nil,
            )
        }
    }

    private func clip(_ index: Int) -> PreparedClip {
        let file = URL.temporaryDirectory.appending(path: "Clip \(UUID().uuidString).mp4")
        let mp4 = Data("clip \(index)".utf8)
        #expect(FileManager.default.createFile(atPath: file.path(percentEncoded: false), contents: mp4))
        return PreparedClip(file: file, width: 720, height: 1280, durationMs: 4000, bytes: mp4.count)
    }

    private func photoRows() throws -> [DraftPhoto] {
        try database.read { db in try DraftPhoto.order(by: \.position).fetchAll(db) }
    }

    private func entries() throws -> [SubmissionDraft] {
        try database.read { db in try SubmissionDraft.order(by: \.createdAt).fetchAll(db) }
    }

    private func videos() throws -> [VideoDraft] {
        try database.read { db in try VideoDraft.order(by: \.createdAt).fetchAll(db) }
    }

    private func history() throws -> [MySubmission] {
        try database.read { db in try MySubmission.fetchAll(db) }
    }
}
