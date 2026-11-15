import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CollectionsListViewController

final class CollectionsListViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case invitations
        case own
        case shared
    }

    nonisolated private enum Item: Hashable {
        case invitation(CollectionInvitation)
        case collection(CollectionRow)
    }

    // MARK: Properties

    private let model: CollectionsListModel
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private let refreshControl = UIRefreshControl()
    private let covers = CoverImages()
    private var shown: (invitations: [CollectionInvitation], own: [CollectionRow], shared: [CollectionRow])?
    private lazy var addItem: UIBarButtonItem = {
        let add = UIBarButtonItem(systemItem: .add, primaryAction: UIAction { [weak self] _ in self?.createCollection() })
        add.accessibilityLabel = CollectionDetailKitStrings.NewCollection.action
        return add
    }()

    private lazy var creatingItem = UIBarButtonItem.spinner()

    // MARK: Lifecycle

    init(model: CollectionsListModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        title = CollectionDetailKitStrings.Collections.title
        navigationItem.largeTitleDisplayMode = .never
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
        refresh(byPerson: false)
    }

    override func updateProperties() {
        super.updateProperties()

        if model.source == .mine {
            navigationItem.rightBarButtonItem = model.isCreating ? creatingItem : addItem
        }
        let invitations = model.invitations
        let own = model.own
        let shared = model.shared
        if shown?.invitations != invitations || shown?.own != own || shown?.shared != shared {
            shown = (invitations, own, shared)
            var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
            for (section, items) in [
                (Section.invitations, invitations.map(Item.invitation)),
                (.own, own.map(Item.collection)),
                (.shared, shared.map(Item.collection)),
            ] where !items.isEmpty {
                snapshot.appendSections([section])
                snapshot.appendItems(items, toSection: section)
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        contentUnavailableConfiguration = emptyState(isEmpty: invitations.isEmpty && own.isEmpty && shared.isEmpty)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemGroupedBackground
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        view.addSubview(collectionView)
    }

    private func setupActions() {
        refreshControl.addAction(UIAction { [weak self] _ in self?.refresh(byPerson: true) }, for: .valueChanged)
    }

    private func refresh(byPerson: Bool) {
        Task { [weak self] in
            let failure = await self?.model.refresh()
            self?.refreshControl.endRefreshing()
            guard byPerson, let self, let failure, contentUnavailableConfiguration == nil else {
                return
            }
            CollectionFailure.show(CollectionDetailKitStrings.Collections.Failed.title, failure)
        }
    }

    private func emptyState(isEmpty: Bool) -> UIContentUnavailableConfiguration? {
        guard isEmpty else {
            return nil
        }
        switch (model.source, model.phase) {
        case (_, .loading):
            return .loading()

        case (_, .failed):
            var failed = UIContentUnavailableConfiguration.empty()
            failed.image = UIImage(systemName: "wifi.exclamationmark")
            failed.text = CollectionDetailKitStrings.Collections.Failed.title
            failed.secondaryText = CollectionDetailKitStrings.Collections.Failed.detail
            return failed

        case (.mine, .loaded):
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "rectangle.stack")
            empty.text = CollectionDetailKitStrings.Collections.Empty.title
            empty.secondaryText = CollectionDetailKitStrings.Collections.Empty.detail
            return empty

        case (.user, .loaded):
            var empty = UIContentUnavailableConfiguration.empty()
            empty.image = UIImage(systemName: "rectangle.stack")
            empty.text = CollectionDetailKitStrings.Collections.noPublic
            return empty
        }
    }

    private func createCollection() {
        present(NewCollectionAlert.make { [weak self] name in
            Task { [weak self] in
                guard let self else {
                    return
                }
                do {
                    let id = try await model.create(named: name)
                    navigationController?.pushViewController(CollectionViewController(id: id), animated: true)
                } catch {
                    CollectionFailure.show(CollectionDetailKitStrings.NewCollection.failed, error)
                }
            }
        }, animated: true)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] _, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.headerMode = self?.model.source == .mine ? .supplementary : .none
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let invitationCell = UICollectionView.CellRegistration<
            UICollectionViewListCell,
            CollectionInvitation,
        > { cell, _, invitation in
            var content = UIListContentConfiguration.subtitleCell()
            content.text = invitation.name
            content.textProperties.font = .preferredFont(forTextStyle: .body, weight: .semibold)
            content.secondaryText = invitation.detail
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = UIImage(systemName: "rectangle.stack.badge.person.crop")
            content.imageProperties.reservedLayoutSize = CGSize(width: CoverImages.side, height: CoverImages.side)
            content.imageToTextPadding = 14
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
        }
        let cell = UICollectionView.CellRegistration<UICollectionViewListCell, CollectionRow> { [weak self] cell, _, row in
            guard let self else {
                return
            }
            let face = row.face
            var content = UIListContentConfiguration.subtitleCell()
            content.text = face.title
            content.textProperties.font = .preferredFont(forTextStyle: .body, weight: .semibold)
            content.secondaryText = row.subtitle
            content.secondaryTextProperties.color = .secondaryLabel
            content.image = CoverImages.tile(for: face, traits: traitCollection)
            content.imageProperties.maximumSize = CGSize(width: CoverImages.side, height: CoverImages.side)
            content.imageToTextPadding = 14
            cell.contentConfiguration = content
            cell.accessories = [.disclosureIndicator()]
            cell.accessibilityLabel = CollectionDetailKitStrings.Collections.Row.a11y(face.title, row.subtitle)
            guard let key = face.pictureKey else {
                return
            }
            let scale = traitCollection.displayScale
            Task { [weak cell, covers] in
                guard let image = await covers.cover(key: key, scale: scale),
                      var updated = cell?.contentConfiguration as? UIListContentConfiguration,
                      updated.text == face.title else {
                    return
                }
                updated.image = image
                cell?.contentConfiguration = updated
            }
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            var content = UIListContentConfiguration.header()
            content.text =
                switch self?.dataSource.sectionIdentifier(for: indexPath.section) {
                case .invitations: CollectionDetailKitStrings.Collections.invitations
                case .shared: CollectionDetailKitStrings.Collections.sharedWithYou
                case .own, nil: CollectionDetailKitStrings.Collections.yours
                }
            header.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Item,
        >(collectionView: collectionView) { view, path, item in
            switch item {
            case .invitation(let invitation):
                view.dequeueConfiguredReusableCell(using: invitationCell, for: path, item: invitation)
            case .collection(let row):
                view.dequeueConfiguredReusableCell(using: cell, for: path, item: row)
            }
        }
        dataSource.supplementaryViewProvider = { view, _, path in
            view.dequeueConfiguredReusableSupplementary(using: header, for: path)
        }
        return dataSource
    }
}

// MARK: UICollectionViewDelegate

extension CollectionsListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        let id =
            switch dataSource.itemIdentifier(for: indexPath) {
            case .invitation(let invitation): invitation.collectionID
            case .collection(let row): row.id
            case nil: nil as String?
            }
        guard let id else {
            return
        }
        navigationController?.pushViewController(CollectionViewController(id: id), animated: true)
    }
}
