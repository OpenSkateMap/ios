import CustomDump
import Foundation
import SpotModelKit
import SQLiteData
import SQLiteKit
import Testing
@testable import SpotsKit

// MARK: - SpotVoteTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SpotVoteTests {
    private let votes = FakeVoteServer()
    private let database: any DatabaseWriter
    private let engine: SpotSyncEngine
    private let session: SpotsSession

    init() throws {
        database = try AppDatabase.inMemory(schemas: [.spots])
        try database.write { db in
            try SpotIndex.insert {
                SpotIndex(
                    id: "s1",
                    title: "Spot",
                    kind: .street,
                    condition: .skateable,
                    cityID: nil,
                    latitude: 1,
                    longitude: 1,
                    version: 1,
                )
            }
            .execute(db)
            try SpotDetail.insert {
                SpotDetail(
                    id: "s1",
                    about: "",
                    obstacles: [],
                    addedByID: nil,
                    addedByName: nil,
                    createdAt: .distantPast,
                    version: 1,
                    fetchedAt: .distantPast,
                    upvotes: 3,
                    downvotes: 1,
                    myVote: .none,
                )
            }
            .execute(db)
        }
        var api = FakeDetailServer().api
        api.vote = { [votes] in try await votes.vote($0, on: $1) }
        engine = SpotSyncEngine(api: api, database: database)
        session = SpotsSession(engine: engine, fetcher: DetailFetcher(api: api, engine: engine, database: database), api: api)
    }

    @Test
    func `a vote moves the totals the way the server counts them`() {
        let mine = SpotVoteTotals(up: 3, down: 1, mine: .up)

        expectNoDifference(mine.voting(.down), SpotVoteTotals(up: 2, down: 2, mine: .down))
        expectNoDifference(mine.voting(.none), SpotVoteTotals(up: 2, down: 1, mine: .none))
        expectNoDifference(mine.voting(.up), mine)
    }

    @Test
    func `a vote shows at once, then takes the server's totals`() async throws {
        var requests = votes.requests.makeAsyncIterator()
        let voting = Task { try await session.vote(.up, on: "s1") }

        let request = await requests.next()
        expectNoDifference(request, FakeVoteServer.Request(vote: .up, spotID: "s1"))
        expectNoDifference(try totals(), SpotVoteTotals(up: 4, down: 1, mine: .up))

        await votes.answer(0, with: .success(SpotVoteTotals(up: 9, down: 2, mine: .up)))
        try await voting.value
        expectNoDifference(try totals(), SpotVoteTotals(up: 9, down: 2, mine: .up))
    }

    @Test
    func `a vote the server refuses goes back and throws`() async throws {
        var requests = votes.requests.makeAsyncIterator()
        let voting = Task { try await session.vote(.down, on: "s1") }
        _ = await requests.next()
        expectNoDifference(try totals(), SpotVoteTotals(up: 3, down: 2, mine: .down))

        await votes.answer(0, with: .failure(.offline))

        await #expect(throws: SpotsAPIError.offline) { try await voting.value }
        expectNoDifference(try totals(), SpotVoteTotals(up: 3, down: 1, mine: .none))
    }

    @Test
    func `the newest vote wins over a late answer to the one it replaced`() async throws {
        var requests = votes.requests.makeAsyncIterator()
        let up = Task { try await session.vote(.up, on: "s1") }
        _ = await requests.next()
        let down = Task { try await session.vote(.down, on: "s1") }
        _ = await requests.next()
        expectNoDifference(try totals(), SpotVoteTotals(up: 3, down: 2, mine: .down))

        await votes.answer(1, with: .success(SpotVoteTotals(up: 3, down: 2, mine: .down)))
        try await down.value
        await votes.answer(0, with: .failure(.offline))

        try await up.value
        expectNoDifference(try totals(), SpotVoteTotals(up: 3, down: 2, mine: .down))
    }

    @Test
    func `when the newest vote fails, the spot goes back to what the server last confirmed`() async throws {
        var requests = votes.requests.makeAsyncIterator()
        let up = Task { try await session.vote(.up, on: "s1") }
        _ = await requests.next()
        let down = Task { try await session.vote(.down, on: "s1") }
        _ = await requests.next()

        await votes.answer(0, with: .success(SpotVoteTotals(up: 4, down: 1, mine: .up)))
        try await up.value
        expectNoDifference(try totals(), SpotVoteTotals(up: 3, down: 2, mine: .down))

        await votes.answer(1, with: .failure(.unavailable))

        await #expect(throws: SpotsAPIError.unavailable) { try await down.value }
        expectNoDifference(try totals(), SpotVoteTotals(up: 4, down: 1, mine: .up))
    }

    @Test
    func `a detail answer requested before a vote keeps the vote`() async throws {
        let stamp = await engine.detailStamp()
        _ = try await engine.applyVote(.up, on: "s1", requestedIn: engine.generation)

        try await engine.applyDetails(page(about: "Fresh", votes: SpotVoteTotals(up: 3, down: 1)), requestedAt: stamp)

        let about = try await database.read { db in try SpotDetail.find("s1").fetchOne(db)?.about }
        expectNoDifference(about, "Fresh")
        expectNoDifference(try totals(), SpotVoteTotals(up: 4, down: 1, mine: .up))

        try await engine.applyDetails(
            page(about: "Fresh", votes: SpotVoteTotals(up: 8, down: 1, mine: .up)),
            requestedAt: engine.detailStamp(),
        )

        expectNoDifference(try totals(), SpotVoteTotals(up: 8, down: 1, mine: .up))
    }

    // MARK: Helpers

    private func totals() throws -> SpotVoteTotals {
        try SpotVoteTotals(#require(database.read { db in try SpotDetail.find("s1").fetchOne(db) }))
    }

    private func page(about: String, votes: SpotVoteTotals) -> SpotDetailsPage {
        SpotDetailsPage(
            spots: [
                RemoteSpotDetail(
                    id: "s1",
                    about: about,
                    obstacles: [],
                    addedByID: nil,
                    addedByName: nil,
                    createdAt: .distantPast,
                    version: 1,
                    photos: [],
                    votes: votes,
                )
            ],
            missing: [],
        )
    }
}

// MARK: - FakeVoteServer

actor FakeVoteServer {

    // MARK: Types

    struct Request: Equatable, Sendable {
        var vote: SpotVote
        var spotID: String
    }

    // MARK: Properties

    nonisolated let requests: AsyncStream<Request>

    private nonisolated let reported: AsyncStream<Request>.Continuation
    private var answers = [CheckedContinuation<SpotVoteTotals, any Error>]()

    // MARK: Lifecycle

    init() {
        (requests, reported) = AsyncStream.makeStream()
    }

    // MARK: Functions

    func vote(_ vote: SpotVote, on spotID: String) async throws -> SpotVoteTotals {
        try await withCheckedThrowingContinuation { answer in
            answers.append(answer)
            reported.yield(Request(vote: vote, spotID: spotID))
        }
    }

    func answer(_ index: Int, with result: Result<SpotVoteTotals, SpotsAPIError>) {
        answers[index].resume(with: result)
    }
}
