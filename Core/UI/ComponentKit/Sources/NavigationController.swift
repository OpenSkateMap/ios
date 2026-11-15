public import UIKit

public final class NavigationController: UINavigationController {

    // MARK: Overridden Properties

    override public var childForStatusBarStyle: UIViewController? {
        topViewController
    }

    // MARK: Lifecycle

    override public func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (controller: Self, _) in
            controller.viewControllers.forEach(controller.placeTitle(of:))
        }
        viewControllers.forEach(placeTitle(of:))
    }

    // MARK: Overrides

    override public func pushViewController(_ viewController: UIViewController, animated: Bool) {
        placeTitle(of: viewController)
        super.pushViewController(viewController, animated: animated)
    }

    override public func setViewControllers(_ viewControllers: [UIViewController], animated: Bool) {
        viewControllers.forEach(placeTitle(of:))
        super.setViewControllers(viewControllers, animated: animated)
    }

    // MARK: Functions

    /// Under a tab bar at the top a centered title gets a row of its own below the bar, as on iPad; the browser style
    /// puts it beside the back button, in the tab bar's row.
    private func placeTitle(of viewController: UIViewController) {
        viewController.navigationItem.style = tabBarController?.isTabBarAtTop == true ? .browser : .navigator
    }
}
