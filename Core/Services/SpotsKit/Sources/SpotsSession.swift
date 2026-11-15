public import Observation
public import SpotModelKit

@MainActor
@Observable
public final class SpotsSession {

    // MARK: Computed Properties

    public var isSyncing: Bool {
        syncsRunning > 0
    }

    // MARK: Properties

    public private(set) var lastOutcome: SpotSyncEngine.Outcome?
    public private(set) var selectedID: String?
    public private(set) var selectedDetails = DetailsLoad.idle

    @ObservationIgnored private let engine: SpotSyncEngine
    @ObservationIgnored private let fetcher: DetailFetcher
    @ObservationIgnored private let api: SpotsAPIManager
    private var syncsRunning = 0
    @ObservationIgnored private var selecting: Task<Void, Never>?
    @ObservationIgnored private var voteFlights = [String: RequestFlight<SpotVoteTotals>]()
    @ObservationIgnored private var tickets = 0

    // MARK: Lifecycle

    public init(engine: SpotSyncEngine, fetcher: DetailFetcher, api: SpotsAPIManager) {
        self.engine = engine
        self.fetcher = fetcher
        self.api = api
    }

    // MARK: Functions

    /// `joining`: launch and foreground take a pass already under way (`SpotSyncEngine.sync(joining:)`).
    public func syncNow(joining: Bool = false) async {
        syncsRunning += 1
        let outcome = await engine.sync(joining: joining)
        syncsRunning -= 1
        lastOutcome = outcome
        if outcome == .synced {
            await fetcher.refresh()
        }
    }

    public func show(_ ids: [String]) {
        Task { await fetcher.show(ids) }
    }

    public func refreshDetails() async {
        do {
            try await engine.expireDetails()
        } catch {
            return
        }
        await fetcher.refresh()
    }

    public func vote(_ vote: SpotVote, on spotID: String) async throws {
        try await send(
            \.voteFlights,
            on: spotID,
            store: { [engine] in try await engine.applyVote(vote, on: spotID, requestedIn: $0) },
            request: { [api] in try await api.vote(vote, spotID) },
            settle: { [engine] in try await engine.applyVoteTotals($0, on: spotID, requestedIn: $1) },
        )
    }

    /// An admin's takedown; the spot leaves the index once the server agrees.
    public func takeDown(_ spotID: String, reason: SpotRemovalReason) async throws {
        try await api.takeDown(spotID, reason)
        try await engine.applyRemoval(of: spotID)
    }

    /// Undoes a takedown; the spot comes back with the next pass (a private one with the collections pull).
    public func restore(_ spotID: String) async throws {
        try await api.restore(spotID)
        await syncNow()
    }

    public func select(_ id: String?) {
        loadDetails(of: id, retrying: false)
    }

    public func retrySelectedDetails() {
        loadDetails(of: selectedID, retrying: true)
    }

    private func loadDetails(of id: String?, retrying: Bool) {
        selecting?.cancel()
        selectedID = id
        selectedDetails = id == nil ? .idle : .loading
        selecting = Task { [fetcher] in
            let failed = await fetcher.select(id, retrying: retrying)
            guard !Task.isCancelled else {
                return
            }
            selectedDetails = failed ? .failed : .idle
        }
    }

    /// Throws only for the newest of a burst; an older answer just updates what the server confirmed.
    private func send<Value: Sendable>(_ flights: ReferenceWritableKeyPath<SpotsSession, [String: RequestFlight<Value>]>,
                                       on spotID: String,
                                       store: (_ generation: Int) async throws -> Value?,
                                       request: () async throws -> Value,
                                       settle: (Value, _ generation: Int) async throws -> Void) async throws {
        tickets += 1
        let ticket = tickets
        self[keyPath: flights][spotID, default: RequestFlight()].start(ticket)
        let generation = await engine.generation
        let outcome: Result<Value, any Error>
        do {
            if let stored = try await store(generation) {
                self[keyPath: flights][spotID]?.stored(stored)
            }
            outcome = try await .success(request())
        } catch {
            outcome = .failure(error)
        }
        var flight = self[keyPath: flights][spotID] ?? RequestFlight()
        let settled =
            switch outcome {
            case .success(let value): flight.succeeded(ticket, with: value)
            case .failure: flight.failed(ticket)
            }
        let replaced = flight.newest != ticket
        self[keyPath: flights][spotID] = flight.isIdle ? nil : flight
        if let settled {
            try await settle(settled, generation)
        }
        if case .failure(let error) = outcome, !replaced {
            throw error
        }
    }
}
