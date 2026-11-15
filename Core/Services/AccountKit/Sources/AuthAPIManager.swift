public import APIClientKit
import Foundation
public import OpenAPIRuntime

// MARK: - AuthAPIManager

public struct AuthAPIManager: Sendable {
    public var signInWithApple: @Sendable (_ credential: AppleCredential) async throws -> SignedInAccount
    public var me: @Sendable (_ token: String) async throws -> Account
    public var signOut: @Sendable (_ token: String) async throws -> Void
    public var deleteAccount: @Sendable (_ token: String) async throws -> Void

    public init(signInWithApple: @escaping @Sendable (_ credential: AppleCredential) async throws -> SignedInAccount,
                me: @escaping @Sendable (_ token: String) async throws -> Account,
                signOut: @escaping @Sendable (_ token: String) async throws -> Void,
                deleteAccount: @escaping @Sendable (_ token: String) async throws -> Void) {
        self.signInWithApple = signInWithApple
        self.me = me
        self.signOut = signOut
        self.deleteAccount = deleteAccount
    }
}

// MARK: - AuthAPIError

public enum AuthAPIError: Error, Equatable {
    case unauthorized
    case forbidden
    case rejected
    case unavailable
    case offline
}

extension AuthAPIManager {
    public static func live(makeClient: @escaping @Sendable ([any ClientMiddleware]) -> Client) -> AuthAPIManager {
        @Sendable
        func client(_ token: String?) -> Client {
            makeClient(token.map { [BearerTokenMiddleware(token: $0)] } ?? [])
        }

        return AuthAPIManager(
            signInWithApple: { credential in
                let body = Components.Schemas.SignInWithAppleRequest(
                    idToken: credential.identityToken,
                    nonce: credential.rawNonce,
                    givenName: credential.givenName.nonEmpty,
                    familyName: credential.familyName.nonEmpty,
                    authorizationCode: credential.authorizationCode.nonEmpty,
                )
                let session = try await withAPIFailures(offline: AuthAPIError.offline, AuthAPIError.init) {
                    try await client(nil).signInWithApple(body: .json(body)).ok.body.json.data
                }
                return SignedInAccount(token: session.token, account: Account(session.user))
            },
            me: { token in
                try await Account(withAPIFailures(offline: AuthAPIError.offline, AuthAPIError.init) {
                    try await client(token).getMe().ok.body.json.data
                })
            },
            signOut: { token in
                _ = try await withAPIFailures(offline: AuthAPIError.offline, AuthAPIError.init) {
                    try await client(token).signOut().ok
                }
            },
            deleteAccount: { token in
                _ = try await withAPIFailures(offline: AuthAPIError.offline, AuthAPIError.init) {
                    try await client(token).deleteMe().ok
                }
            },
        )
    }

    public static let preview = AuthAPIManager(
        signInWithApple: { _ in SignedInAccount(token: "preview-token", account: .preview) },
        me: { _ in .preview },
        signOut: { _ in },
        deleteAccount: { _ in },
    )
}

extension AuthAPIError {
    fileprivate init(_ failure: APIFailure) {
        switch failure.status {
        case 401: self = .unauthorized
        case 403: self = .forbidden
        case 429, 500...: self = .unavailable
        default: self = .rejected
        }
    }
}

extension Account {
    init(_ me: Components.Schemas.Me) {
        let role: Role =
            switch me.role {
            case .user: .user
            case .editor: .editor
            case .admin: .admin
            }
        self.init(id: me.id, name: me.name, email: me.email, role: role, createdAt: me.createdAt, pushIdentity: me.pushIdentity)
    }
}

extension String? {
    /// Apple sends empty name components for people who removed their name; the API wants them absent.
    fileprivate var nonEmpty: String? {
        self?.isEmpty == false ? self : nil
    }
}
