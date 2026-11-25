import AccountKit
import FactoryKit
import IdentifiedCollections
import Observation
import ReviewKit
import SpotModelKit
import SQLiteData

@MainActor
@Observable
final class ReviewQueueModel {

    // MARK: Computed Properties

    var cards: IdentifiedArrayOf<ReviewCard> {
        session.cards
    }

    var phase: ReviewSession.Phase {
        session.phase
    }

    var notice: ReviewSession.Notice? {
        session.notice
    }

    var lastDecision: ReviewSession.Decision? {
        session.lastDecision
    }

    var videoCount: Int {
        session.videoCards.count
    }

    var hasDecisionsInFlight: Bool {
        !session.deciding.isEmpty
    }

    var isQueueKnown: Bool {
        session.isQueueKnown
    }

    var isUndoing: Bool {
        session.isUndoing
    }

    var isCurator: Bool {
        authSession.isCurator
    }

    // MARK: Properties

    @ObservationIgnored @FetchAll(City.all) private var cities
    @ObservationIgnored @Injected(\.reviewSession) private var session
    @ObservationIgnored @Injected(\.authSession) private var authSession

    // MARK: Functions

    func cityName(for id: String?) -> String? {
        id.flatMap { id in cities.first { $0.id == id }?.localizedName ?? session.cities[id: id]?.localizedName }
    }

    func isDeciding(_ id: ReviewCard.ID) -> Bool {
        session.deciding.contains(id)
    }

    func load() async {
        await session.load()
    }

    func approve(_ id: ReviewCard.ID) async {
        await session.approve(id)
    }

    func reject(_ id: ReviewCard.ID, reason: RejectReason) {
        Task { await session.reject(id, reason: reason) }
    }

    func undo() async {
        await session.undo()
    }

    func dismissNotice() {
        session.dismissNotice()
    }

    func forgetLastDecision() {
        session.forgetLastDecision()
    }
}
