import AuthenticationServices
import CustomDump
import Foundation
import Synchronization
import Testing
@testable import AccountKit

// MARK: - AuthSessionTests

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct AuthSessionTests {
    @Test
    func `signing in with Apple stores the session and signs in`() async throws {
        let calls = Calls()
        let keychain = KeychainManager.inMemory()
        let session = AuthSession(
            apple: AppleSignInManager { .skater },
            api: .stub(signInWithApple: { credential in
                calls.record("signIn \(credential.identityToken) \(credential.rawNonce)")
                return SignedInAccount(token: "skater-token", account: .skater)
            }),
            keychain: keychain,
            endAccountScope: { },
        )

        await session.signInWithApple()

        expectNoDifference(session.phase, .signedIn(.skater))
        expectNoDifference(calls.values, ["signIn apple-identity-token raw-nonce-0123456789"])
        expectNoDifference(try stored(in: keychain), .skater)
    }

    @Test
    func `closing Apple's sheet returns to signed out with no notice and no API call`() async {
        let calls = Calls()
        let session = AuthSession(
            apple: AppleSignInManager { throw AppleSignInError.canceled },
            api: .stub(signInWithApple: { _ in
                calls.record("signIn")
                return .skater
            }),
            keychain: .inMemory(),
            endAccountScope: { },
        )

        await session.signInWithApple()

        expectNoDifference(session.phase, .signedOut(notice: nil))
        expectNoDifference(calls.values, [])
    }

    @Test
    func `a failed sign-in returns to signed out with a notice that says why`() async {
        let appleFails = AuthSession(
            apple: AppleSignInManager { throw AppleSignInError.failed(code: 1000) },
            api: .stub(),
            keychain: .inMemory(),
            endAccountScope: { },
        )
        let offline = AuthSession(
            apple: AppleSignInManager { .skater },
            api: .stub(signInWithApple: { _ in throw AuthAPIError.offline }),
            keychain: .inMemory(),
            endAccountScope: { },
        )

        await appleFails.signInWithApple()
        await offline.signInWithApple()

        expectNoDifference(appleFails.phase, .signedOut(notice: .appleSignInFailed))
        expectNoDifference(offline.phase, .signedOut(notice: .offline))
    }

    @Test
    func `a session left from an earlier install is dropped once; later launches keep theirs`() throws {
        let defaults = try #require(UserDefaults(suiteName: "AuthSessionTests.\(UUID().uuidString)"))
        let reinstalled = KeychainManager.storing(.skater)

        AuthSession.forgetSessionFromEarlierInstall(keychain: reinstalled, defaults: defaults)
        let first = AuthSession(apple: .unused, api: .stub(), keychain: reinstalled, endAccountScope: { })
        let later = KeychainManager.storing(.skater)
        AuthSession.forgetSessionFromEarlierInstall(keychain: later, defaults: defaults)
        let second = AuthSession(apple: .unused, api: .stub(), keychain: later, endAccountScope: { })

        expectNoDifference(first.phase, .signedOut(notice: nil))
        expectNoDifference(second.phase, .signedIn(.skater))
    }

    @Test
    func `a stored session is restored signed in before any network call`() {
        let session = AuthSession(apple: .unused, api: .stub(), keychain: .storing(.skater), endAccountScope: { })

        expectNoDifference(session.phase, .signedIn(.skater))
    }

    @Test
    func `a session the Keychain can't read now is kept for a later launch; one that doesn't decode is dropped`() {
        let deleted = Calls()
        let locked = KeychainManager(
            load: { _ in throw KeychainError(status: errSecInteractionNotAllowed) },
            save: { _, _ in },
            delete: { key in deleted.record(key) },
        )
        let garbled = KeychainManager.inMemory([AuthSession.storageKey: Data("not json".utf8)])

        let unreadable = AuthSession(apple: .unused, api: .stub(), keychain: locked, endAccountScope: { })
        let undecodable = AuthSession(apple: .unused, api: .stub(), keychain: garbled, endAccountScope: { })

        expectNoDifference(unreadable.phase, .signedOut(notice: nil))
        expectNoDifference(deleted.values, [])
        expectNoDifference(undecodable.phase, .signedOut(notice: nil))
        expectNoDifference(try? garbled.load(AuthSession.storageKey), .some(nil))
    }

    @Test
    func `refreshing replaces the stored account with the server's`() async throws {
        let renamed = Account(
            id: Account.skater.id,
            name: "Renamed Skater",
            email: Account.skater.email,
            role: .editor,
            createdAt: Account.skater.createdAt,
        )
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(me: { token in
                #expect(token == SignedInAccount.skater.token)
                return renamed
            }),
            keychain: keychain,
            endAccountScope: { },
        )

        await session.refreshAccount()

        expectNoDifference(session.phase, .signedIn(renamed))
        expectNoDifference(try stored(in: keychain)?.account, renamed)
    }

    @Test
    func `a 401 from the API signs out locally and clears the stored session`() async throws {
        let scopeResets = Calls()
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(me: { _ in throw AuthAPIError.unauthorized }),
            keychain: keychain,
            endAccountScope: { scopeResets.record("reset") },
        )

        await session.refreshAccount()

        expectNoDifference(session.phase, .signedOut(notice: .sessionExpired))
        expectNoDifference(try stored(in: keychain), nil)
        expectNoDifference(scopeResets.values, ["reset"])
    }

    @Test
    func `an offline refresh keeps the stored account`() async throws {
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(me: { _ in throw AuthAPIError.offline }),
            keychain: keychain,
            endAccountScope: { },
        )

        await session.refreshAccount()

        expectNoDifference(session.phase, .signedIn(.skater))
        expectNoDifference(try stored(in: keychain), .skater)
    }

    @Test
    func `signing out clears the token, resets the account scope and tells the server`() async throws {
        let calls = Calls()
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(signOut: { token in calls.record("signOut \(token)") }),
            keychain: keychain,
            endAccountScope: { calls.record("reset scope") },
        )

        await session.signOut()

        expectNoDifference(session.phase, .signedOut(notice: nil))
        expectNoDifference(try stored(in: keychain), nil)
        expectNoDifference(calls.values, ["reset scope", "signOut skater-token"])
    }

    @Test
    func `signing out works offline`() async throws {
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(signOut: { _ in throw AuthAPIError.offline }),
            keychain: keychain,
            endAccountScope: { },
        )

        await session.signOut()

        expectNoDifference(session.phase, .signedOut(notice: nil))
        expectNoDifference(try stored(in: keychain), nil)
    }

    @Test
    func `deleting the account deletes it on the server, then signs out`() async throws {
        let calls = Calls()
        let keychain = KeychainManager.storing(.skater)
        let session = AuthSession(
            apple: .unused,
            api: .stub(deleteAccount: { token in calls.record("delete \(token)") }),
            keychain: keychain,
            endAccountScope: { },
        )

        try await session.deleteAccount()

        expectNoDifference(calls.values, ["delete skater-token"])
        expectNoDifference(session.phase, .signedOut(notice: .accountDeleted))
        expectNoDifference(try stored(in: keychain), nil)
    }

    @Test
    func `a failed deletion keeps the account signed in`() async throws {
        let session = AuthSession(
            apple: .unused,
            api: .stub(deleteAccount: { _ in throw AuthAPIError.unavailable }),
            keychain: .storing(.skater),
            endAccountScope: { },
        )

        await #expect(throws: AuthAPIError.unavailable) {
            try await session.deleteAccount()
        }
        expectNoDifference(session.phase, .signedIn(.skater))
    }

    @Test
    func `a revoked or deleted Apple ID ends the session on refresh and signs out on the server`() async throws {
        for appleState in [ASAuthorizationAppleIDProvider.CredentialState.revoked, .notFound] {
            let calls = Calls()
            let keychain = KeychainManager.storing(.skater)
            let session = AuthSession(
                apple: .checking { userID in
                    calls.record("check \(userID)")
                    return appleState
                },
                api: .stub(signOut: { token in calls.record("signOut \(token)") }),
                keychain: keychain,
                endAccountScope: { calls.record("reset scope") },
            )

            await session.refreshAccount()

            expectNoDifference(session.phase, .signedOut(notice: .sessionExpired))
            expectNoDifference(try stored(in: keychain), nil)
            expectNoDifference(calls.values, ["check apple-user-1", "reset scope", "signOut skater-token"])
        }
    }

    @Test
    func `an Apple ID that is still authorized, or whose state can't be read, keeps the session`() async {
        let authorized = AuthSession(
            apple: .checking { _ in .authorized },
            api: .stub(me: { _ in .skater }),
            keychain: .storing(.skater),
            endAccountScope: { },
        )
        let unreadable = AuthSession(
            apple: .checking { _ in throw ASAuthorizationError(.failed) },
            api: .stub(me: { _ in .skater }),
            keychain: .storing(.skater),
            endAccountScope: { },
        )

        await authorized.refreshAccount()
        await unreadable.refreshAccount()

        expectNoDifference(authorized.phase, .signedIn(.skater))
        expectNoDifference(unreadable.phase, .signedIn(.skater))
    }

    @Test
    func `a session stored without an Apple ID isn't checked`() async {
        let calls = Calls()
        let session = AuthSession(
            apple: .checking { userID in
                calls.record("check \(userID)")
                return .revoked
            },
            api: .stub(me: { _ in .skater }),
            keychain: .storing(SignedInAccount(token: "skater-token", account: .skater)),
            endAccountScope: { },
        )

        await session.refreshAccount()

        expectNoDifference(session.phase, .signedIn(.skater))
        expectNoDifference(calls.values, [])
    }

    @Test
    func `Apple's revocation notice checks the credential at once`() async {
        let revocations = AsyncStream<Void>.makeStream()
        let signedOut = AsyncStream<Void>.makeStream()
        let session = AuthSession(
            apple: AppleSignInManager(
                signIn: unusedSignIn,
                credentialState: { _ in .revoked },
                revocations: { revocations.stream },
            ),
            api: .stub(signOut: { _ in signedOut.continuation.yield() }),
            keychain: .storing(.skater),
            endAccountScope: { },
        )

        revocations.continuation.yield()
        for await _ in signedOut.stream {
            break
        }

        expectNoDifference(session.phase, .signedOut(notice: .sessionExpired))
    }

    private func stored(in keychain: KeychainManager) throws -> SignedInAccount? {
        try keychain.load(AuthSession.storageKey).map { try JSONDecoder().decode(SignedInAccount.self, from: $0) }
    }
}

