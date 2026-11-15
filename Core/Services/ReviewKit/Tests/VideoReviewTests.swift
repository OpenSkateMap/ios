import CustomDump
import Foundation
import Testing
@testable import ReviewKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct VideoReviewTests {
    @Test
    func `pending videos load with the queue`() async {
        let server = FakeReviewServer(cards: [.fixture("a")])
        server.setVideos([.fixture("v1"), .fixture("v2")])
        let session = ReviewSession(api: server.api)

        await session.load()

        expectNoDifference(session.cards.map(\.id), ["a"])
        expectNoDifference(session.videoCards.map(\.id), ["v1", "v2"])
    }

    @Test
    func `approving and rejecting a video send the version the curator saw`() async {
        let server = FakeReviewServer()
        server.setVideos([.fixture("v1", updatedAt: 1_791_500_111), .fixture("v2", updatedAt: 1_791_500_222)])
        let session = ReviewSession(api: server.api)
        await session.load()

        await session.approveVideo("v1")
        expectNoDifference(session.lastVideoDecision?.verdict, .approved)
        await session.rejectVideo("v2", reason: .wrongSpot)

        expectNoDifference(
            server.calls,
            ["queue", "approveVideo v1 seen=1791500111", "rejectVideo v2 wrong_spot seen=1791500222"],
        )
        expectNoDifference(Array(session.videoCards), [])
        expectNoDifference(session.lastVideoDecision?.verdict, .rejected(.wrongSpot))
    }

    @Test
    func `a video decision that didn't reach the server puts the video back, and undo restores a decided one`() async {
        let server = FakeReviewServer()
        server.setVideos([.fixture("v1")])
        let session = ReviewSession(api: server.api)
        await session.load()

        server.failNext(.offline)
        await session.approveVideo("v1")
        expectNoDifference(session.videoCards.map(\.id), ["v1"])
        expectNoDifference(session.notice, .offline)

        await session.approveVideo("v1")
        await session.undoVideo()
        expectNoDifference(session.videoCards.map(\.id), ["v1"])
        expectNoDifference(session.lastVideoDecision, nil)
        expectNoDifference(server.calls.last, "undoVideo v1")
    }
}
