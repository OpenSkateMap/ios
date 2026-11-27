import AppLinkKit
import CollectionDetailKit
import CollectionsKit
import ComponentKit
import ContributeKit
import FactoryKit
import NotificationsKit
import Observation
import OnboardingKit
import os
import ProfileKit
import SpotDetailKit
import SpotsMapKit
import UIKit

final class MainTabBarController: UITabBarController {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "links")

    // MARK: Overridden Properties

    override var childForStatusBarStyle: UIViewController? {
        selectedViewController
    }

    // MARK: Properties

    @Injected(\.onboardingStore) private var onboardingStore
    @Injected(\.appLinks) private var appLinks
    @Injected(\.notificationsManager) private var notifications

    private weak var map: SpotsMapViewController?
    private var mapTab: UITab?
    private var hasAppeared = false
    private var watchingLinks: Task<Void, Never>?
    private var waitingForEditor: Task<Void, Never>?

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        tabs = makeTabs()
        Container.shared.contributeTabOpener.register { [weak self] in
            { self?.showContribute() }
        }
        Container.shared.spotEditOpener.register { [weak self] in
            { id in self?.openSpotEdit(id) }
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        watchingLinks?.cancel()
        waitingForEditor?.cancel()
    }

    /// Links are observed here, not in `updateProperties()`, which stops while a full-screen cover is up.
    override func viewDidLoad() {
        super.viewDidLoad()

        registerForTraitChanges([UITraitVerticalSizeClass.self, UITraitHorizontalSizeClass.self]) { (controller: Self, _) in
            controller.updateTabBarPlacement()
        }
        observeLinks()
    }

    override func viewIsAppearing(_ animated: Bool) {
        super.viewIsAppearing(animated)

        updateTabBarPlacement()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        defer { hasAppeared = true }
        if !hasAppeared {
            notifications.onOpen { [weak self] destination in
                self?.open(destination)
            }
        }
        if appLinks.pending != nil {
            openPendingLink()
        } else if !hasAppeared {
            if onboardingStore.isWelcomeSeen() {
                askForNotifications()
            } else {
                OnboardingViewController.presentWelcomeIfNeeded(over: topPresented, store: onboardingStore) { [weak self] in
                    self?.askForNotifications()
                }
            }
        }
    }

    // MARK: Overrides

    /// Registered before `super` so it runs ahead of the children's alongside layout, which then sees the new inset.
    override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        coordinator.animate { [weak self] _ in
            self?.tabBarPlacementDidSettle()
        }
        super.viewWillTransition(to: size, with: coordinator)
    }

    // MARK: Static Functions

    private static func navigationController(root: UIViewController) -> UINavigationController {
        let navigationController = NavigationController(rootViewController: root)
        navigationController.navigationBar.prefersLargeTitles = true
        return navigationController
    }

    private static func holdsUnsavedChanges(_ controller: UIViewController) -> Bool {
        if controller.isModalInPresentation {
            return true
        }
        guard let presentation = controller.presentationController else {
            return false
        }
        return presentation.delegate?.presentationControllerShouldDismiss?(presentation) == false
    }

    // MARK: Functions

    private func makeTabs() -> [UITab] {
        let mapTab = UITab(
            title: OpenSkateMapStrings.Tab.discover,
            image: OpenSkateMapAsset.discover.image,
            identifier: "discover",
        ) { [weak self] _ in
            let map = SpotsMapViewController(
                spotSheet: SpotSheet(lowestDetentHeight: SpotSheetViewController.smallDetentHeight) { selection in
                    SpotSheetViewController(selection: selection)
                }
            )
            self?.map = map
            return map
        }
        self.mapTab = mapTab
        return [
            mapTab,
            UITab(
                title: OpenSkateMapStrings.Tab.contribute,
                image: UIImage(systemName: "plus.square.fill"),
                identifier: "contribute",
            ) { _ in
                Self.navigationController(root: ContributeViewController())
            },
            UITab(
                title: OpenSkateMapStrings.Tab.profile,
                image: UIImage(systemName: "person.crop.circle.fill"),
                identifier: "profile",
            ) { _ in
                Self.navigationController(root: ProfileViewController())
            },
        ]
    }

    private func observeLinks() {
        watchingLinks = Task { [weak self, appLinks] in
            for await link in Observations({ appLinks.pending }) where link != nil {
                guard let self else {
                    return
                }
                if hasAppeared {
                    openPendingLink()
                }
            }
        }
    }

    private func openPendingLink() {
        guard let link = appLinks.take() else {
            return
        }
        closePresented { [weak self] in
            self?.open(link)
        }
    }

    /// Over unsaved changes, `next` waits until the editor closes; a newer link or tap replaces it.
    private func closePresented(then next: @escaping () -> Void) {
        let base = map?.topSheet ?? self
        var presented = base.presentedViewController
        while let controller = presented {
            if Self.holdsUnsavedChanges(controller) {
                wait(for: controller, then: next)
                return
            }
            presented = controller.presentedViewController
        }
        waitingForEditor?.cancel()
        waitingForEditor = nil
        guard base.presentedViewController != nil else {
            return next()
        }
        base.dismiss(animated: true, completion: next)
    }

    /// UIKit says nothing when a sheet closes, so the editor is looked at twice a second until it's gone.
    private func wait(for editor: UIViewController, then next: @escaping () -> Void) {
        Self.logger.notice("A link or notification arrived over unsaved changes; it opens once the editor closes")
        waitingForEditor?.cancel()
        waitingForEditor = Task { [weak self, weak editor] in
            while editor?.view.window != nil {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else {
                    return
                }
            }
            self?.waitingForEditor = nil
            self?.closePresented(then: next)
        }
    }

    private func showContribute(then next: (() -> Void)? = nil) {
        let contribute = tab(forIdentifier: "contribute")
        guard let map, map.topSheet != nil else {
            selectedTab = contribute
            next?()
            return
        }
        map.closeSpot { [weak self] in
            self?.selectedTab = contribute
            next?()
        }
    }

    private func open(_ destination: NotificationDestination) {
        switch destination {
        case .link(let url):
            guard let link = AppLink(url: url) else {
                Self.logger.notice("A notification's link isn't one of the app's; it isn't opened")
                return
            }
            appLinks.open(link)

        case .contribute:
            closePresented { [weak self] in
                self?.showContribute()
            }

        case .reviewQueue:
            closePresented { [weak self] in
                self?.showContribute { [weak self] in
                    let navigation = self?.selectedViewController as? UINavigationController
                    (navigation?.viewControllers.first as? ContributeViewController)?.showReviewQueue()
                }
            }
        }
    }

    private func askForNotifications() {
        Task { [notifications] in
            guard await notifications.permission() == .notAsked else {
                return
            }
            _ = await notifications.requestPermission()
        }
    }

    private func open(_ link: AppLink) {
        switch link {
        case .spot(let id):
            selectedTab = mapTab
            map?.openSpot(id: id)

        case .collection(let id):
            topPresented.present(CollectionScreens.collection(id: id), animated: true)

        case .collectionMap(let id):
            showCollectionOnMap(id)
        }
    }

    private func openSpotEdit(_ id: String) {
        closePresented { [weak self] in
            guard let self else {
                return
            }
            selectedTab = mapTab
            map?.openSpot(id: id, suggestingEdit: true)
        }
    }

    /// One the account can't open shows its page instead (to ask to join, or the invitation).
    private func showCollectionOnMap(_ id: String) {
        Task { [weak self] in
            guard let focus = await Container.shared.collectionsSession().focus(of: id) else {
                self?.topPresented.present(CollectionScreens.collection(id: id), animated: true)
                return
            }
            guard let self else {
                return
            }
            selectedTab = mapTab
            map?.showCollection(focus)
        }
    }
}
