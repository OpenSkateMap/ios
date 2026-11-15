import APIClientKit
import CustomDump
import FactoryKit
import Foundation
import Observation
import SpotModelKit
import SQLiteKit
import Testing
@testable import ReviewKit

// MARK: - ReviewSessionTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ReviewSessionTests {
    @Test
    func `loading shows the queue oldest first`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)

        await session.load()

        expectNoDifference(session.cards.map(\.id), ["a", "b"])
        expectNoDifference(session.phase, .loaded)
    }

    @Test
    func `approving sends the version the curator saw and only what changed`() async {
        let server = FakeReviewServer(cards: [.fixture("a", updatedAt: 1_791_500_123), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()

        await session.approve("a", edits: SpotEdits(title: "Undercroft"))

        expectNoDifference(server.calls, ["queue", "approve a seen=1791500123 edits=title=Undercroft"])
        expectNoDifference(session.cards.map(\.id), ["b"])
        expectNoDifference(session.lastDecision?.verdict, .approved(spotID: "spot-a", title: "Undercroft"))
        expectNoDifference(session.notice, nil)
    }

    @Test
    func `rejecting sends the reason and the version the curator saw`() async {
        let server = FakeReviewServer(cards: [.fixture("a", updatedAt: 1_791_500_456)])
        let session = ReviewSession(api: server.api)
        await session.load()

        await session.reject("a", reason: .privateProperty)

        expectNoDifference(server.calls, ["queue", "reject a private_property seen=1791500456"])
        expectNoDifference(Array(session.cards), [])
        expectNoDifference(session.lastDecision?.verdict, .rejected(.privateProperty))
    }

    @Test
    func `a resend since the card was opened reloads the queue with the new version`() async {
        let server = FakeReviewServer(cards: [.fixture("a", updatedAt: 1_791_500_000)])
        let session = ReviewSession(api: server.api)
        await session.load()
        server.setQueue([.fixture("a", title: "Resent", updatedAt: 1_791_500_999)])
        server.failNext(.conflict("The submission changed since you opened it; reload it first"))

        await session.approve("a")

        expectNoDifference(session.notice, .changedSinceOpened)
        expectNoDifference(session.cards.map(\.title), ["Resent"])
        expectNoDifference(session.cards.first?.updatedAt, Date(timeIntervalSince1970: 1_791_500_999))
        expectNoDifference(session.lastDecision, nil)
        expectNoDifference(server.calls.last, "queue")
    }

    @Test
    func `a submission outside the curator's cities leaves the stack with a notice`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()
        server.setQueue([.fixture("b")])
        server.failNext(.forbidden("You don't review submissions in this city"))

        await session.approve("a")

        expectNoDifference(session.notice, .outsideYourCities)
        expectNoDifference(session.cards.map(\.id), ["b"])
        expectNoDifference(session.lastDecision, nil)
    }

    @Test
    func `a refusal reloads after a load already out, whose answer may predate it`() async {
        let server = FakeReviewServer(cards: [.fixture("a", updatedAt: 1_791_500_000)])
        let session = ReviewSession(api: server.api)
        await session.load()

        server.holdNextQueue()
        var requests = server.queueHeld.makeAsyncIterator()
        let stale = Task { await session.load() }
        _ = await requests.next()
        server.setQueue([.fixture("a", title: "Resent", updatedAt: 1_791_500_999)])
        server.failNext(.conflict("The submission changed since you opened it; reload it first"))
        let approving = Task { await session.approve("a") }
        for await notice in Observations({ [session] in session.notice }) where notice != nil {
            break
        }
        server.releaseQueue()
        await stale.value
        _ = await approving.value

        expectNoDifference(session.cards.map(\.title), ["Resent"])
        expectNoDifference(server.calls.count { $0 == "queue" }, 3)
        expectNoDifference(server.calls.last, "queue")
    }

    @Test
    func `a load that was out while a card was decided doesn't bring it back`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()

        server.holdNextQueue()
        var requests = server.queueHeld.makeAsyncIterator()
        let reload = Task { await session.load() }
        _ = await requests.next()
        await session.approve("a")
        server.releaseQueue()
        await reload.value

        expectNoDifference(session.cards.map(\.id), ["b"])
    }

    @Test
    func `offline puts the card back where it was`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()
        server.failNext(.offline)

        await session.reject("b", reason: .duplicate)

        expectNoDifference(session.notice, .offline)
        expectNoDifference(session.cards.map(\.id), ["a", "b"])
        expectNoDifference(session.deciding, [])
    }

    @Test
    func `undo brings the card back on top at its new version`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()
        await session.approve("b")

        await session.undo()

        expectNoDifference(server.calls.last, "undo b")
        expectNoDifference(session.cards.map(\.id), ["b", "a"])
        expectNoDifference(session.cards.first?.updatedAt, Date(timeIntervalSince1970: 1_791_590_402))
        expectNoDifference(session.lastDecision, nil)
    }

    @Test
    func `an undo that can't reach the server stays undoable`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        let session = ReviewSession(api: server.api)
        await session.load()
        await session.approve("a")
        server.failNext(.offline)

        await session.undo()

        expectNoDifference(session.notice, .undoFailed(.offline))
        expectNoDifference(session.lastDecision?.card.id, "a")
        expectNoDifference(Array(session.cards), [])
        #expect(!session.isUndoing)
    }

    @Test
    func `a decision says whether it went through`() async {
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        let session = ReviewSession(api: server.api)
        await session.load()
        server.failNext(.offline)

        let offline = await session.approve("a")
        let approved = await session.approve("a")

        #expect(!offline)
        #expect(approved)
    }

    @Test
    func `an undo shows as in progress until the server answers`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        let session = ReviewSession(api: server.api)
        await session.load()
        await session.approve("a")
        server.holdNextUndo()
        var undos = server.undoHeld.makeAsyncIterator()

        let undo = Task { await session.undo() }
        _ = await undos.next()
        #expect(session.isUndoing)
        server.releaseUndo()
        await undo.value

        #expect(!session.isUndoing)
        expectNoDifference(session.cards.map(\.id), ["a"])
    }

    @Test
    func `a reload keeps the queue known, so how much is waiting stays on screen`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        let session = ReviewSession(api: server.api)
        #expect(!session.isQueueKnown)
        await session.load()

        server.holdNextQueue()
        var requests = server.queueHeld.makeAsyncIterator()
        let reload = Task { await session.load() }
        _ = await requests.next()

        expectNoDifference(session.phase, .loading)
        #expect(session.isQueueKnown)
        expectNoDifference(session.cards.map(\.id), ["a"])
        server.releaseQueue()
        await reload.value
    }

    @Test
    func `a failed load keeps what was shown and says why`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        let session = ReviewSession(api: server.api)
        await session.load()
        server.failNext(.unavailable)

        await session.load()

        expectNoDifference(session.phase, .failed(.unavailable))
        expectNoDifference(session.cards.map(\.id), ["a"])
    }

    @Test
    func `ending the account gives the next one a fresh queue`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        Container.shared.reviewAPIManager.register { server.api }
        defer { Container.shared.reviewAPIManager.reset() }

        let first = Container.shared.reviewSession()
        await first.load()
        Container.shared.manager.reset(scope: .account)
        let next = Container.shared.reviewSession()

        #expect(first !== next)
        expectNoDifference(Array(next.cards), [])
        expectNoDifference(next.phase, .idle)
    }
}

