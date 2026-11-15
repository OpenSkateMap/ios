public import AuthenticationServices
import UIKit

// MARK: - AppleSignInManager

public struct AppleSignInManager: Sendable {
    public var signIn: @Sendable () async throws -> AppleCredential
    /// `.revoked` or `.notFound`: the person took the app's access away, or deleted their Apple Account.
    public var credentialState: @Sendable (_ userID: String) async throws -> ASAuthorizationAppleIDProvider.CredentialState
    public var revocations: @Sendable () -> AsyncStream<Void>

    public init(signIn: @escaping @Sendable () async throws -> AppleCredential,
                credentialState: @escaping @Sendable (String) async throws -> ASAuthorizationAppleIDProvider.CredentialState,
                revocations: @escaping @Sendable () -> AsyncStream<Void>) {
        self.signIn = signIn
        self.credentialState = credentialState
        self.revocations = revocations
    }

    /// One whose credentials are never revoked, for previews and tests that only sign in.
    public init(signIn: @escaping @Sendable () async throws -> AppleCredential) {
        self.init(signIn: signIn, credentialState: { _ in .authorized }, revocations: { AsyncStream { $0.finish() } })
    }
}

// MARK: - AppleCredential

public struct AppleCredential: Equatable, Sendable {
    public var userID: String
    public var identityToken: String
    public var rawNonce: String
    public var authorizationCode: String?
    public var givenName: String?
    public var familyName: String?

    public init(userID: String,
                identityToken: String,
                rawNonce: String,
                authorizationCode: String? = nil,
                givenName: String? = nil,
                familyName: String? = nil) {
        self.userID = userID
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.authorizationCode = authorizationCode
        self.givenName = givenName
        self.familyName = familyName
    }
}

// MARK: - AppleSignInError

public enum AppleSignInError: Error, Equatable {
    case canceled
    case failed(code: Int)
}

extension AppleSignInManager {
    public static let live = AppleSignInManager(signIn: { @MainActor in
        let nonce = Nonce.random()
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Nonce.sha256(nonce)

        let authorization: ASAuthorization
        do {
            authorization = try await AppleAuthorizationFlow().perform(request)
        } catch let error as ASAuthorizationError where error.code == .canceled {
            throw AppleSignInError.canceled
        } catch let error as ASAuthorizationError {
            throw AppleSignInError.failed(code: error.code.rawValue)
        }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.failed(code: ASAuthorizationError.invalidResponse.rawValue)
        }
        return AppleCredential(
            userID: credential.user,
            identityToken: identityToken,
            rawNonce: nonce,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) },
            givenName: credential.fullName?.givenName,
            familyName: credential.fullName?.familyName,
        )
    }, credentialState: { userID in
        try await withCheckedThrowingContinuation { continuation in
            ASAuthorizationAppleIDProvider().getCredentialState(forUserID: userID) { state, error in
                // `.notFound` always comes with an error; the async form would throw it and hide the state.
                if let error, state != .notFound {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }, revocations: {
        AsyncStream { continuation in
            let revoked = ASAuthorizationAppleIDProvider.credentialRevokedNotification
            let watching = Task {
                for await _ in NotificationCenter.default.notifications(named: revoked) {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in watching.cancel() }
        }
    })

    public static let preview = AppleSignInManager {
        AppleCredential(userID: "preview-apple-user", identityToken: "preview-identity-token", rawNonce: Nonce.random())
    }
}

// MARK: - AppleAuthorizationFlow

@MainActor
private final class AppleAuthorizationFlow: NSObject {

    // MARK: Properties

    private var controller: ASAuthorizationController?
    private var continuation: CheckedContinuation<ASAuthorization, any Error>?

    // MARK: Functions

    func perform(_ request: ASAuthorizationRequest) async throws -> ASAuthorization {
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        self.controller = controller
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                controller.performRequests()
            }
        } onCancel: {
            Task { @MainActor in self.controller?.cancel() }
        }
    }

    private func finish(_ result: Result<ASAuthorization, any Error>) {
        continuation?.resume(with: result)
        continuation = nil
        controller = nil
    }
}

// MARK: ASAuthorizationControllerDelegate

extension AppleAuthorizationFlow: ASAuthorizationControllerDelegate {
    func authorizationController(controller _: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        finish(.success(authorization))
    }

    func authorizationController(controller _: ASAuthorizationController, didCompleteWithError error: any Error) {
        finish(.failure(error))
    }
}

// MARK: ASAuthorizationControllerPresentationContextProviding

extension AppleAuthorizationFlow: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for _: ASAuthorizationController) -> ASPresentationAnchor {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            preconditionFailure("Sign in with Apple starts from a visible screen, so a window scene exists")
        }
        return scene.keyWindow ?? scene.windows.first ?? UIWindow(windowScene: scene)
    }
}
