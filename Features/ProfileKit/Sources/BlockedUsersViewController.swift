import ComponentKit
import FactoryKit
import PeopleKit
import PinLayout
import SQLiteData
import UIKit

final class BlockedUsersViewController: UIViewController {

    // MARK: Properties

    @Injected(\.profileSession) private var profileSession
    @Fetch private var blocked: BlockedUsers
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var shown: BlockedUsers?
    private var loadFailed: String?
    private var unblocking = Set<String>()

    // MARK: Lifecycle

    init() {
        _blocked = Fetch(wrappedValue: BlockedUsers(), BlockedUsersRequest(account: Container.shared.profileSession().accountID))
        super.init(nibName: nil, bundle: nil)
        title = ProfileKitStrings.BlockedUsers.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.allowsSelection = false
        view.addSubview(collectionView)
        load()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override func updateProperties() {
        super.updateProperties()

        let blocked = blocked
        // Only on a change: requesting a content-unavailable update on every pass never settles.
        guard blocked != shown else {
            return
        }
        shown = blocked
        var snapshot = NSDiffableDataSourceSnapshot<Int, String>()
        snapshot.appendSections([0])
        snapshot.appendItems(blocked.users.map(\.id))
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: true)
        setNeedsUpdateContentUnavailableConfiguration()
    }

    // MARK: Overrides

    override func updateContentUnavailableConfiguration(using _: UIContentUnavailableConfigurationState) {
        if let shown, !shown.users.isEmpty {
            contentUnavailableConfiguration = nil
        } else if shown?.isLoaded == true {
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "hand.raised")
            empty.text = ProfileKitStrings.BlockedUsers.Empty.title
            empty.secondaryText = ProfileKitStrings.BlockedUsers.Empty.detail
            contentUnavailableConfiguration = empty
        } else if let loadFailed {
            var failed = UIContentUnavailableConfiguration.empty()
            failed.text = ProfileKitStrings.BlockedUsers.Failed.title
            failed.secondaryText = loadFailed
            var retry = UIButton.Configuration.gray()
            retry.title = ProfileKitStrings.Common.tryAgain
            failed.button = retry
            failed.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.load() }
            contentUnavailableConfiguration = failed
        } else {
            contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
        }
    }

    // MARK: Functions

    private func load() {
        loadFailed = nil
        setNeedsUpdateContentUnavailableConfiguration()
        Task { [weak self, profileSession] in
            do {
                try await profileSession.loadBlockedUsers()
            } catch {
                self?.loadFailed = PeopleAPIError.message(for: error)
                self?.setNeedsUpdateContentUnavailableConfiguration()
            }
        }
    }

    private func unblock(_ user: BlockedUser) {
        guard !unblocking.contains(user.id) else {
            return
        }
        setUnblocking(user.id, true)
        Task { [weak self, profileSession] in
            do {
                try await profileSession.setBlocked(user.id, false)
            } catch {
                ToastView.showFailure(ProfileKitStrings.BlockedUsers.unblockFailed, subtitle: PeopleAPIError.message(for: error))
            }
            self?.setUnblocking(user.id, false)
        }
    }

    private func setUnblocking(_ id: String, _ isUnblocking: Bool) {
        if isUnblocking {
            unblocking.insert(id)
        } else {
            unblocking.remove(id)
        }
        var snapshot = dataSource.snapshot()
        guard snapshot.indexOfItem(id) != nil else {
            return
        }
        snapshot.reconfigureItems([id])
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout.list(using: UICollectionLayoutListConfiguration(appearance: .insetGrouped))
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, String> {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, String> { [weak self] cell, _, id in
            guard let self, let user = blocked.users.first(where: { $0.id == id }) else {
                return
            }
            var content = UIListContentConfiguration.subtitleCell()
            content.text = user.name
            content.secondaryText = user.username.map { "@\($0)" }
            content.secondaryTextProperties.color = .secondaryLabel
            cell.contentConfiguration = content
            var configuration = UIButton.Configuration.gray()
            configuration.title = ProfileKitStrings.BlockedUsers.unblock
            configuration.cornerStyle = .capsule
            configuration.showsActivityIndicator = unblocking.contains(id)
            let button = UIButton(configuration: configuration)
            button.isEnabled = !unblocking.contains(id)
            button.accessibilityLabel = ProfileKitStrings.BlockedUsers.A11y.unblock(user.name)
            button.addAction(UIAction { [weak self] _ in self?.unblock(user) }, for: .primaryActionTriggered)
            cell.accessories = [.customView(configuration: .init(customView: button, placement: .trailing()))]
        }
        return UICollectionViewDiffableDataSource<Int, String>(collectionView: collectionView) { collectionView, indexPath, id in
            collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: id)
        }
    }
}
