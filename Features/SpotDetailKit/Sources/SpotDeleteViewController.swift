import ComponentKit
import os
import PinLayout
import SpotModelKit
import UIKit

// MARK: - SpotDeleteViewController

final class SpotDeleteViewController: UIViewController {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "spot-delete")

    // MARK: Properties

    private let model: SpotDeleteModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var deleting: Task<Void, Never>?
    private lazy var deleteItem = UIBarButtonItem(
        primaryAction: UIAction(
            title: SpotDetailKitStrings.Spot.More.delete,
            image: UIImage(systemName: "checkmark"),
        ) { [weak self] _ in
            self?.delete()
        }
    )
    private let deletingItem = UIBarButtonItem.spinner()

    // MARK: Lifecycle

    init(spot: SpotIndex) {
        model = SpotDeleteModel(spot: spot)
        super.init(nibName: nil, bundle: nil)
        title = SpotDetailKitStrings.Spot.More.delete
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) },
        )
        deleteItem.style = .prominent
        navigationItem.rightBarButtonItem = deleteItem
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.delegate = self
        view.addSubview(collectionView)
        var snapshot = NSDiffableDataSourceSnapshot<Int, SpotRemovalReason>()
        snapshot.appendSections([0])
        snapshot.appendItems(SpotRemovalReason.allCases)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override func updateProperties() {
        super.updateProperties()

        deleteItem.isEnabled = model.canDelete
        navigationItem.showRightItem(model.isDeleting ? deletingItem : deleteItem)
        // Read here so a new choice moves the checkmark.
        _ = model.reason
        var snapshot = dataSource.snapshot()
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    // MARK: Static Functions

    static func inNavigation(spot: SpotIndex) -> UIViewController {
        let navigation = UINavigationController(rootViewController: SpotDeleteViewController(spot: spot))
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    // MARK: Functions

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = .supplementary
            configuration.footerMode = .supplementary
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, SpotRemovalReason> {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, SpotRemovalReason> { [weak self] cell, _, reason in
            let isChosen = self?.model.reason == reason
            var content = UIListContentConfiguration.cell()
            content.text = reason.title
            cell.contentConfiguration = content
            cell.accessories = isChosen ? [.checkmark()] : []
            cell.accessibilityTraits = isChosen ? [.button, .selected] : .button
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { header, _, _ in
            var content = UIListContentConfiguration.header()
            content.text = SpotDetailKitStrings.Spot.Delete.question
            header.contentConfiguration = content
        }
        let footer = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { footer, _, _ in
            var content = UIListContentConfiguration.footer()
            content.text = SpotDetailKitStrings.Spot.Delete.footer
            footer.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Int,
            SpotRemovalReason,
        >(collectionView: collectionView) { view, path, reason in
            view.dequeueConfiguredReusableCell(using: cell, for: path, item: reason)
        }
        dataSource.supplementaryViewProvider = { view, kind, path in
            kind == UICollectionView.elementKindSectionFooter
                ? view.dequeueConfiguredReusableSupplementary(using: footer, for: path)
                : view.dequeueConfiguredReusableSupplementary(using: header, for: path)
        }
        return dataSource
    }

    private func delete() {
        guard deleting == nil, model.canDelete else {
            return
        }
        deleting = Task { [weak self, model] in
            defer { self?.deleting = nil }
            do {
                try await model.delete()
            } catch {
                Self.logger.error("A takedown didn't go through: \(String(describing: error), privacy: .public)")
                ToastView.showFailure(SpotDetailKitStrings.Spot.Delete.failed)
                return
            }
            // The spot sheet closes as its spot leaves the index, taking this screen with it, so Undo lives in a toast.
            ToastView.show(
                .icon(predefinedIcon: .success, title: SpotDetailKitStrings.Spot.Delete.done),
                actionTitle: SpotDetailKitStrings.Spot.Delete.undo,
            ) {
                model.restore()
            }
        }
    }
}

// MARK: UICollectionViewDelegate

extension SpotDeleteViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        model.reason = dataSource.itemIdentifier(for: indexPath)
    }
}