// MARK: - ReviewQueueCacheTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ReviewQueueCacheTests {
    private static func store() throws -> ReviewQueueStore {
        .live(database: try AppDatabase.inMemory(schemas: [.review]))
    }

    @Test
    func `the first load shows the queue as last cached until the server answers, and then the server's`() async throws {
        let store = try Self.store()
        await store.save(ReviewQueue(cityIDs: nil, cards: [.fixture("old")]), store.generation())
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        server.holdNextQueue()
        let session = ReviewSession(api: server.api, store: store)

        var requests = server.queueHeld.makeAsyncIterator()
        let load = Task { await session.load() }
        _ = await requests.next()
        expectNoDifference(session.cards.map(\.id), ["old"])

        server.releaseQueue()
        await load.value
        expectNoDifference(session.cards.map(\.id), ["a", "b"])
        let cached = await store.load()
        expectNoDifference(cached?.cards.map(\.id), ["a", "b"])
    }

    @Test
    func `a failed refresh keeps the cached queue, and a decision updates it`() async throws {
        let store = try Self.store()
        await store.save(ReviewQueue(cityIDs: nil, cards: [.fixture("a"), .fixture("b")]), store.generation())
        let server = FakeReviewServer(cards: [.fixture("a"), .fixture("b")])
        server.failNext(.offline)
        let session = ReviewSession(api: server.api, store: store)

        await session.load()
        expectNoDifference(session.cards.map(\.id), ["a", "b"])
        expectNoDifference(session.phase, .failed(.offline))

        await session.reject("a", reason: .duplicate)
        let afterDecision = await store.load()
        expectNoDifference(afterDecision?.cards.map(\.id), ["b"])
        await store.clear()
        let cleared = await store.load()
        expectNoDifference(cleared, nil)
    }

    @Test
    func `a queue that comes back after the account ended isn't cached for the next one`() async throws {
        let store = try Self.store()
        let server = FakeReviewServer(cards: [.fixture("theirs")])
        server.holdNextQueue()
        let session = ReviewSession(api: server.api, store: store)
        var requests = server.queueHeld.makeAsyncIterator()
        let load = Task { await session.load() }
        _ = await requests.next()

        await store.clear()
        server.releaseQueue()
        await load.value

        let cached = await store.load()
        expectNoDifference(cached, nil)
    }

}
