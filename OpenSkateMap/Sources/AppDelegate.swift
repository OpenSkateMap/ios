import AccountKit
import AnalyticsKit
import ComponentKit
import FactoryKit
import NotificationsKit
import Observation
import SQLiteKit
import TipJarKit
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: Properties

    private var identifying: Task<Void, Never>?

    // MARK: Static Functions

    private static func identify(_ authSession: AuthSession,
                                 to notifications: NotificationsManager,
                                 analytics: AnalyticsManager) async {
        var identified: Account?
        for await phase in Observations({ authSession.phase }) {
            guard case .signedIn(let account) = phase else {
                identified = nil
                continue
            }
            guard account != identified else {
                continue
            }
            identified = account
            analytics.identify(account.id)
            guard let identityHash = account.pushIdentity else {
                continue
            }
            notifications.identify(
                NotificationSubscriber(
                    id: account.id,
                    name: account.name,
                    role: account.role.rawValue,
                    joinedAt: account.createdAt,
                    identityHash: identityHash,
                )
            )
        }
    }

    // MARK: Functions

    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Before the scene makes its window.
        UIView.followLayoutDirection()
        AppDatabase.bridgeToSQLiteData(Container.shared.database())
        Container.shared.tipJarManager().configure()
        let analytics = Container.shared.analyticsManager()
        analytics.configure()
        let notifications = Container.shared.notificationsManager()
        notifications.configure()
        identifying = Task {
            await Self.identify(Container.shared.authSession(), to: notifications, analytics: analytics)
        }
        return true
    }

    func application(_: UIApplication,
                     configurationForConnecting connectingSceneSession: UISceneSession,
                     options _: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

}
