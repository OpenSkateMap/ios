public import Foundation
public import IdentifiedCollections
public import Observation

// MARK: - ReviewSession

@MainActor
@Observable
public final class ReviewSession {

    // MARK: Types

    public enum Phase: Equatable, Sendable {
        case idle
        case loading
        case loaded
        case failed(Notice)
    }

    public enum Notice: Equatable, Sendable {
        case offline
        case unavailable
        case signedOut
        case outsideYourCities
        case changedSinceOpened
        case refused(String)
        indirect case undoFailed(Notice)
    }

    public struct Decision: Equatable, Sendable {
        public enum Verdict: Equatable, Sendable {
            case approved(spotID: String?, title: String)
            case rejected(RejectReason)
        }

        public let card: ReviewCard
        public let verdict: Verdict
    }

    public struct VideoDecision: Equatable, Sendable {
        public enum Verdict: Equatable, Sendable {
            case approved
            case rejected(VideoRejectReason)
        }

        public let card: VideoReviewCard
        public let verdict: Verdict
    }

    // MARK: Static Properties

    /// The server's page limit.
    static let pageSize = 50

    // MARK: Properties

    public private(set) var cards = IdentifiedArrayOf<ReviewCard>()
    public private(set) var phase = Phase.idle
    public private(set) var isQueueKnown = false
    public private(set) var notice: Notice?
    public private(set) var lastDecision: Decision?
    public private(set) var deciding = Set<ReviewCard.ID>()
    public private(set) var videoCards = IdentifiedArrayOf<VideoReviewCard>()
    public private(set) var lastVideoDecision: VideoDecision?
    public private(set) var isUndoing = false

    @ObservationIgnored private let api: ReviewAPIManager
    @ObservationIgnored private let store: ReviewQueueStore
    @ObservationIgnored private let storeGeneration: Int
    @ObservationIgnored private var loading: Task<Void, Never>?
    @ObservationIgnored private var decided = Set<String>()

    // MARK: Lifecycle

    public init(api: ReviewAPIManager, store: ReviewQueueStore = .none) {
        self.api = api
        self.store = store
        // One session per account: once its account ends, nothing it still has in flight gets cached.
        storeGeneration = store.generation()
    }

    // MARK: Static Functions

    private static func notice(for error: ReviewAPIError) -> Notice {
        switch error {
        case .unauthorized: .signedOut
        case .offline: .offline
        case .unavailable: .unavailable
        case .forbidden: .outsideYourCities
        case .conflict: .changedSinceOpened
        case .rejected(let message): .refused(message)
        }
    }

    // MARK: Functions

    public func load() async {
        if let loading {
            return await loading.value
        }
        let isFirst = phase == .idle
        phase = .loading
        let task = Task {
            await fetch(restoring: isFirst)
            loading = nil
        }
        loading = task
        await task.value
    }

    /// False when it didn't go through: the card is back (or gone, when it's no longer the reviewer's) and `notice` says why.
    /// `seenUpdatedAt` is the version an editor showed, which can be older than the queue's copy.
    @discardableResult
    public func approve(_ id: ReviewCard.ID, edits: SpotEdits = .none, seenUpdatedAt: Date? = nil) async -> Bool {
        await decide(id, in: \.cards, record: { self.lastDecision = Decision(card: $0, verdict: $1) }) { [api] card in
            let decided = try await api.approve(card.id, edits, seenUpdatedAt ?? card.updatedAt)
            return .approved(spotID: decided.spotID, title: edits.title ?? card.title)
        }
    }

    @discardableResult
    public func reject(_ id: ReviewCard.ID, reason: RejectReason) async -> Bool {
        await decide(id, in: \.cards, record: { self.lastDecision = Decision(card: $0, verdict: $1) }) { [api] card in
            _ = try await api.reject(card.id, reason, card.updatedAt)
            return .rejected(reason)
        }
    }

    public func undo() async {
        guard let decision = lastDecision, !isUndoing else {
            return
        }
        lastDecision = nil
        isUndoing = true
        defer { isUndoing = false }
        await undo(decision.card, in: \.cards, send: { try await self.api.undo($0).updatedAt }) { self.lastDecision = decision }
    }

    @discardableResult
    public func approveVideo(_ id: VideoReviewCard.ID) async -> Bool {
        await decide(id, in: \.videoCards, record: { self.lastVideoDecision = VideoDecision(card: $0, verdict: $1) }) {
            [api] card in
            _ = try await api.approveVideo(card.id, card.updatedAt)
            return .approved
        }
    }

