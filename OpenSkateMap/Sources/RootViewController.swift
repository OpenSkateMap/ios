import AccountKit
import FactoryKit
import PinLayout
import SignInKit
import UIKit

final class RootViewController: UIViewController {

    // MARK: Types

    private enum Destination {
        case signIn
        case app
    }

    // MARK: Overridden Properties

    override var childForStatusBarStyle: UIViewController? {
        content
    }

    // MARK: Properties

    @Injected(\.authSession) private var authSession

    private var destination: Destination?
    private var content: UIViewController?

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
    }

    override func updateProperties() {
        super.updateProperties()

        let destination: Destination =
            switch authSession.phase {
            case .signedIn: .app
            case .signedOut, .signingIn: .signIn
            }
        guard destination != self.destination else {
            return
        }
        let animated = self.destination != nil
        self.destination = destination
        let next: UIViewController =
            switch destination {
            case .signIn: SignInViewController()
            case .app: MainTabBarController()
            }
        show(next, animated: animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        content?.view.pin
            .all()
    }

    // MARK: Functions

    /// Whatever the old destination presented goes with it, so nothing from an ended session stays on screen.
    private func show(_ next: UIViewController, animated: Bool) {
        let previous = content
        if presentedViewController != nil {
            dismiss(animated: false)
        }
        previous?.willMove(toParent: nil)
        addChild(next)
        next.view.frame = view.bounds
        content = next
        setNeedsStatusBarAppearanceUpdate()
        let swap = {
            previous?.view.removeFromSuperview()
            self.view.addSubview(next.view)
        }
        if animated {
            UIView.transition(
                with: view,
                duration: 0.35,
                options: [.transitionCrossDissolve, .allowAnimatedContent],
                animations: swap,
            ) { _ in
                previous?.removeFromParent()
                next.didMove(toParent: self)
            }
        } else {
            swap()
            previous?.removeFromParent()
            next.didMove(toParent: self)
        }
    }
}
