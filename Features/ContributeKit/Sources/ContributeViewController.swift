import AppLinkKit
import ComponentKit
import ContributionsKit
import FactoryKit
import PinLayout
import SpotModelKit
public import UIKit

// MARK: - ContributeViewController

public final class ContributeViewController: UIViewController {

    // MARK: Types

    /// The tab, or all of Your Spots behind its See All.
    enum Mode {
        case tab
        case yourSpots
    }

    private nonisolated enum Section: Hashable {
        case nearYou
        case photoMatches
        case photos
        case hero
        case ways
        case yourSpots
    }

    private nonisolated enum Item: Hashable {
        case nearYou(SpotIndex.ID)
        case libraryMatch(LibraryMatch.ID)
        case photosPrompt
        case hero
        case reviewQueue
        case noSpots
        case spot(YourSpot.ID)
    }

    // MARK: Static Properties

    /// Even, so a header's trailing accessory centres on its title; `sectionSpacing` makes the gaps.
    private static let sectionHeaderMargins = (top: CGFloat(10), bottom: CGFloat(10))
    private static let sectionSpacing: CGFloat = 14
    private static let latestSpots = 3

    // MARK: Properties

    private let mode: Mode
    private let model = ContributeModel()
    private let photos = FromYourPhotosModel()
    @Injected(\.appLinkOpener) private var links
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var refreshControl = PullToRefreshControl { [weak self] in
        await self?.model.refresh() == false ? Self.showRefreshFailure : nil
    }

    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>?
    private var spotsByID = [YourSpot.ID: YourSpot]()
    private var nearYou = NearYou()
    private var hasMoreSpots = false
    private var hero = ContributeHeroView.Content(headline: "", message: "")
    private var reviewSubtitle = ""
    private var photosContent = FromYourPhotosModel.Content.hidden

    // MARK: Lifecycle

    public convenience init() {
        self.init(mode: .tab)
    }

    init(mode: Mode) {
        self.mode = mode
        super.init(nibName: nil, bundle: nil)

        title = switch mode {
        case .tab: ContributeKitStrings.Contribute.title
        case .yourSpots: ContributeKitStrings.Contribute.YourSpots.header
        }
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

        guard mode == .tab else {
            return
        }
        Task { await model.loadReviewQueue() }
        Task { await model.loadNearYou() }
        Task { await photos.refresh() }
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
    }

    override public func updateProperties() {
        super.updateProperties()

        if mode == .tab {
            navigationItem.subtitle = Self.summaryText(for: model.summary)
        }
        apply(
            model.spots,
            nearYou: model.nearYou,
            hero: Self.heroContent(for: model.summary),
            showsReviewQueue: model.showsReviewQueue,
            reviewSubtitle: Self.reviewSubtitle(waiting: model.reviewWaiting),
            photos: mode == .tab ? photos.content : .hidden,
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
        return ContributeHeroView.Content(
            headline: ContributeKitStrings.Contribute.Hero.Summary.headline,
            message: ContributeKitStrings.Contribute.Hero.Summary.message,
        )
    }

    /// What yours add up to, under the title; nothing before the first spot.
    static func summaryText(for summary: ContributeModel.Summary) -> String? {
        guard summary.added > 0 else {
            return nil
        }
        var parts = [ContributeKitStrings.Contribute.Hero.Summary.added(summary.added)]
        if summary.onTheMap > 0 {
            parts.append(ContributeKitStrings.Contribute.Hero.Summary.onTheMap(summary.onTheMap))
        }
        if summary.waiting > 0 {
            parts.append(ContributeKitStrings.Contribute.Hero.Summary.waiting(summary.waiting))
        }
        return parts.joined(separator: " · ")
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
        let configuration = UICollectionViewCompositionalLayoutConfiguration()
        configuration.interSectionSpacing = Self.sectionSpacing
        return UICollectionViewCompositionalLayout(sectionProvider: { [weak self] sectionIndex, environment in
            let section = self?.dataSource?.sectionIdentifier(for: sectionIndex) ?? .yourSpots
            if section == .nearYou {
                return Self.railSection(environment, spots: self?.nearYou.spots ?? [])
            }
            if section == .photoMatches {
                return Self.matchesSection(environment, content: self?.photosContent ?? .hidden)
            }
            var configuration = UICollectionLayoutListConfiguration(appearance: section == .ways ? .insetGrouped : .plain)
            // Under the cards, From Your Photos' note goes without a header of its own.
            let isNote = if case .matches = self?.photosContent { section == .photos } else { false }
            configuration.headerMode = section == .hero || isNote || self?.mode == .yourSpots ? .none : .supplementary
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
        }, configuration: configuration)
    }

    /// Cards widen with the text size and take the tallest one's measured height: a sideways row keeps estimates.
    private static func railSection(_ environment: any NSCollectionLayoutEnvironment,
                                    spots: [NearYou.Spot]) -> NSCollectionLayoutSection {
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: NearYouCell.width, compatibleWith: environment.traitCollection)
        let width = min(scaled, environment.container.effectiveContentSize.width - 64)
        let height = NearYouCell.height(fitting: spots, width: width, traits: environment.traitCollection)
        let size = NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: .absolute(height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        let header = NSCollectionLayoutBoundarySupplementaryItem(
            layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(56)),
            elementKind: UICollectionView.elementKindSectionHeader,
            alignment: .top,
        )
        section.boundarySupplementaryItems = [header]
        return section
    }

