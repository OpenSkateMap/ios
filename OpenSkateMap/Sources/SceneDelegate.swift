import AccountKit
import AppLinkKit
import CollectionsKit
import ContributionsKit
import FactoryKit
import ImageKit
import LibraryMatchKit
import OnboardingKit
import PeopleKit
import ProfileKit
import SpotsKit
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: Properties

    var window: UIWindow?

    @Injected(\.authSession) private var authSession
    @Injected(\.appLinks) private var appLinks

    // MARK: Functions

    func scene(_ scene: UIScene, willConnectTo _: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else {
            return
        }
        for activity in connectionOptions.userActivities {
            open(activity)
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(LaunchArgument.resetOnboarding) {
            Container.shared.onboardingStore().setWelcomeSeen(false)
        }
        #endif
        ColorScheme.current.apply(to: windowScene)
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = RootViewController()
        window.makeKeyAndVisible()
        self.window = window
        sweepClips()
    }

    func scene(_: UIScene, continue userActivity: NSUserActivity) {
        open(userActivity)
    }

    func sceneWillEnterForeground(_: UIScene) {
        Task {
            guard case .signedIn(let account) = authSession.phase else {
                return
            }
            // Alongside: the syncs don't need the refreshed account, and if it ends the session their answers go with it.
            async let refreshed: Void = authSession.refreshAccount()
            async let contributions: Void = Container.shared.contributionsSession().refresh()
            async let collections: Void = Container.shared.collectionsSession().syncNow(joining: true)
            // Warms Profile's cache for offline; the tab reports its own failures.
            async let profile = try? Container.shared.profileSession().load(account.id)
            await Container.shared.spotsSession().syncNow(joining: true)
            // After the spots, so new ones are matched too; never asks for access.
            async let libraryMatches: Void = Container.shared.libraryMatchSession().refresh()
            await refreshed
            await contributions
            await collections
            _ = await profile
            await libraryMatches
        }
    }

    func sceneDidEnterBackground(_: UIScene) {
        sweepClips()
    }

    private func sweepClips() {
        let clips = Container.shared.clipCache()
        Task { @concurrent in
            await clips.sweep()
        }
    }

    private func open(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL,
              let link = AppLink(url: url) else {
            return
        }
        appLinks.open(link)
    }
}