    @discardableResult
    public func rejectVideo(_ id: VideoReviewCard.ID, reason: VideoRejectReason) async -> Bool {
        await decide(id, in: \.videoCards, record: { self.lastVideoDecision = VideoDecision(card: $0, verdict: $1) }) {
            [api] card in
            _ = try await api.rejectVideo(card.id, reason, card.updatedAt)
            return .rejected(reason)
        }
    }

    public func undoVideo() async {
        guard let decision = lastVideoDecision, !isUndoing else {
            return
        }
        lastVideoDecision = nil
        isUndoing = true
        defer { isUndoing = false }
        await undo(decision.card, in: \.videoCards, send: { try await self.api.undoVideo($0).updatedAt }) {
            self.lastVideoDecision = decision
        }
    }

    public func forgetLastVideoDecision() {
        lastVideoDecision = nil
    }

    public func dismissNotice() {
        notice = nil
    }

    public func forgetLastDecision() {
        lastDecision = nil
    }

    private func fetch(restoring: Bool) async {
        decided = []
        if restoring, let cached = await store.load() {
            cards = IdentifiedArray(cached.cards.filter { !deciding.contains($0.id) }) { first, _ in first }
            videoCards = IdentifiedArray(cached.videos.filter { !deciding.contains($0.id) }) { first, _ in first }
            isQueueKnown = true
        }
        do {
            let queue = try await api.queue(nil, Self.pageSize)
            let settled = deciding.union(decided)
            cards = IdentifiedArray(queue.cards.filter { !settled.contains($0.id) }) { first, _ in first }
            videoCards = IdentifiedArray(queue.videos.filter { !settled.contains($0.id) }) { first, _ in first }
            phase = .loaded
            isQueueKnown = true
            await saveQueue()
        } catch let error as ReviewAPIError {
            phase = .failed(Self.notice(for: error))
        } catch {
            phase = .failed(.unavailable)
        }
    }

    /// A load already out may have read the queue before the refusal, so this one goes out after it.
    private func reloadAfterRefusal() async {
        await loading?.value
        await load()
    }

    private func decide<Card: ReviewItem, Verdict>(_ id: String,
                                                   in list: ReferenceWritableKeyPath<ReviewSession, IdentifiedArrayOf<Card>>,
                                                   record: (Card, Verdict) -> Void,
                                                   _ send: (Card) async throws -> Verdict) async -> Bool {
        guard !deciding.contains(id) else {
            return false
        }
        guard let index = self[keyPath: list].index(id: id) else {
            notice = .changedSinceOpened
            return false
        }
        let card = self[keyPath: list].remove(at: index)
        deciding.insert(id)
        defer { deciding.remove(id) }
        do {
            let verdict = try await send(card)
            decided.insert(id)
            record(card, verdict)
            notice = nil
            await saveQueue()
            return true
        } catch let error as ReviewAPIError {
            notice = Self.notice(for: error)
            switch error {
            case .offline, .unavailable, .rejected:
                self[keyPath: list].insert(card, at: min(index, self[keyPath: list].count))

            case .conflict, .forbidden:
                // The server's queue says whether it's still this reviewer's: a pin moved outside their cities leaves it there.
                deciding.remove(id)
                await reloadAfterRefusal()
                if case .forbidden = error, case .failed = phase {
                    self[keyPath: list].insert(card, at: min(index, self[keyPath: list].count))
                }

            case .unauthorized:
                break
            }
            return false
        } catch {
            notice = .unavailable
            self[keyPath: list].insert(card, at: min(index, self[keyPath: list].count))
            return false
        }
    }

    private func undo<Card: ReviewItem>(_ card: Card,
                                        in list: ReferenceWritableKeyPath<ReviewSession, IdentifiedArrayOf<Card>>,
                                        send: (String) async throws -> Date,
                                        keepUndoable: () -> Void) async {
        do {
            var card = card
            card.updatedAt = try await send(card.id)
            decided.remove(card.id)
            self[keyPath: list].remove(id: card.id)
            self[keyPath: list].insert(card, at: 0)
            await saveQueue()
        } catch let error as ReviewAPIError {
            if error == .offline || error == .unavailable {
                keepUndoable()
            }
            notice = .undoFailed(Self.notice(for: error))
        } catch {
            notice = .undoFailed(.unavailable)
        }
    }

    private func saveQueue() async {
        await store.save(ReviewQueue(cityIDs: nil, cards: cards.elements, videos: videoCards.elements), storeGeneration)
    }
}

// MARK: - ReviewItem

protocol ReviewItem: Identifiable where ID == String {
    var updatedAt: Date { get set }
}

// MARK: - ReviewCard + ReviewItem

extension ReviewCard: ReviewItem { }

// MARK: - VideoReviewCard + ReviewItem

extension VideoReviewCard: ReviewItem { }
