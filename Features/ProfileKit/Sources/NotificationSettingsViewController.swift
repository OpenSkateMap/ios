import ComponentKit
import IdentifiedCollections
import NotificationsKit
import PinLayout
import UIKit

final class NotificationSettingsViewController: UIViewController, UICollectionViewDelegate {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case permission
        case topics
    }

    nonisolated private enum Item: Hashable {
        case turnOn
        case openSettings
        case topic(NotificationTopic.ID)
    }

    // MARK: Properties

    private let model = NotificationSettingsModel()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var shown: (permission: NotificationPermission?, topics: IdentifiedArrayOf<NotificationTopic>, loadFailed: Bool)?
    private var watchingForeground: Task<Void, Never>?

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        title = ProfileKitStrings.Notifications.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        watchingForeground?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        watchForeground()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task { [model] in await model.load() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override func updateProperties() {
        super.updateProperties()

        if model.saveFailed {
            showSaveFailure()
        }
        let state = (permission: model.permission, topics: model.topics, loadFailed: model.loadFailed)
        if let shown, shown == state {
            return
        }
        let previous = shown
        shown = state
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        switch state.permission {
        case .notAsked:
            snapshot.appendSections([.permission])
            snapshot.appendItems([.turnOn])

        case .denied:
            snapshot.appendSections([.permission])
            snapshot.appendItems([.openSettings])

        case .allowed, nil:
            break
        }
        snapshot.appendSections([.topics])
        snapshot.appendItems(state.topics.map { .topic($0.id) })
        snapshot.reconfigureItems(state.topics.map { .topic($0.id) })
        if previous?.loadFailed != state.loadFailed {
            snapshot.reloadSections([.topics])
        }
        if previous?.permission != state.permission, snapshot.sectionIdentifiers.contains(.permission) {
            snapshot.reloadSections([.permission])
        }
        dataSource.apply(snapshot, animatingDifferences: previous != nil)
    }

    // MARK: Functions

    func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .turnOn, .openSettings: true
        case .topic, nil: false
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .turnOn:
            Task { [model] in await model.turnOn() }

        case .openSettings:
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }

        case .topic, nil:
            break
        }
    }

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func watchForeground() {
        watchingForeground = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                await self?.model.refreshPermission()
            }
        }
    }

    private func showSaveFailure() {
        model.dismissSaveFailure()
        ToastView.showFailure(
            ProfileKitStrings.Notifications.SaveFailed.title,
            subtitle: ProfileKitStrings.Notifications.SaveFailed.message,
        )
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.footerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let action = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var content = UIListContentConfiguration.cell()
            content.text = item == .turnOn
                ? ProfileKitStrings.Notifications.turnOn
                : ProfileKitStrings.Notifications.openSettings
            content.textProperties.color = .tintColor
            cell.contentConfiguration = content
            cell.accessibilityTraits = .button
        }
        let topic = UICollectionView.CellRegistration<SwitchCell, NotificationTopic.ID> { [weak self] cell, _, id in
            guard let self, let topic = model.topics[id: id] else {
                return
            }
            var content = UIListContentConfiguration.subtitleCell()
            content.text = topic.title
            content.textProperties.font = .preferredFont(forTextStyle: .body)
            content.secondaryText = topic.detail
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            cell.show(
                content,
                isOn: topic.isOn,
                isEnabled: topic.isAvailable && model.permission == .allowed,
            )
            cell.onChange = { [weak self] isOn in
                guard let model = self?.model else {
                    return
                }
                Task { await model.set(id, isOn: isOn) }
            }
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
            if case .topic(let id) = item {
                return collectionView.dequeueConfiguredReusableCell(using: topic, for: indexPath, item: id)
            }
            return collectionView.dequeueConfiguredReusableCell(using: action, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
        }
        return dataSource
    }

    private func footerText(for section: Section?) -> String? {
        switch section {
        case .permission:
            model.permission == .denied
                ? ProfileKitStrings.Notifications.Off.footer
                : ProfileKitStrings.Notifications.TurnOn.footer

        case .topics:
            model.loadFailed ? ProfileKitStrings.Notifications.loadFailed : nil

        case nil:
            nil
        }
    }
}
