import CollectionsKit
import ContributionsKit
import CustomDump
import FactoryKit
import Foundation
import IdentifiedCollections
import PhotoUploadKit
import ReviewKit
import SpotModelKit
import SpotsKit
import SQLiteData
import SQLiteKit
import Testing
@testable import ContributeKit

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct NewSpotModelTests {
    private static func card(_ id: String, updatedAt: Date = Date(timeIntervalSince1970: 0)) -> ReviewCard {
        ReviewCard(
            id: id,
            title: "Vauxhall DIY Bowl",
            about: "",
            kind: .diy,
            obstacles: ["bowl"],
            condition: .skateable,
            latitude: 51.486,
            longitude: -0.124,
            cityID: nil,
            note: "",
            photos: [],
            submitterName: nil,
            nearby: [],
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: updatedAt,
        )
    }

    @Test
    func `a picked file that can't be read shows as a photo that can't be used`() throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let outbox = ContributionsOutbox(api: .preview, photos: .preview, database: database, files: files)
        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.contributionsSession.register { ContributionsSession(outbox: outbox, photos: .preview) }

        try withDependencies {
            $0.defaultDatabase = database
        } operation: {
            let model = NewSpotModel()
            model.addPhotos([nil])

            let photo = try #require(model.form.photos.first)
            expectNoDifference(photo.added?.state, .failed)
        }
    }

    @Test
    func `picked photos show as preparing at once, and each fills in as it arrives`() throws {
        try withModel { model in
            let ids = model.beginPhotos(2)
            expectNoDifference(model.form.photos.map(\.added?.state), [.preparing, .preparing])

            model.fillPhoto(ids[1], with: nil)
            expectNoDifference(model.form.photos.map(\.added?.state), [.preparing, .failed])

            model.removePhoto(ids[0])
            model.fillPhoto(ids[0], with: nil)
            expectNoDifference(model.form.photos.map(\.id), [ids[1]])
        }
    }

    @Test
    func `a picked batch takes only the tiles that are left`() throws {
        try withModel { model in
            _ = model.beginPhotos(NewSpotForm.maxPhotos - 1)
            let ids = model.beginPhotos(3)
            expectNoDifference(ids.count, 1)
            expectNoDifference(model.form.photos.count, NewSpotForm.maxPhotos)
        }
    }

    @Test
    func `a trimmed video becomes its tile's clip, with the chosen frame as the photo`() async throws {
        try await withModel { model in
            let source = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov")
            let ids = model.beginPhotos(2)
            model.fillPhoto(ids[0], with: nil)

            try await model.fillClip(ids[1], from: source, duration: 12.4, coverAt: 3.5)

            let photo = try #require(model.form.photos[id: ids[1]]?.added)
            expectNoDifference(photo.clip, PreparedClip(file: source, width: 720, height: 1280, durationMs: 12400, bytes: 0))
            expectNoDifference(photo.prepared, PreparedPhoto(jpeg: Data(), width: 1, height: 1, thumbhash: ""))
            expectNoDifference(model.form.photos.map(\.clipMilliseconds), [nil, 12400])
        }
    }

    @Test
    func `a video that can't become a clip leaves no tile, and says why`() async throws {
        try await withModel { model in
            let ids = model.beginPhotos(2)

            await #expect(throws: ClipPreparationError.tooShort) {
                try await model.fillClip(
                    ids[0],
                    from: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov"),
                    duration: 2.5,
                    coverAt: 0,
                )
            }
            expectNoDifference(model.form.photos.map(\.id), [ids[1]])
        }
    }

    @Test
    func `a video cancelled in the trimmer leaves no tile, even once its clip would be ready`() async throws {
        try await withModel { model in
            let ids = model.beginPhotos(2)

            model.removePhoto(ids[0])
            try await model.fillClip(
                ids[0],
                from: URL.temporaryDirectory.appending(path: "\(UUID().uuidString).mov"),
                duration: 5,
                coverAt: 1,
            )

            expectNoDifference(model.form.photos.map(\.id), [ids[1]])
        }
    }

    @Test
    func `the spot can't be sent while its new private collection is being made`() async throws {
        let (started, start) = AsyncStream.makeStream(of: Void.self)
        let (answer, release) = AsyncStream.makeStream(of: Void.self)
        var api = CollectionsAPIManager.preview
        api.save = { _, _, _ in
            start.yield()
            for await _ in answer {
                break
            }
            throw CollectionsAPIError.offline
        }
        try await withModel(collections: api) { model in
            let creating = Task { try await model.createPrivateCollection(named: "Night Lines") }
            for await _ in started {
                break
            }
            #expect(model.isCreatingCollection)
            let submission = await model.submit()
            expectNoDifference(submission, .busy)

            release.yield()
            await #expect(throws: CollectionsAPIError.self) { try await creating.value }
            #expect(!model.isCreatingCollection)
            expectNoDifference(model.form.collectionID, nil)
        }
    }

    @Test
    func `approving waits for the server, sends the curator's edits for its own card, and keeps them when it fails`()
        async throws {
        let (approvals, report) = AsyncStream.makeStream(of: (id: String, edits: SpotEdits).self)
        let (answers, answer) = AsyncStream.makeStream(of: Bool.self)
        let cards = [Self.card("top"), Self.card("opened")]
        var api = ReviewAPIManager.preview
        api.queue = { _, _ in ReviewQueue(cityIDs: nil, cards: cards) }
        api.approve = { id, edits, seen in
            report.yield((id, edits))
            for await succeeds in answers {
                guard succeeds else {
                    throw ReviewAPIError.offline
                }
                break
            }
            return ReviewDecided(id: id, status: .approved, spotID: "spot", updatedAt: seen)
        }
        let review = ReviewSession(api: api)
        await review.load()
        try await withModel(review: review, make: { NewSpotModel(reviewing: cards[1]) }) { model in
            model.edit { $0.condition = .knobbed }

            let failing = Task { await model.submit() }
            var sent = approvals.makeAsyncIterator()
            let next = await sent.next()
            let first = try #require(next)
            expectNoDifference(first.id, "opened")
            expectNoDifference(first.edits, SpotEdits(condition: .knobbed))
            #expect(model.isApproving)
            answer.yield(false)
            let failed = await failing.value
            expectNoDifference(failed, .failed)
            #expect(!model.isApproving)
            expectNoDifference(model.form.condition, .knobbed)

            let approving = Task { await model.submit() }
            _ = await sent.next()
            answer.yield(true)
            let approved = await approving.value
            expectNoDifference(approved, .approved)
            expectNoDifference(review.cards.map(\.id), ["top"])
        }
    }

    @Test
    func `an approval goes out as the version on screen, and a card that changed closes the sheet`() async throws {
        let opened = Self.card("a")
        let resent = Self.card("a", updatedAt: Date(timeIntervalSince1970: 1))
        let (sent, report) = AsyncStream.makeStream(of: Date.self)
        var api = ReviewAPIManager.preview
        api.queue = { _, _ in ReviewQueue(cityIDs: nil, cards: [resent]) }
        api.approve = { _, _, seen in
            report.yield(seen)
            throw ReviewAPIError.conflict("changed")
        }
        let review = ReviewSession(api: api)
        await review.load()
        try await withModel(review: review, make: { NewSpotModel(reviewing: opened) }) { model in
            let outcome = await model.submit()

            var seen = sent.makeAsyncIterator()
            let first = await seen.next()
            expectNoDifference(first, opened.updatedAt)
            expectNoDifference(outcome, .cardChanged)
            expectNoDifference(review.notice, .changedSinceOpened)
            #expect(model.isApproving)
        }
    }

    @Test
    func `a card no longer in the queue closes the sheet with a notice`() async throws {
        var api = ReviewAPIManager.preview
        api.queue = { _, _ in ReviewQueue(cityIDs: nil, cards: []) }
        let review = ReviewSession(api: api)
        await review.load()
        try await withModel(review: review, make: { NewSpotModel(reviewing: Self.card("a")) }) { model in
            let outcome = await model.submit()

            expectNoDifference(outcome, .cardChanged)
            expectNoDifference(review.notice, .changedSinceOpened)
        }
    }

    @Test
    func `a pin outside the curator's cities keeps the card and the edits, so the pin can move back`() async throws {
        let card = Self.card("a")
        var api = ReviewAPIManager.preview
        api.queue = { _, _ in ReviewQueue(cityIDs: nil, cards: [card]) }
        api.approve = { _, _, _ in throw ReviewAPIError.forbidden("The new pin is outside the cities you review") }
        let review = ReviewSession(api: api)
        await review.load()
        try await withModel(review: review, make: { NewSpotModel(reviewing: card) }) { model in
            model.edit { $0.condition = .knobbed }
            let outcome = await model.submit()

            expectNoDifference(outcome, .failed)
            expectNoDifference(review.notice, .outsideYourCities)
            expectNoDifference(review.cards.map(\.id), ["a"])
            expectNoDifference(model.form.condition, .knobbed)
            #expect(!model.isApproving)
        }
    }

    @Test
    func `a 403 whose reload fails keeps the card and the edits`() async throws {
        let card = Self.card("a")
        let (answers, answer) = AsyncStream.makeStream(of: Result<ReviewQueue, ReviewAPIError>.self)
        answer.yield(.success(ReviewQueue(cityIDs: nil, cards: [card])))
        answer.yield(.failure(.offline))
        var api = ReviewAPIManager.preview
        api.queue = { _, _ in
            for await next in answers {
                return try next.get()
            }
            throw ReviewAPIError.offline
        }
        api.approve = { _, _, _ in throw ReviewAPIError.forbidden("The new pin is outside the cities you review") }
        let review = ReviewSession(api: api)
        await review.load()
        try await withModel(review: review, make: { NewSpotModel(reviewing: card) }) { model in
            model.edit { $0.condition = .knobbed }
            let outcome = await model.submit()

            expectNoDifference(outcome, .failed)
            expectNoDifference(review.notice, .outsideYourCities)
            expectNoDifference(review.cards.map(\.id), ["a"])
            expectNoDifference(model.form.condition, .knobbed)
        }
    }

    private func withModel(collections api: CollectionsAPIManager = .preview,
                           review: ReviewSession = ReviewSession(api: .preview),
                           make: () -> NewSpotModel = { NewSpotModel() },
                           _ body: (NewSpotModel) async throws -> Void) async throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let outbox = ContributionsOutbox(api: .preview, photos: .preview, database: database, files: files)
        let sync = CollectionsSync(api: api, spots: SpotSyncEngine(api: .preview, database: database), database: database)
        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.contributionsSession.register { ContributionsSession(outbox: outbox, photos: .preview) }
        container.collectionsSession.register { CollectionsSession(sync: sync, api: api) { "rider" } }
        container.reviewSession.register { review }
        try await withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try await body(make())
        }
    }

    private func withModel(_ body: (NewSpotModel) throws -> Void) throws {
        let database = try AppDatabase.inMemory(schemas: [.spots, .contributions])
        let files = OutboxFiles(directory: URL.temporaryDirectory.appending(path: UUID().uuidString))
        let outbox = ContributionsOutbox(api: .preview, photos: .preview, database: database, files: files)
        let container = Container.shared
        container.manager.push()
        defer { container.manager.pop() }
        container.contributionsSession.register { ContributionsSession(outbox: outbox, photos: .preview) }
        try withDependencies {
            $0.defaultDatabase = database
        } operation: {
            try body(NewSpotModel())
        }
    }
}
