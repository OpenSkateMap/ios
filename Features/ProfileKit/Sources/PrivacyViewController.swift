import AnalyticsKit
import AppLinkKit
import ComponentKit
import FactoryKit
import PinLayout
import SafariServices
import UIKit

// MARK: - PrivacyViewController

final class PrivacyViewController: UIViewController, UICollectionViewDelegate {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case blocking
        case analytics
        case policy
    }

    nonisolated private enum Item: Hashable {
        case blockedUsers
        case analytics
        case policy
    }

    // MARK: Properties

    @Injected(\.analyticsManager) private var analytics
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()

    // MARK: Lifecycle

    init() {
        super.init(nibName: nil, bundle: nil)

        title = ProfileKitStrings.Privacy.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        applySnapshot()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    // MARK: Functions

    func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        dataSource.itemIdentifier(for: indexPath) != .analytics
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .blockedUsers:
            navigationController?.pushViewController(BlockedUsersViewController(), animated: true)

        case .policy:
            present(SFSafariViewController(url: LegalPage.privacy.url), animated: true)

        case .analytics, nil:
            break
        }
    }

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func applySnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.blocking, .analytics, .policy])
        snapshot.appendItems([.blockedUsers], toSection: .blocking)
        snapshot.appendItems([.analytics], toSection: .analytics)
        snapshot.appendItems([.policy], toSection: .policy)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func makeLayout() -> UICollectionViewLayout {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.footerMode = .supplementary
        return UICollectionViewCompositionalLayout.list(using: configuration)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let row = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, item in
            var content = UIListContentConfiguration.cell()
            switch item {
            case .blockedUsers:
                content.text = ProfileKitStrings.BlockedUsers.title
                content.image = .symbolTile(
                    systemName: "person.fill.xmark",
                    color: .systemGray,
                    traitCollection: cell.traitCollection,
                )
                cell.accessories = [.disclosureIndicator()]

            case .policy:
                content.text = LegalPage.privacy.title
                content.image = .symbolTile(
                    systemName: "text.document.fill",
                    color: .systemBlue,
                    traitCollection: cell.traitCollection,
                )
                let arrow = UIImageView(image: UIImage(systemName: "arrow.up.forward"))
                arrow.tintColor = .tertiaryLabel
                arrow.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
                    .applying(UIImage.SymbolConfiguration(weight: .semibold))
                cell.accessories = [.customView(configuration: .init(customView: arrow, placement: .trailing()))]

            case .analytics:
                break
            }
            cell.contentConfiguration = content
            cell.accessibilityTraits = .button
        }
        let analyticsRow = UICollectionView.CellRegistration<SwitchCell, Item> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            var content = UIListContentConfiguration.cell()
            content.text = ProfileKitStrings.Profile.Analytics.title
            content.image = .symbolTile(systemName: "chart.bar.fill", color: .systemPurple, traitCollection: cell.traitCollection)
            cell.show(content, isOn: analytics.isEnabled())
            cell.onChange = { [analytics] in analytics.setEnabled($0) }
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footer, _, indexPath in
            var content = UIListContentConfiguration.footer()
            content.text = self?.dataSource.sectionIdentifier(for: indexPath.section) == .analytics
                ? ProfileKitStrings.Profile.Analytics.footer
                : nil
            footer.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Item,
        >(collectionView: collectionView) { collectionView, indexPath, item in
            item == .analytics
                ? collectionView.dequeueConfiguredReusableCell(using: analyticsRow, for: indexPath, item: item)
                : collectionView.dequeueConfiguredReusableCell(using: row, for: indexPath, item: item)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: footer, for: indexPath)
        }
        return dataSource
    }
}
