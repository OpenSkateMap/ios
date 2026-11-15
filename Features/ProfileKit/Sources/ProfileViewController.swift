import AccountKit
import ComponentKit
import FactoryKit
public import MessageUI
import PeopleKit
import PinLayout
import SafariServices
import SPConfetti
import TipJarKit
public import UIKit

// MARK: - ProfileViewController

public final class ProfileViewController: UIViewController, UICollectionViewDelegate {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case profile
        case yours
        case preferences
        case app
        case account
    }

    nonisolated private enum Item: Hashable {
        case profile
        case collections
        case account
        case privacy
        case appearance
        case notifications
        case support
        case feedback
        case signOut
        case deleteAccount
    }

    // MARK: Properties

    private let model = ProfileModel()
    @Injected(\.tipJarManager) private var tipJar
    private var loadingTips: Task<Void, Never>?
    private var preparingFeedback: Task<Void, Never>?
    private var hasTipped = false
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private lazy var refreshControl = PullToRefreshControl { [weak self] in
        await self?.reload(reportsFailure: true).value
        return nil
    }

    private var displayedAccount: Account?
    private var displayedProfile: PublicProfile?
    private var displayedLoadFailed = false
    private var displayedDeleting = false
    private var actionTask: Task<Void, Never>?
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)

        title = ProfileKitStrings.Profile.title
        navigationItem.largeTitleDisplayMode = .inline
        let edit = UIBarButtonItem(image: UIImage(systemName: "pencil"), primaryAction: UIAction { [weak self] _ in
            self?.editProfile()
        })
        edit.accessibilityLabel = ProfileKitStrings.EditProfile.title
        edit.isEnabled = false
        navigationItem.rightBarButtonItem = edit
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        view.addSubview(collectionView)

        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.profile, .yours, .preferences, .app, .account])
        snapshot.appendItems([.profile], toSection: .profile)
        snapshot.appendItems([.collections, .privacy], toSection: .yours)
        snapshot.appendItems([.appearance, .notifications], toSection: .preferences)
        snapshot.appendItems([.support, .feedback], toSection: .app)
        snapshot.appendItems([.account, .signOut, .deleteAccount], toSection: .account)
        dataSource.apply(snapshot, animatingDifferences: false)
        // The row tiles are images drawn at the text size.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            var snapshot = self.dataSource.snapshot()
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
            self.dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        reload()
    }

    override public func updateProperties() {
        super.updateProperties()

        navigationItem.rightBarButtonItem?.isEnabled = model.profile != nil
        var snapshot = dataSource.snapshot()
        var changed = [Item]()
        if model.account != displayedAccount {
            displayedAccount = model.account
            changed.append(.account)
        }
        if model.isDeletingAccount != displayedDeleting {
            displayedDeleting = model.isDeletingAccount
            changed.append(.deleteAccount)
        }
        if model.profile != displayedProfile {
            displayedProfile = model.profile
            changed.append(.profile)
        }
        let showsFailure = model.loadFailed && model.profile == nil
        if showsFailure != displayedLoadFailed {
            displayedLoadFailed = showsFailure
            snapshot.reloadSections([.profile])
        }
        guard !changed.isEmpty || snapshot.reloadedSectionIdentifiers.contains(.profile) else {
            return
        }
        snapshot.reconfigureItems(changed.filter { !snapshot.reloadedSectionIdentifiers.contains(section(of: $0)) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Functions

    public func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .profile, nil: false
        case .account, .collections, .privacy, .appearance, .notifications, .support, .feedback, .signOut, .deleteAccount:
            !model.isDeletingAccount
        }
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {
        refreshControl.fingerLifted()
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .collections:
            openCollections()

        case .privacy:
            navigationController?.pushViewController(PrivacyViewController(), animated: true)

        case .appearance:
            navigationController?.pushViewController(AppearanceViewController(), animated: true)

        case .notifications:
            navigationController?.pushViewController(NotificationSettingsViewController(), animated: true)

        case .support:
            openSupport()

        case .feedback:
            openFeedback()

        case .signOut:
            run { await $0.signOut() }

        case .deleteAccount:
            confirmAccountDeletion()

        case .account:
            openAccountActions(at: indexPath)

        case .profile, nil:
            break
        }
    }

    /// A pull while a load runs waits for that one.
    @discardableResult
    private func reload(reportsFailure: Bool = false) -> Task<Void, Never> {
        if let loading {
            return loading
        }
        let task = Task { [weak self, model] in
            do {
                try await model.load()
            } catch {
                if reportsFailure {
                    ToastView.showFailure(ProfileKitStrings.Profile.refreshFailed, subtitle: PeopleAPIError.message(for: error))
                }
            }
            self?.loading = nil
        }
        loading = task
        return task
    }

    private func editProfile() {
        guard let profile = model.profile else {
            return
        }
        let editor = UINavigationController(rootViewController: EditProfileViewController(profile: profile))
        present(editor, animated: true)
    }

    private func open(_ url: URL) {
        view.window?.windowScene?.open(url, options: nil)
    }

    private func confirmAccountDeletion() {
        let alert = UIAlertController(
            title: ProfileKitStrings.Profile.DeleteAccount.Confirm.title,
            message: ProfileKitStrings.Profile.DeleteAccount.Confirm.message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(
            title: ProfileKitStrings.Profile.DeleteAccount.title,
            style: .destructive,
        ) { [weak self] _ in
            self?.run { model in
                do {
                    try await model.deleteAccount()
                } catch AuthAPIError.unauthorized {
                    // The session already ended; sign-in says so.
                } catch {
                    ToastView.showFailure(
                        ProfileKitStrings.Profile.DeleteAccount.Failed.title,
                        subtitle: ProfileKitStrings.Profile.DeleteAccount.Failed.message,
                    )
                }
            }
        })
        alert.addAction(UIAlertAction(title: ProfileKitStrings.Common.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func run(_ action: @escaping (ProfileModel) async -> Void) {
        guard actionTask == nil else {
            return
        }
        actionTask = Task { [model] in
            await action(model)
            actionTask = nil
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.footerMode = .supplementary
        let layoutConfiguration = UICollectionViewCompositionalLayoutConfiguration()
        layoutConfiguration.boundarySupplementaryItems = [NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(64)),
            elementKind: LegalFooterView.elementKind,
            alignment: .bottom,
        )]
        return UICollectionViewCompositionalLayout(
            sectionProvider: { [weak self] index, environment in
                let list = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
                guard self?.dataSource.sectionIdentifier(for: index) == .profile else {
                    return list
                }
                // Not a list section: inset-grouped lists clip a cell to the card's corners, which cut into the stat tiles.
                let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(240))
                let profile = NSCollectionLayoutSection(group: .vertical(
                    layoutSize: size,
                    subitems: [NSCollectionLayoutItem(layoutSize: size)],
                ))
                profile.contentInsets = list.contentInsets
                profile.contentInsetsReference = list.contentInsetsReference
                profile.boundarySupplementaryItems = list.boundarySupplementaryItems
                return profile
            },
            configuration: layoutConfiguration,
        )
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            self?.configure(cell, for: item)
        }
        let profileCell = UICollectionView.CellRegistration<ProfileHeaderCell, Item> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            if let profile = model.profile {
                cell.show(profile)
            } else {
                cell.showPlaceholder(for: model.account)
            }
            cell.onOpenURL = { [weak self] in self?.open($0) }
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footer, _, indexPath in
            var content = UIListContentConfiguration.footer()
            content.text = self?.footerText(for: self?.dataSource.sectionIdentifier(for: indexPath.section))
            footer.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Item,
        >(collectionView: collectionView) { collectionView, indexPath, item in
            item == .profile
                ? collectionView.dequeueConfiguredReusableCell(using: profileCell, for: indexPath, item: item)
                : collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: item)
        }
        let legal = UICollectionView.SupplementaryRegistration<LegalFooterView>(
            elementKind: LegalFooterView.elementKind
        ) { [weak self] footer, _, _ in
            footer.onOpenURL = { self?.present(SFSafariViewController(url: $0), animated: true) }
        }
        dataSource.supplementaryViewProvider = { collectionView, kind, indexPath in
            kind == LegalFooterView.elementKind
                ? collectionView.dequeueConfiguredReusableSupplementary(using: legal, for: indexPath)
                : collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
        }
        return dataSource
    }

    private func configure(_ cell: UICollectionViewListCell, for item: Item) {
        var content: UIListContentConfiguration
        cell.accessories = []
        switch item {
        case .profile:
            return

        case .account:
            content = .subtitleCell()
            content.image = .symbolTile(systemName: "apple.logo", color: .black, traitCollection: cell.traitCollection)
            content.text = ProfileKitStrings.Profile.Account.title
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.secondaryText = model.account?.email
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)

        case .collections:
            content = .cell()
            content.text = ProfileKitStrings.Profile.Collections.title
            content.image = .symbolTile(
                systemName: "rectangle.stack.fill",
                color: .systemOrange,
                traitCollection: cell.traitCollection,
            )
            cell.accessories = [.disclosureIndicator()]

        case .privacy:
            content = .cell()
            content.text = ProfileKitStrings.Privacy.title
            content.image = .symbolTile(systemName: "hand.raised.fill", color: .systemBlue, traitCollection: cell.traitCollection)
            cell.accessories = [.disclosureIndicator()]

        case .appearance:
            content = .cell()
            content.text = ProfileKitStrings.Appearance.title
            content.image = .symbolTile(
                systemName: "circle.lefthalf.filled",
                color: .systemTeal,
                traitCollection: cell.traitCollection,
            )
            cell.accessories = [.disclosureIndicator()]

        case .notifications:
            content = .cell()
            content.text = ProfileKitStrings.Notifications.title
            content.image = .symbolTile(systemName: "bell.badge.fill", color: .systemRed, traitCollection: cell.traitCollection)
            cell.accessories = [.disclosureIndicator()]

        case .support:
            content = .cell()
            content.text = ProfileKitStrings.Support.title
            content.image = .symbolTile(systemName: "heart.fill", color: .systemPink, traitCollection: cell.traitCollection)
            cell.accessories = loadingTips == nil ? [.disclosureIndicator()] : [.spinner()]

        case .feedback:
            content = .cell()
            content.text = ProfileKitStrings.Profile.Feedback.title
            content.image = .symbolTile(systemName: "envelope.fill", color: .systemIndigo, traitCollection: cell.traitCollection)
            if preparingFeedback != nil {
                cell.accessories = [.spinner()]
            }

        case .signOut:
            content = .cell()
            content.text = ProfileKitStrings.Profile.SignOut.title
            content.image = .symbolTile(
                systemName: "rectangle.portrait.and.arrow.right",
                color: .systemGray,
                traitCollection: cell.traitCollection,
            )

        case .deleteAccount:
            content = .cell()
            content.text = model.isDeletingAccount
                ? ProfileKitStrings.Profile.DeleteAccount.deleting
                : ProfileKitStrings.Profile.DeleteAccount.title
            content.image = .symbolTile(systemName: "trash.fill", color: .systemRed, traitCollection: cell.traitCollection)
            content.textProperties.color = model.isDeletingAccount ? .secondaryLabel : .systemRed
            if model.isDeletingAccount {
                cell.accessories = [.spinner()]
            }
        }
        cell.contentConfiguration = content
        cell.accessibilityTraits = .button
        cell.accessibilityUserInputLabels = content.text.map { [$0] }
    }

    private func openAccountActions(at indexPath: IndexPath) {
        guard let account = model.account, let row = collectionView.cellForItem(at: indexPath) else {
            return
        }
        let actions: [ActionPopoverController.Action] = [
            .init(title: ProfileKitStrings.Profile.Account.copyEmail) { UIPasteboard.general.string = account.email },
            .init(title: ProfileKitStrings.Profile.Account.copyUserID) { UIPasteboard.general.string = account.id },
        ]
        present(ActionPopoverController(actions: actions, from: row), animated: true)
    }

    private func openSupport() {
        guard loadingTips == nil else {
            return
        }
        loadingTips = Task { [weak self, tipJar] in
            do {
                let tips = try await tipJar.tips()
                guard !tips.isEmpty else {
                    throw TipJarError.unavailable
                }
                self?.present(SupportSheet.make(tips: tips) { self?.thankForTip() }, animated: true)
            } catch {
                ToastView.showFailure(
                    ProfileKitStrings.Profile.Support.LoadFailed.title,
                    subtitle: ProfileKitStrings.Profile.Support.LoadFailed.message,
                )
            }
            self?.loadingTips = nil
            self?.reconfigure(.support)
        }
        reconfigure(.support)
    }

    private func openFeedback() {
        guard preparingFeedback == nil else {
            return
        }
        preparingFeedback = Task { [weak self] in
            defer {
                self?.preparingFeedback = nil
                self?.reconfigure(.feedback)
            }
            guard let self else {
                return
            }
            if let mail = await FeedbackMail.composer(account: model.account) {
                mail.mailComposeDelegate = self
                present(mail, animated: true)
            } else if let url = FeedbackMail.mailtoURL(account: model.account), await UIApplication.shared.open(url) {
                return
            } else {
                let alert = UIAlertController(
                    title: ProfileKitStrings.Profile.Feedback.NoMail.title,
                    message: ProfileKitStrings.Profile.Feedback.NoMail.message(FeedbackMail.address),
                    preferredStyle: .alert,
                )
                alert.addAction(UIAlertAction(title: ProfileKitStrings.Profile.Feedback.NoMail.copy, style: .default) { _ in
                    UIPasteboard.general.string = FeedbackMail.address
                })
                alert.addAction(UIAlertAction(title: ProfileKitStrings.Common.ok, style: .cancel))
                present(alert, animated: true)
            }
        }
        reconfigure(.feedback)
    }

    private func thankForTip() {
        if !UIAccessibility.isReduceMotionEnabled {
            SPConfettiConfiguration.particlesConfig.birthRate = 80
            SPConfettiConfiguration.particlesConfig.velocity = 220
            SPConfettiConfiguration.particlesConfig.velocityRange = 80
            SPConfetti.startAnimating(
                .fullWidthToDown,
                particles: [.arc, .triangle, .heart, .star, .circle, .polygon],
                duration: 2.5,
            )
        }
        hasTipped = true
        var snapshot = dataSource.snapshot()
        snapshot.reloadSections([.app])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func reconfigure(_ item: Item) {
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems([item])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func openCollections() {
        guard let list = Container.shared.collectionsListScreen() else {
            return
        }
        navigationController?.pushViewController(list, animated: true)
    }

    private func footerText(for section: Section?) -> String? {
        switch section {
        case .profile: displayedLoadFailed ? ProfileKitStrings.Profile.loadFailed : nil
        case .app: hasTipped ? ProfileKitStrings.Profile.Support.thanks : nil
        case .account: ProfileKitStrings.Profile.Account.footer
        case .yours, .preferences, nil: nil
        }
    }

    private func section(of item: Item) -> Section {
        switch item {
        case .profile: .profile
        case .collections, .privacy: .yours
        case .appearance, .notifications: .preferences
        case .support, .feedback: .app
        case .account, .signOut, .deleteAccount: .account
        }
    }
}

// MARK: MFMailComposeViewControllerDelegate

extension ProfileViewController: MFMailComposeViewControllerDelegate {
    public func mailComposeController(_ controller: MFMailComposeViewController,
                                      didFinishWith result: MFMailComposeResult,
                                      error _: any Error?) {
        controller.dismiss(animated: true)
        if result == .failed {
            ToastView.showFailure(ProfileKitStrings.Profile.Feedback.failed)
        }
    }
}