    /// Matches as cards in a row like Near You's, wider for the photo.
    private static func matchesSection(_ environment: any NSCollectionLayoutEnvironment,
                                       content: FromYourPhotosModel.Content) -> NSCollectionLayoutSection {
        guard case .matches(let cards, _) = content else {
            return railSection(environment, spots: [])
        }
        let traits = environment.traitCollection
        let scaled = UIFontMetrics(forTextStyle: .body).scaledValue(for: LibraryMatchCell.width, compatibleWith: traits)
        let width = min(scaled, environment.container.effectiveContentSize.width - 64)
        let height = LibraryMatchCell.height(fitting: cards, width: width, traits: traits)
        let size = NSCollectionLayoutSize(widthDimension: .absolute(width), heightDimension: .absolute(height))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuousGroupLeadingBoundary
        section.interGroupSpacing = 10
        section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)
        section.boundarySupplementaryItems = [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(56)),
                elementKind: UICollectionView.elementKindSectionHeader,
                alignment: .top,
            ),
        ]
        return section
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
        let nearYouCell = UICollectionView.CellRegistration<NearYouCell, SpotIndex.ID> { [weak self] cell, _, id in
            guard let self, let spot = nearYou.spots.first(where: { $0.id == id }) else {
                return
            }
            cell.configure(with: spot)
            cell.onAddPhotos = { Container.shared.spotEditOpener()?(id) }
        }
        let matchCell = UICollectionView.CellRegistration<LibraryMatchCell, LibraryMatch.ID> { [weak self] cell, _, id in
            guard let self, case .matches(let cards, _) = photosContent, let card = cards.first(where: { $0.id == id }) else {
                return
            }
            cell.configure(with: card)
            cell.onAdd = { Container.shared.spotEditOpener()?(card.match.spotID, libraryPhotoIDs: [card.match.assetID]) }
            cell.onSkip = { [weak self] in Task { await self?.photos.skip(id) } }
        }
        let promptCell = UICollectionView.CellRegistration<LibraryPromptCell, Item> { [weak self] cell, _, _ in
            guard let self, let prompt = photosContent.prompt else {
                return
            }
            cell.configure(with: prompt)
            cell.onAction = { [weak self] in self?.act(on: prompt) }
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
            let section = self?.dataSource?.sectionIdentifier(for: indexPath.section)
            // These headers sit inside their section's insets, already on the margin.
            let isInset = section == .ways || section == .nearYou || section == .photoMatches
            var content = UIListContentConfiguration.header()
            content.text = switch section {
            case .nearYou: ContributeKitStrings.Contribute.NearYou.header
            case .photoMatches, .photos: ContributeKitStrings.Contribute.FromYourPhotos.header
            case .ways: ContributeKitStrings.Contribute.Ways.header
            default: ContributeKitStrings.Contribute.YourSpots.header
            }
            content.textProperties.font = .preferredFont(forTextStyle: .title3, weight: .bold)
            content.textProperties.color = .label
            content.textProperties.transform = .none
            content.axesPreservingSuperviewLayoutMargins = isInset ? [] : .horizontal
            content.directionalLayoutMargins.top = Self.sectionHeaderMargins.top
            content.directionalLayoutMargins.bottom = Self.sectionHeaderMargins.bottom
            if isInset {
                content.directionalLayoutMargins.leading = 0
                content.directionalLayoutMargins.trailing = 0
            }
            header.contentConfiguration = content
            header.accessories = self?.headerAccessories(for: section) ?? []
        }
        let dataSource = UICollectionViewDiffableDataSource<
            Section,
            Item,
        >(collectionView: collectionView) { view, indexPath, item in
            switch item {
            case .nearYou(let id): view.dequeueConfiguredReusableCell(using: nearYouCell, for: indexPath, item: id)
            case .libraryMatch(let id): view.dequeueConfiguredReusableCell(using: matchCell, for: indexPath, item: id)
            case .photosPrompt: view.dequeueConfiguredReusableCell(using: promptCell, for: indexPath, item: item)
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

    private func apply(_ allSpots: [YourSpot],
                       nearYou: NearYou,
                       hero: ContributeHeroView.Content,
                       showsReviewQueue: Bool,
                       reviewSubtitle: String,
                       photos: FromYourPhotosModel.Content) {
        let spots = mode == .tab ? Array(allSpots.prefix(Self.latestSpots)) : allSpots
        let previous = spotsByID
        let previousNearYou = self.nearYou
        let heroChanged = hero != self.hero
        let reviewChanged = reviewSubtitle != self.reviewSubtitle
        let seeAllChanged = (allSpots.count > spots.count) != hasMoreSpots
        let previousPhotos = photosContent
        photosContent = photos
        spotsByID = Dictionary(spots.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        self.nearYou = nearYou
        hasMoreSpots = allSpots.count > spots.count
        self.hero = hero
        self.reviewSubtitle = reviewSubtitle
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if mode == .tab {
            if !nearYou.spots.isEmpty {
                snapshot.appendSections([.nearYou])
                snapshot.appendItems(nearYou.spots.map { .nearYou($0.id) })
            }
            appendPhotos(photos, to: &snapshot)
            snapshot.appendSections([.hero])
            snapshot.appendItems([.hero])
            if showsReviewQueue {
                snapshot.appendSections([.ways])
                snapshot.appendItems([.reviewQueue])
            }
        }
        snapshot.appendSections([.yourSpots])
        snapshot.appendItems(spots.isEmpty ? [.noSpots] : spots.map { .spot($0.id) })
        var changed = spots.filter { spot in previous[spot.id].map { $0 != spot } ?? false }.map { Item.spot($0.id) }
        changed += nearYou.spots
            .filter { spot in previousNearYou.spots.first { $0.id == spot.id }.map { $0 != spot } ?? false }
            .map { Item.nearYou($0.id) }
        if heroChanged {
            changed.append(.hero)
        }
        if reviewChanged, showsReviewQueue {
            changed.append(.reviewQueue)
        }
        changed += Self.changedPhotoItems(from: previousPhotos, to: photos)
        let shown = Set(snapshot.itemIdentifiers)
        snapshot.reconfigureItems(changed.filter(shown.contains))
        let reloadsHeaders = nearYou.cityName != previousNearYou.cityName || seeAllChanged
        if reloadsHeaders, let current = dataSource?.snapshot() {
            let kept = Set(current.sectionIdentifiers).intersection(snapshot.sectionIdentifiers)
            snapshot.reloadSections([Section.nearYou, .yourSpots].filter(kept.contains))
        }
        let isFirstApply = dataSource?.snapshot().numberOfItems == 0
        dataSource?.apply(snapshot, animatingDifferences: !isFirstApply)
    }

    private func headerAccessories(for section: Section?) -> [UICellAccessory] {
        switch section {
        case .nearYou:
            guard let city = nearYou.cityName else {
                return []
            }
            return [.label(text: city, options: .init(tintColor: .secondaryLabel, font: .preferredFont(forTextStyle: .subheadline)))]

        case .yourSpots where mode == .tab && hasMoreSpots:
            var configuration = UIButton.Configuration.plain()
            configuration.title = ContributeKitStrings.Contribute.YourSpots.seeAll
            configuration.contentInsets = .zero
            configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
                var attributes = attributes
                attributes.font = UIFont.preferredFont(forTextStyle: .body)
                return attributes
            }
            let button = UIButton(configuration: configuration, primaryAction: UIAction { [weak self] _ in self?.showAllSpots() })
            return [.customView(configuration: .init(customView: button, placement: .trailing(displayed: .always)))]

        default:
            return []
        }
    }

    private func appendPhotos(_ photos: FromYourPhotosModel.Content,
                              to snapshot: inout NSDiffableDataSourceSnapshot<Section, Item>) {
        switch photos {
        case .hidden:
            break

        case .prompt:
            snapshot.appendSections([.photos])
            snapshot.appendItems([.photosPrompt])

        case .matches(let cards, let note):
            snapshot.appendSections([.photoMatches])
            snapshot.appendItems(cards.map { .libraryMatch($0.id) })
            if note != nil {
                snapshot.appendSections([.photos])
                snapshot.appendItems([.photosPrompt])
            }
        }
    }

    private static func changedPhotoItems(from old: FromYourPhotosModel.Content,
                                          to new: FromYourPhotosModel.Content) -> [Item] {
        var changed = old.prompt != new.prompt ? [Item.photosPrompt] : []
        if case .matches(let oldCards, _) = old, case .matches(let newCards, _) = new {
            changed += newCards
                .filter { card in oldCards.first { $0.id == card.id }.map { $0 != card } ?? false }
                .map { .libraryMatch($0.id) }
        }
        return changed
    }

    private func act(on prompt: FromYourPhotosModel.Prompt) {
        switch prompt {
        case .intro:
            Task { await photos.findMyShots() }

        case .denied, .limited:
            if let settings = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settings)
            }

        case .scanning, .nothingFound:
            break
        }
    }

    private func showAllSpots() {
        navigationController?.pushViewController(ContributeViewController(mode: .yourSpots), animated: true)
    }


    private func startNewSpot() {
        present(NewSpotSheetController(), animated: true)
    }
}

// MARK: UICollectionViewDelegate

extension ContributeViewController: UICollectionViewDelegate {
    public func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource?.itemIdentifier(for: indexPath) {
        case .nearYou, .reviewQueue: true
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
        case .nearYou(let id):
            links.open(.spot(id: id))

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
