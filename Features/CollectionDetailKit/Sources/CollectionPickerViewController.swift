import CollectionsKit
import ComponentKit
import FactoryKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CollectionPickerViewController

final class CollectionPickerViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Item: Hashable {
        case newCollection
        case collection(String)
    }

    // MARK: Properties

    private let model: CollectionPickerModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private var rowsByID = [String: SavedIn]()
    private var shownRows: [SavedIn]?
    private var shownBusy = Set<String>()
    private var shownCreating = false

    // MARK: Lifecycle

    init(spotID: String) {
        model = CollectionPickerModel(spotID: spotID)
        super.init(nibName: nil, bundle: nil)
        title = CollectionDetailKitStrings.Picker.title
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
    }

    override func updateProperties() {
        super.updateProperties()

        let rows = model.rows
        let busy = model.busy
        let isCreating = model.isCreating
        guard rows != shownRows || busy != shownBusy || isCreating != shownCreating else {
            return
        }
        shownRows = rows
        shownBusy = busy
        shownCreating = isCreating
        rowsByID = Dictionary(rows.map { ($0.collection.id, $0) }) { first, _ in first }
        var snapshot = NSDiffableDataSourceSnapshot<Int, Item>()
        snapshot.appendSections([0])
        snapshot.appendItems([.newCollection] + rows.map { .collection($0.collection.id) })
        snapshot.reconfigureItems(snapshot.itemIdentifiers)
        dataSource.apply(snapshot, animatingDifferences: false)
        if let sheet = navigationController?.sheetPresentationController {
            sheet.animateChanges { sheet.invalidateDetents() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    // MARK: Static Functions

    static func sheet(spotID: String) -> UIViewController {
        let picker = CollectionPickerViewController(spotID: spotID)
        let navigation = UINavigationController(rootViewController: picker)
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [
                .custom(identifier: .init("rows")) { [weak picker] context in
                    let limit = context.maximumDetentValue * 0.6
                    return picker.map { min($0.fittingHeight(), limit) } ?? limit
                },
                .large(),
            ]
            sheet.prefersGrabberVisible = true
        }
        return navigation
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        view.addSubview(collectionView)
    }

    private func fittingHeight() -> CGFloat {
        let width = navigationController?.view.bounds.width ?? 0
        if width > 0, collectionView.bounds.width != width {
            collectionView.frame.size.width = width
        }
        collectionView.layoutIfNeeded()
        return max(collectionView.adjustedContentInset.top, 56) + collectionView.collectionViewLayout.collectionViewContentSize
            .height
    }

    private func newCollection() {
        present(NewCollectionAlert.make { [model] name in
            Task {
                do {
                    try await model.createAndSave(named: name)
                } catch {
                    CollectionFailure.show(CollectionDetailKitStrings.Picker.failed, error)
                }
            }
        }, animated: true)
    }

    private func toggle(_ collectionID: String) {
        Task { [model] in
            do {
                try await model.toggle(collectionID)
            } catch {
                CollectionFailure.show(
                    CollectionDetailKitStrings.Picker.failed,
                    error,
                    notFound: CollectionDetailKitStrings.Picker.notOwnSpot,
                )
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { _, environment in
            NSCollectionLayoutSection.list(
                using: UICollectionLayoutListConfiguration(appearance: .insetGrouped),
                layoutEnvironment: environment,
            )
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Int, Item> {
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self else {
                return
            }
            var content = UIListContentConfiguration.subtitleCell()
            switch item {
            case .newCollection:
                content = .cell()
                content.text = CollectionDetailKitStrings.NewCollection.action
                content.textProperties.color = model.isCreating ? .secondaryLabel : .tintColor
                content.image = UIImage(systemName: "plus.circle.fill")
                cell.accessories = model.isCreating ? [.spinner()] : []
                cell.accessibilityTraits = model.isCreating ? [.button, .notEnabled] : .button

            case .collection(let id):
                guard let row = rowsByID[id] else {
                    return
                }
                let face = CollectionRow(row.collection, spotCount: 0).face
                content.text = face.title
                content.secondaryText = row.collection.visibility == .private
                    ? CollectionDetailKitStrings.Visibility.private
                    : CollectionDetailKitStrings.Visibility.public
                content.secondaryTextProperties.color = .secondaryLabel
                content.image = CoverImages.tile(for: face, side: 36, traits: traitCollection)
                content.imageProperties.maximumSize = CGSize(width: 36, height: 36)
                content.imageToTextPadding = 12
                if model.busy.contains(id) {
                    cell.accessories = [.spinner()]
                } else {
                    cell.accessories = row.contains ? [.checkmark()] : []
                }
                cell.accessibilityTraits = row.contains ? [.button, .selected] : .button
            }
            cell.contentConfiguration = content
        }
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { view, path, item in
            view.dequeueConfiguredReusableCell(using: cell, for: path, item: item)
        }
    }
}

// MARK: UICollectionViewDelegate

extension CollectionPickerViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .newCollection where !model.isCreating: newCollection()
        case .newCollection: break
        case .collection(let id): toggle(id)
        case nil: break
        }
    }
}
