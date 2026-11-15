import AppLinkKit
import ComponentKit
import ContributionsKit
import FactoryKit
import PinLayout
public import UIKit

// MARK: - ContributeViewController

public final class ContributeViewController: UIViewController {

    // MARK: Types

    private nonisolated enum Section: Hashable {
        case hero
        case ways
        case yourSpots
    }

    private nonisolated enum Item: Hashable {
        case hero
        case reviewQueue
        case noSpots
        case spot(YourSpot.ID)
    }

    // MARK: Static Properties

    private static let sectionHeaderMargins = (top: CGFloat(24), bottom: CGFloat(10))

    // MARK: Properties

    private let model = ContributeModel()
    @Injected(\.appLinkOpener) private var links
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var refreshControl = PullToRefreshControl { [weak self] in
        await self?.model.refresh() == false ? Self.showRefreshFailure : nil
    }

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    private var spotsByID = [YourSpot.ID: YourSpot]()
    private var hero = ContributeHeroView.Content(headline: "", message: "")
    private var reviewSubtitle = ""

    // MARK: Lifecycle

    public init() {
        super.init(nibName: nil, bundle: nil)

        title = ContributeKitStrings.Contribute.title
        navigationItem.largeTitleDisplayMode = .inline
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        dataSource = makeDataSource()
        // The row tiles are images drawn at the text size.
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in
            guard let dataSource = self.dataSource else {
                return
            }
            var snapshot = dataSource.snapshot()
            guard snapshot.sectionIdentifiers.contains(.ways) else {
                return
            }
            snapshot.reconfigureItems(snapshot.itemIdentifiers(inSection: .ways))
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    override public func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        Task { await model.loadReviewQueue() }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override public func updateProperties() {
        super.updateProperties()

        apply(
            model.spots,
            hero: Self.heroContent(for: model.summary),
            showsReviewQueue: model.showsReviewQueue,
            reviewSubtitle: Self.reviewSubtitle(waiting: model.reviewWaiting),
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Static Functions

    static func heroContent(for summary: ContributeModel.Summary) -> ContributeHeroView.Content {
        guard summary.added > 0 else {
            return ContributeHeroView.Content(
                headline: ContributeKitStrings.Contribute.Hero.Empty.headline,
                message: ContributeKitStrings.Contribute.Hero.Empty.message,
            )
        }
        var parts = [ContributeKitStrings.Contribute.Hero.Summary.added(summary.added)]
        if summary.onTheMap > 0 {
            parts.append(ContributeKitStrings.Contribute.Hero.Summary.onTheMap(summary.onTheMap))
        }
        if summary.waiting > 0 {
            parts.append(ContributeKitStrings.Contribute.Hero.Summary.waiting(summary.waiting))
        }
        return ContributeHeroView.Content(
            headline: ContributeKitStrings.Contribute.Hero.Summary.headline,
            message: parts.joined(separator: " · "),
        )
    }

    static func reviewSubtitle(waiting: Int?) -> String {
        switch waiting {
        case nil: ContributeKitStrings.Contribute.ReviewQueue.subtitle
        case 0: ContributeKitStrings.Contribute.ReviewQueue.nothingWaiting
        case let count?: ContributeKitStrings.Contribute.ReviewQueue.waiting(count)
        }
    }

    private static func showRefreshFailure() {
        ToastView.showFailure(
            ContributeKitStrings.Contribute.RefreshFailed.title,
            subtitle: ContributeKitStrings.Contribute.RefreshFailed.message,
        )
    }

    // MARK: Functions

    public func showReviewQueue() {
        navigationController?.popToRootViewController(animated: false)
        navigationController?.pushViewController(ReviewQueueViewController(), animated: true)
    }

    private func setupViews() {
        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.alwaysBounceVertical = true
        collectionView.refreshControl = refreshControl
        view.addSubview(collectionView)
    }

    private func retry(_ id: YourSpot.ID) {
        Task { [model] in
            if await !model.retry(id) {
                ToastView.showFailure(ContributeKitStrings.Contribute.YourSpots.retryFailed)
            }
        }
    }

    private func discard(_ id: YourSpot.ID) {
        Task { [model] in
            switch await model.discard(id) {
            case .done:
                break

            case .alreadySending:
                ToastView.showFailure(
                    ContributeKitStrings.Contribute.YourSpots.DiscardFailed.title,
                    subtitle: ContributeKitStrings.Contribute.YourSpots.DiscardFailed.sending,
                )

            case .failed:
                ToastView.showFailure(ContributeKitStrings.Contribute.YourSpots.DiscardFailed.title)
            }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            let section = self?.dataSource?.sectionIdentifier(for: sectionIndex) ?? .yourSpots
            var configuration = UICollectionLayoutListConfiguration(appearance: section == .ways ? .insetGrouped : .plain)
            configuration.headerMode = section == .hero ? .none : .supplementary
            configuration.headerTopPadding = 0
            configuration.showsSeparators = section == .ways
            configuration.backgroundColor = .systemBackground
            configuration.trailingSwipeActionsConfigurationProvider = { [weak self] indexPath in
                self?.discardAction(at: indexPath)
            }
            let layoutSection = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            layoutSection.contentInsets.top = 0
            layoutSection.contentInsets.bottom = 0
            return layoutSection
        }
    }

    private func discardAction(at indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .spot(let id) = dataSource?.itemIdentifier(for: indexPath),
              let spot = spotsByID[id],
              spot.isUnsent,
              spot.badge != .sending else {
            return nil
        }
        let discard = UIContextualAction(
            style: .destructive,
            title: ContributeKitStrings.Contribute.YourSpots.discard,
        ) { [weak self] _, _, done in
            self?.discard(id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [discard])
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let heroCell = UICollectionView.CellRegistration<ContributeHeroCell, Item> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            cell.hero.show(hero)
            cell.hero.onAddSpot = { [weak self] in self?.startNewSpot() }
        }
        let spotCell = UICollectionView.CellRegistration<YourSpotCell, YourSpot.ID> { [weak self] cell, _, id in
            guard let self, let spot = spotsByID[id] else {
                return
            }
            cell.configure(with: spot)
            cell.onRetry = { [weak self] in self?.retry(id) }
        }
        let wayCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self else {
                return
            }
            var content = UIListContentConfiguration.subtitleCell()
            switch item {
            case .reviewQueue:
                content.image = .symbolTile(
                    systemName: "checkmark.seal.fill",
                    color: .systemGreen,
                    traitCollection: cell.traitCollection,
                )
                content.text = model.isCurator
                    ? ContributeKitStrings.Contribute.ReviewQueue.title
                    : ContributeKitStrings.ReviewQueue.ownerTitle
                content.secondaryText = reviewSubtitle

            default:
                return
            }
            content.textProperties.font = .preferredFont(forTextStyle: .body, weight: .semibold)
            content.secondaryTextProperties.color = .secondaryLabel
            content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.imageToTextPadding = 14
            cell.contentConfiguration = content
            cell.accessibilityUserInputLabels = content.text.map { [$0] }
            var background = UIBackgroundConfiguration.listCell()
            background.backgroundColor = .secondarySystemBackground
            cell.backgroundConfiguration = background
            cell.accessories = [.disclosureIndicator()]
        }
        let noSpotsCell = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            var content = UIListContentConfiguration.cell()
            content.text = ContributeKitStrings.Contribute.YourSpots.empty
            content.textProperties.color = .secondaryLabel
            content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .clear()
        }
        let header = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            let isWays = self?.dataSource?.sectionIdentifier(for: indexPath.section) == .ways
            var content = UIListContentConfiguration.header()
            content.text = isWays ? ContributeKitStrings.Contribute.Ways.header : ContributeKitStrings.Contribute.YourSpots.header
            content.textProperties.font = .preferredFont(forTextStyle: .title3, weight: .bold)
            content.textProperties.color = .label
            content.textProperties.transform = .none
            content.axesPreservingSuperviewLayoutMargins = isWays ? [] : .horizontal
            content.directionalLayoutMargins.top = Self.sectionHeaderMargins.top
            content.directionalLayoutMargins.bottom = Self.sectionHeaderMargins.bottom
            if isWays {
                content.directionalLayoutMargins.leading = 0
            }
            header.contentConfiguration = content
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Item,
        >(collectionView: collectionView) { view, indexPath, item in
            switch item {
            case .hero: view.dequeueConfiguredReusableCell(using: heroCell, for: indexPath, item: item)
            case .reviewQueue: view.dequeueConfiguredReusableCell(using: wayCell, for: indexPath, item: item)
            case .noSpots: view.dequeueConfiguredReusableCell(using: noSpotsCell, for: indexPath, item: item)
            case .spot(let id): view.dequeueConfiguredReusableCell(using: spotCell, for: indexPath, item: id)
            }
        }
        dataSource.supplementaryViewProvider = { view, _, indexPath in
            view.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        return dataSource
    }

    private func apply(_ spots: [YourSpot],
                       hero: ContributeHeroView.Content,
                       showsReviewQueue: Bool,
                       reviewSubtitle: String) {
        let previous = spotsByID
        let heroChanged = hero != self.hero
        let reviewChanged = reviewSubtitle != self.reviewSubtitle
        spotsByID = Dictionary(spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.hero = hero
        self.reviewSubtitle = reviewSubtitle
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([.hero])
        snapshot.appendItems([.hero])
        let ways: [Item] = showsReviewQueue ? [.reviewQueue] : []
        if !ways.isEmpty {
            snapshot.appendSections([.ways])
            snapshot.appendItems(ways)
        }
        snapshot.appendSections([.yourSpots])
        snapshot.appendItems(spots.isEmpty ? [.noSpots] : spots.map { .spot($0.id) })
        var changed = spots.filter { spot in previous[spot.id].map { $0 != spot } ?? false }.map { Item.spot($0.id) }
        if heroChanged {
            changed.append(.hero)
        }
        if reviewChanged, showsReviewQueue {
            changed.append(.reviewQueue)
        }
        snapshot.reconfigureItems(changed)
        let isFirstApply = dataSource?.snapshot().numberOfItems == 0
        dataSource?.apply(snapshot, animatingDifferences: !isFirstApply)
    }

    private func startNewSpot() {
        present(NewSpotSheetController(), animated: true)
    }
}

// MARK: UICollectionViewDelegate

extension ContributeViewController: UICollectionViewDelegate {
    public func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource?.itemIdentifier(for: indexPath) {
        case .reviewQueue: true
        case .spot(let id): spotsByID[id]?.spotID != nil
        default: false
        }
    }

    public func scrollViewDidEndDragging(_: UIScrollView, willDecelerate _: Bool) {
        refreshControl.fingerLifted()
    }

    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource?.itemIdentifier(for: indexPath) {
        case .reviewQueue:
            navigationController?.pushViewController(ReviewQueueViewController(), animated: true)

        case .spot(let id):
            if let spotID = spotsByID[id]?.spotID {
                links.open(.spot(id: spotID))
            }

        default:
            break
        }
    }
}
