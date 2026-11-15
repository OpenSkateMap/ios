import AccountKit
import FactoryKit
import Observation
import PeopleKit
import SQLiteData

@MainActor
@Observable
final class PublicProfileModel {

    // MARK: Types

    enum Phase: Equatable {
        case loading
        case loaded
        /// No such person, or they blocked you; the server doesn't say which, and neither does the app.
        case unavailable
        case failed(String)
    }

    // MARK: Computed Properties

    var profile: PublicProfile? {
        storedProfile
    }

    var isYou: Bool {
        guard case .signedIn(let account) = authSession.phase else {
            return false
        }
        return account.id == userID
    }

    // MARK: Properties

    let userID: String
    private(set) var phase = Phase.loading
    private(set) var isLoading = false
    private(set) var isChangingBlock = false

    @ObservationIgnored @Fetch private var storedProfile: PublicProfile?
    @ObservationIgnored @Injected(\.authSession) private var authSession
    @ObservationIgnored @Injected(\.profileSession) private var profileSession

    // MARK: Lifecycle

    init(userID: String) {
        self.userID = userID
        _storedProfile = Fetch(
            wrappedValue: nil,
            ProfileRequest(personID: userID, account: Container.shared.profileSession().accountID),
        )
    }

    // MARK: Functions

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await profileSession.load(userID)
            phase = .loaded
        } catch PeopleAPIError.notFound {
            phase = .unavailable
        } catch {
            phase = profile == nil ? .failed(PeopleAPIError.message(for: error)) : .loaded
        }
    }

    func setBlocked(_ blocked: Bool) async throws {
        isChangingBlock = true
        defer { isChangingBlock = false }
        try await profileSession.setBlocked(userID, blocked)
    }
}
