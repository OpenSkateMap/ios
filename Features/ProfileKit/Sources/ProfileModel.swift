import AccountKit
import FactoryKit
import Observation
import PeopleKit
import SQLiteData
import SQLiteKit

@MainActor
@Observable
final class ProfileModel {

    // MARK: Computed Properties

    var account: Account? {
        guard case .signedIn(let account) = authSession.phase else {
            return nil
        }
        return account
    }

    var profile: PublicProfile? {
        storedProfile
    }

    // MARK: Properties

    private(set) var isDeletingAccount = false
    private(set) var loadFailed = false

    @ObservationIgnored @Fetch private var storedProfile: PublicProfile?
    @ObservationIgnored private var observedID: String?
    @ObservationIgnored @Injected(\.authSession) private var authSession
    @ObservationIgnored @Injected(\.profileSession) private var profileSession

    // MARK: Lifecycle

    init() {
        let account = Container.shared.profileSession().accountID
        observedID = account
        _storedProfile = Fetch(wrappedValue: nil, ProfileRequest(personID: account ?? "", account: account))
    }

    // MARK: Functions

    /// Throws for the caller that asks (a pull to refresh); the screen's own refresh ignores it.
    func load() async throws {
        guard let account else {
            return
        }
        do {
            if observedID != account.id {
                observedID = account.id
                try await $storedProfile.load(
                    ProfileRequest(personID: account.id, account: account.id),
                    scheduler: .backgroundRead,
                )
            }
            try await profileSession.load(account.id)
            loadFailed = false
        } catch {
            loadFailed = true
            throw error
        }
    }

    func signOut() async {
        await authSession.signOut()
    }

    func deleteAccount() async throws {
        guard !isDeletingAccount else {
            return
        }
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        try await authSession.deleteAccount()
    }
}
