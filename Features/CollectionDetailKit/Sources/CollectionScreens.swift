import AppLinkKit
import CollectionsKit
import ComponentKit
import FactoryKit
public import UIKit

public enum CollectionScreens {
    public static func list() -> UIViewController {
        CollectionsListViewController(model: CollectionsListModel(source: .mine))
    }

    public static func publicCollections(of userID: String) -> UIViewController {
        CollectionsListViewController(model: CollectionsListModel(source: .user(id: userID)))
    }

    public static func collection(id: String) -> UIViewController {
        presented(CollectionViewController(id: id))
    }

    public static func listSheet() -> UIViewController {
        navigation(list())
    }

    public static func picker(spotID: String) -> UIViewController {
        CollectionPickerViewController.sheet(spotID: spotID)
    }

    public static func newCollection() -> UIViewController {
        NewCollectionAlert.make { name in
            Task {
                do {
                    let id = try await Container.shared.collectionsSession().create(CollectionDraft(name: name))
                    Container.shared.appLinkOpener().open(.collection(id: id))
                } catch {
                    CollectionFailure.show(CollectionDetailKitStrings.NewCollection.failed, error)
                }
            }
        }
    }

    private static func navigation(_ screen: UIViewController) -> UIViewController {
        let navigation = NavigationController(rootViewController: screen)
        navigation.navigationBar.prefersLargeTitles = true
        return navigation
    }

    private static func presented(_ screen: UIViewController) -> UIViewController {
        let navigation = navigation(screen)
        screen.navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .close,
            primaryAction: UIAction { [weak navigation] _ in
                navigation?.dismiss(animated: true)
            },
        )
        return navigation
    }

}
