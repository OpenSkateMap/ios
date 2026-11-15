import AuthenticationServices
import Foundation
public import Observation
import os

@MainActor
@Observable
public final class AuthSession {

    // MARK: Types

    public enum Phase: Equatable, Sendable {
        case signedOut(notice: SignedOutNotice?)
        case signingIn
        case signedIn(Account)
    }

    private enum State {
        case signedOut(notice: SignedOutNotice?)
        case signingIn
        case signedIn(SignedInAccount)
    }

    // MARK: Static Properties

    nonisolated static let storageKey = "auth.session"
    nonisolated static let installedKey = "account.installed"

    private nonisolated static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "auth")

    // MARK: Computed Properties

    public var phase: Phase {
        switch state {
        case .signedOut(let notice): .signedOut(notice: notice)
        case .signingIn: .signingIn
        case .signedIn(let session): .signedIn(session.account)
        }
    }

    public var sessionToken: String? {
        if case .signedIn(let session) = state {
            return session.token
        }
        return nil
    }

    // MARK: Properties

    private var state: State

    @ObservationIgnored private let apple: AppleSignInManager
    @ObservationIgnored private let api: AuthAPIManager
    @ObservationIgnored private let keychain: KeychainManager
    @ObservationIgnored private let endAccountScope: @MainActor () -> Void
    @ObservationIgnored private var refreshing: Task<Void, Never>?
    @ObservationIgnored private var watchingRevocations: Task<Void, Never>?

    // MARK: Lifecycle

    public init(apple: AppleSignInManager,
                api: AuthAPIManager,
                keychain: KeychainManager,
                endAccountScope: @escaping @MainActor () -> Void) {
        self.apple = apple
        self.api = api
        self.keychain = keychain
        self.endAccountScope = endAccountScope
        state = Self.restore(from: keychain).map(State.signedIn) ?? .signedOut(notice: nil)
        watchingRevocations = Task { [weak self, apple] in
            for await _ in apple.revocations() {
                guard let self, case .signedIn(let session) = state else {
                    continue
                }
                await endIfAppleRevoked(session)
            }
        }
    }

    // MARK: Static Functions

    /// Keychain items outlive deleting the app but UserDefaults don't: a session without this install's marker is dropped.
    nonisolated static func forgetSessionFromEarlierInstall(keychain: KeychainManager, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: installedKey) else {
            return
        }
        do {
            try keychain.delete(storageKey)
        } catch {
            logger.error("The earlier install's session wasn't removed: \(describe(error), privacy: .public)")
        }
        defaults.set(true, forKey: installedKey)
    }

    private static func restore(from keychain: KeychainManager) -> SignedInAccount? {
        let data: Data?
        do {
            data = try keychain.load(storageKey)
        } catch {
            // Unreadable now (the device is still locked, say) isn't gone: a later launch reads it.
            logger.error("The stored session couldn't be read: \(describe(error), privacy: .public)")
            return nil
        }
        guard let data else {
            return nil
        }
        do {
            return try JSONDecoder().decode(SignedInAccount.self, from: data)
        } catch {
            logger.error("Discarding the stored session: \(describe(error), privacy: .public)")
            try? keychain.delete(storageKey)
            return nil
        }
    }

    /// Never logs the payload: a `ClientError` describes the request, headers (the bearer token) included.
    private nonisolated static func describe(_ error: any Error) -> String {
        switch error {
        case let error as AuthAPIError: "AuthAPIError.\(error)"
        case let error as KeychainError: "KeychainError(\(error.status))"
        default: String(describing: type(of: error))
        }
    }

    private static func notice(forSignInError error: any Error) -> SignedOutNotice? {
        switch error {
        case AppleSignInError.canceled, is CancellationError: nil
        case is AppleSignInError: .appleSignInFailed
        case AuthAPIError.offline: .offline
        case AuthAPIError.unavailable: .serverUnavailable
        case AuthAPIError.forbidden: .accountDisabled
        default: .signInRejected
        }
    }

    // MARK: Functions

    public func signInWithApple() async {
        guard case .signedOut = state else {
            return
        }
        state = .signingIn
        do {
            let credential = try await apple.signIn()
            var session = try await api.signInWithApple(credential)
            session.appleUserID = credential.userID
            store(session)
            state = .signedIn(session)
        } catch {
            state = .signedOut(notice: Self.notice(forSignInError: error))
        }
    }

    public func refreshAccount() async {
        if let refreshing {
            return await refreshing.value
        }
        guard case .signedIn(let session) = state else {
            return
        }
        let task = Task { await refresh(session) }
        refreshing = task
        await task.value
        if refreshing == task {
            refreshing = nil
        }
    }

    public func signOut() async {
        guard case .signedIn(let session) = state else {
            return
        }
        endSession(notice: nil)
        do {
            try await api.signOut(session.token)
        } catch {
            Self.logger.notice("Server sign-out did not complete: \(Self.describe(error), privacy: .public)")
        }
    }

    public func deleteAccount() async throws {
        guard case .signedIn(let session) = state else {
            return
        }
        do {
            try await api.deleteAccount(session.token)
        } catch AuthAPIError.unauthorized {
            endSession(ifCurrent: session.token, notice: .sessionExpired)
            throw AuthAPIError.unauthorized
        }
        endSession(ifCurrent: session.token, notice: .accountDeleted)
    }

    public func sessionRefused(token: String) {
        endSession(ifCurrent: token, notice: .sessionExpired)
    }

    private func refresh(_ session: SignedInAccount) async {
        guard await !endIfAppleRevoked(session) else {
            return
        }
        do {
            let account = try await api.me(session.token)
            guard case .signedIn(let current) = state, current.token == session.token else {
                return
            }
            var refreshed = current
            refreshed.account = account
            store(refreshed)
            state = .signedIn(refreshed)
        } catch AuthAPIError.unauthorized {
            endSession(ifCurrent: session.token, notice: .sessionExpired)
        } catch AuthAPIError.forbidden {
            endSession(ifCurrent: session.token, notice: .accountDisabled)
        } catch {
            Self.logger.notice("Account refresh failed; keeping the stored account: \(Self.describe(error), privacy: .public)")
        }
    }

    /// Apple sends no notice when someone deletes their Apple Account, so this runs on every refresh too.
    @discardableResult
    private func endIfAppleRevoked(_ session: SignedInAccount) async -> Bool {
        guard let userID = session.appleUserID else {
            return false
        }
        let credential: ASAuthorizationAppleIDProvider.CredentialState
        do {
            credential = try await apple.credentialState(userID)
        } catch {
            Self.logger.notice("Apple ID state unknown; keeping the session: \(Self.describe(error), privacy: .public)")
            return false
        }
        guard credential == .revoked || credential == .notFound else {
            return false
        }
        guard case .signedIn(let current) = state, current.token == session.token else {
            return true
        }
        endSession(notice: .sessionExpired)
        do {
            try await api.signOut(session.token)
        } catch {
            Self.logger.notice("Server sign-out did not complete: \(Self.describe(error), privacy: .public)")
        }
        return true
    }

    private func endSession(ifCurrent token: String, notice: SignedOutNotice) {
        guard case .signedIn(let current) = state, current.token == token else {
            return
        }
        endSession(notice: notice)
    }

    private func endSession(notice: SignedOutNotice?) {
        refreshing?.cancel()
        refreshing = nil
        do {
            try keychain.delete(Self.storageKey)
        } catch {
            Self.logger.error("Could not delete the stored session: \(Self.describe(error), privacy: .public)")
        }
        state = .signedOut(notice: notice)
        endAccountScope()
    }

    private func store(_ session: SignedInAccount) {
        do {
            try keychain.save(JSONEncoder().encode(session), Self.storageKey)
        } catch {
            Self.logger.error("Could not store the session: \(Self.describe(error), privacy: .public)")
        }
    }

}
