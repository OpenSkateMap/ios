import AccountKit
import ComponentKit
import FactoryKit
import SnapshotTesting
import Testing
import UIKit
@testable import SignInKit

// MARK: - SignInViewControllerTests

@MainActor
@Suite(.serialized, .timeLimit(.minutes(1)))
struct SignInViewControllerTests {

    // MARK: Static Properties

    private static let iPhone = image(on: .iPhone13Pro)

    // MARK: Lifecycle

    init() {
        // As the app sets it at launch.
        UIView.followLayoutDirection()
    }

    // MARK: Static Functions

    private static func image(on config: ViewImageConfig,
                              contentSize: UIContentSizeCategory = .large) -> Snapshotting<UIViewController, UIImage> {
        .image(
            on: config,
            precision: 0.995,
            perceptualPrecision: 0.98,
            traits: UITraitCollection {
                $0.displayScale = 1
                $0.preferredContentSizeCategory = contentSize
            },
        )
    }

    // MARK: Functions

    @Test
    func `signed out`() {
        withAuthSession(.signedOut) {
            assertSnapshot(of: SignInViewController(footage: nil), as: Self.iPhone)
            assertSnapshot(of: SignInViewController(footage: nil), as: Self.image(on: .iPhoneSe), named: "small")
            assertSnapshot(
                of: SignInViewController(footage: nil),
                as: Self.image(on: .iPhone13Pro, contentSize: .accessibilityExtraLarge),
                named: "accessibility-text",
            )
        }
    }

    @Test
    func `with footage, the credit and the pause button show over the poster`() {
        let poster = UIGraphicsImageRenderer(size: CGSize(width: 9, height: 16)).image { context in
            UIColor(white: 0.45, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 9, height: 16))
        }
        let footage = SignInFootage(video: URL(filePath: "/dev/null"), poster: poster)

        withAuthSession(.signedOut) {
            assertSnapshot(of: SignInViewController(footage: footage), as: Self.iPhone)
        }
    }

    @Test
    func `signing in shows progress on the button`() async {
        let (calls, call) = AsyncStream<Void>.makeStream()
        let session = makeSession(apple: AppleSignInManager {
            call.yield()
            for await _ in AsyncStream<Never>.makeStream().stream { }
            throw AppleSignInError.canceled
        })
        let signingIn = Task { await session.signInWithApple() }
        defer { signingIn.cancel() }
        for await _ in calls {
            break
        }

        withAuthSession(session) {
            assertSnapshot(of: SignInViewController(footage: nil), as: Self.iPhone)
        }
    }

    @Test
    func `a failed sign-in says why above the button`() async {
        let session = makeSession(signInWithApple: { _ in throw AuthAPIError.offline })
        await session.signInWithApple()

        withAuthSession(session) {
            assertSnapshot(of: SignInViewController(footage: nil), as: Self.iPhone)
        }
    }

    private func withAuthSession(_ session: AuthSession, _ body: () -> Void) {
        Container.shared.authSession.register { session }
        defer { Container.shared.authSession.reset() }
        body()
    }

    private func makeSession(apple: AppleSignInManager = AppleSignInManager { AppleCredential(
        userID: "apple-user",
        identityToken: "token",
        rawNonce: "nonce",
    ) },
    signInWithApple: @escaping @Sendable (AppleCredential) async throws -> SignedInAccount = { _ in
        throw AuthAPIError.unavailable
    }) -> AuthSession {
        AuthSession(
            apple: apple,
            api: AuthAPIManager(
                signInWithApple: signInWithApple,
                me: { _ in throw AuthAPIError.unavailable },
                signOut: { _ in },
                deleteAccount: { _ in },
            ),
            keychain: .inMemory(),
            endAccountScope: { },
        )
    }
}

extension AuthSession {
    fileprivate static var signedOut: AuthSession {
        AuthSession(apple: .preview, api: .preview, keychain: .inMemory(), endAccountScope: { })
    }
}