// MARK: - Fixtures

extension Account {
    static let skater = Account(
        id: "user-1",
        name: "Test Skater",
        email: "skater@privaterelay.appleid.com",
        role: .user,
        createdAt: Date(timeIntervalSince1970: 1_791_590_400),
    )
}

extension SignedInAccount {
    static let skater = SignedInAccount(token: "skater-token", account: .skater, appleUserID: "apple-user-1")
}

extension AppleCredential {
    static let skater = AppleCredential(
        userID: "apple-user-1",
        identityToken: "apple-identity-token",
        rawNonce: "raw-nonce-0123456789",
    )
}

extension AppleSignInManager {
    static let unused = AppleSignInManager(signIn: unusedSignIn)

    typealias CredentialState = ASAuthorizationAppleIDProvider.CredentialState

    static func checking(_ state: @escaping @Sendable (String) async throws -> CredentialState) -> AppleSignInManager {
        AppleSignInManager(signIn: unusedSignIn, credentialState: state, revocations: { AsyncStream { $0.finish() } })
    }
}

@Sendable
func unusedSignIn() async throws -> AppleCredential {
    Issue.record("Apple sign-in was not expected")
    throw AppleSignInError.canceled
}

extension AuthAPIManager {
    static func stub(signInWithApple: @escaping @Sendable (AppleCredential) async throws -> SignedInAccount = unexpected,
                     me: @escaping @Sendable (String) async throws -> Account = unexpected,
                     signOut: @escaping @Sendable (String) async throws -> Void = unexpected,
                     deleteAccount: @escaping @Sendable (String) async throws -> Void = unexpected) -> AuthAPIManager {
        AuthAPIManager(signInWithApple: signInWithApple, me: me, signOut: signOut, deleteAccount: deleteAccount)
    }
}

extension KeychainManager {
    static func storing(_ session: SignedInAccount) -> KeychainManager {
        // swiftformat:disable:next noForceTryInTests
        .inMemory([AuthSession.storageKey: try! JSONEncoder().encode(session)])
    }
}

@Sendable
func unexpected<Input, Output>(_: Input) async throws -> Output {
    Issue.record("Unexpected API call")
    throw AuthAPIError.rejected
}

// MARK: - Calls

final class Calls: Sendable {

    // MARK: Computed Properties

    var values: [String] {
        storage.withLock { $0 }
    }

    // MARK: Properties

    private let storage = Mutex<[String]>([])

    // MARK: Functions

    func record(_ call: String) {
        storage.withLock { $0.append(call) }
    }
}
