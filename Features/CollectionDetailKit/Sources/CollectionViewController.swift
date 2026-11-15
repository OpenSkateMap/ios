import AppLinkKit
import CollectionsKit
import ComponentKit
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - CollectionViewController

final class CollectionViewController: UIViewController {

    // MARK: Types

    nonisolated private enum Section: Hashable {
        case actions
        case about
        case spots
    }

    nonisolated private enum Item: Hashable {
        case actions
        case about
        case spot(String)
        case empty
        case loadingMore
    }

    // MARK: Static Properties

    /// Matches CollectionHeroView's inset.
    private static let rowInset: CGFloat = 20
    /// Concentric with the action capsules: their radius (22) plus their 20 pt margin.
    private static let pageCornerRadius: CGFloat = 42
    /// Rows from the end where the next page is asked for: a fling's worth, so it's usually there before it's seen.
    private static let loadMoreAhead = 30

    // MARK: Overridden Properties

    override var preferredStatusBarStyle: UIStatusBarStyle {
        hero.isHidden || isBarSolid ? .default : .lightContent
    }

    // MARK: Computed Properties

    private var heroHeight: CGFloat {
        min(view.bounds.width, view.bounds.height * 0.52).rounded()
    }

    // MARK: Properties

    private let model: CollectionModel
    private let hero = CollectionHeroView()
    private lazy var collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private lazy var dataSource = makeDataSource()
    private let covers = CoverImages()
    private var shown: CollectionModel.Shown?
    private var shownRemoving = Set<String>()
    private var shownLoadingMore = false
    private var spotsByID = [String: SpotIndex]()
    private var isBarSolid = false
    /// Set as it closes after Delete, Leave or Decline, so the emptied page doesn't flash a state on its way out.
    private var isClosing = false

    @Injected(\.appLinkOpener) private var links

    // MARK: Lifecycle

    init(id: String) {
        model = CollectionModel(id: id)
        super.init(nibName: nil, bundle: nil)
        navigationItem.largeTitleDisplayMode = .never
        applyBar()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        Task { [model] in await model.loadIfNeeded() }
    }

    override func updateProperties() {
        super.updateProperties()

        let shown = model.shown
        navigationItem.rightBarButtonItems = barItems(for: shown?.role)
        contentUnavailableConfiguration = emptyState()
        if hero.isHidden != (shown == nil) {
            hero.isHidden = shown == nil
            setNeedsStatusBarAppearanceUpdate()
        }
        let removing = model.removing
        let isLoadingMore = model.isLoadingMore
        guard shown != self.shown || removing != shownRemoving || isLoadingMore != shownLoadingMore else {
            return
        }
        let old = self.shown
        self.shown = shown
        shownRemoving = removing
        shownLoadingMore = isLoadingMore
        showHero(shown)
        spotsByID = Dictionary((shown?.spots ?? []).map { ($0.id, $0) }) { first, _ in first }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        if let shown {
            snapshot.appendSections([.actions])
            snapshot.appendItems([.actions], toSection: .actions)
            if !shown.about.isEmpty {
                snapshot.appendSections([.about])
                snapshot.appendItems([.about], toSection: .about)
            }
            snapshot.appendSections([.spots])
            snapshot.appendItems(shown.spots.isEmpty ? [.empty] : shown.spots.map { .spot($0.id) }, toSection: .spots)
            if isLoadingMore {
                snapshot.appendItems([.loadingMore], toSection: .spots)
            }
            snapshot.reconfigureItems(snapshot.itemIdentifiers)
        }
        dataSource.apply(snapshot, animatingDifferences: old != nil)
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        collectionView.pin
            .all()
        layoutInsets()
    }

    // MARK: Overrides

    /// A bar that changes height mid-scroll changes the safe area without a layout pass.
    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()

        layoutInsets()
    }

    // MARK: Static Functions

    private static func capsule(_ title: String, filled: Bool) -> UIButton.Configuration {
        var configuration: UIButton.Configuration = filled ? .filled() : .gray()
        configuration.title = title
        configuration.cornerStyle = .capsule
        return configuration
    }

    // MARK: Functions

    private func setupViews() {
        view.backgroundColor = .systemBackground
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        view.addSubview(collectionView)
        hero.pageOverlap = Self.pageCornerRadius
        // Right to left the list unflips only its background view; a plain subview draws mirrored.
        let heroBackground = UIView()
        heroBackground.addSubview(hero)
        collectionView.backgroundView = heroBackground
    }

    private func layoutInsets() {
        collectionView.contentInset.top = heroHeight - view.safeAreaInsets.top
        collectionView.verticalScrollIndicatorInsets.top = heroHeight - view.safeAreaInsets.top
        layoutHero()
    }

    private func layoutHero() {
        let top = -collectionView.adjustedContentInset.top
        let scrolled = collectionView.contentOffset.y - top
        let height = heroHeight
        hero.pin
            .top(-max(0, scrolled))
            .start()
            .width(collectionView.bounds.width)
            .height(height + max(0, -scrolled) + Self.pageCornerRadius)
        // Round at rest, square as its top reaches the screen's top, in step with the scroll in between.
        hero.pageCornerRadius = Self.pageCornerRadius * min(1, max(0, 1 - scrolled / height))
        let titleBelowBar = height - scrolled - hero.titleRise - view.safeAreaInsets.top
        hero.textAlpha = min(1, max(0, titleBelowBar / 32))
        let solid = titleBelowBar < 0
        guard solid != isBarSolid else {
            return
        }
        isBarSolid = solid
        applyBar()
    }

    private func applyBar() {
        let appearance = UINavigationBarAppearance()
        if isBarSolid {
            appearance.configureWithDefaultBackground()
        } else {
            appearance.configureWithTransparentBackground()
        }
        navigationItem.standardAppearance = appearance
        navigationItem.scrollEdgeAppearance = appearance
        navigationItem.compactAppearance = appearance
        navigationItem.title = isBarSolid ? shown?.face.title : nil
        setNeedsStatusBarAppearanceUpdate()
    }

    private func showHero(_ shown: CollectionModel.Shown?) {
        guard let shown else {
            hero.content = nil
            return
        }
        hero.content = CollectionHeroView.Content(title: shown.face.title, subtitle: shown.byline, backdrop: shown.face.backdrop)
        navigationItem.title = isBarSolid ? shown.face.title : nil
    }

    private func emptyState() -> UIContentUnavailableConfiguration? {
        if isClosing || [.decline, .delete, .leave].contains(model.action) {
            return nil
        }
        return switch model.phase {
        case .shown:
            nil

        case .gone:
            goneState()

        case .loading:
            .loading()

        case .invited(let invitation):
            invitationState(invitation)

        case .locked(let requested):
            lockedState(requested: requested)

        case .failed:
            failedState()
        }
    }

    private func invitationState(_ invitation: CollectionInvitation) -> UIContentUnavailableConfiguration {
        var invited = UIContentUnavailableConfiguration.empty()
        invited.image = UIImage(systemName: "rectangle.stack.badge.person.crop")
        invited.text = invitation.name
        invited.secondaryText = invitation.detail + "\n" + invitation.role.detail
        invited.button = Self.capsule(CollectionDetailKitStrings.Collection.Invitation.accept, filled: true)
        invited.button.showsActivityIndicator = model.action == .accept
        invited.buttonProperties.isEnabled = model.action == nil
        invited.buttonProperties.primaryAction = UIAction { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Collection.Invitation.failed) { try await $0.accept() }
        }
        invited.secondaryButton = Self.capsule(CollectionDetailKitStrings.Collection.Invitation.decline, filled: false)
        invited.secondaryButtonProperties.isEnabled = model.action == nil
        invited.secondaryButtonProperties.primaryAction = UIAction { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Collection.Invitation.failed, closesAfter: true) { try await $0.decline() }
        }
        return invited
    }

    private func lockedState(requested: Bool) -> UIContentUnavailableConfiguration {
        var locked = UIContentUnavailableConfiguration.empty()
        guard !requested else {
            locked.image = UIImage(systemName: "clock")
            locked.text = CollectionDetailKitStrings.Collection.Requested.title
            locked.secondaryText = CollectionDetailKitStrings.Collection.Requested.detail
            return locked
        }
        locked.image = UIImage(systemName: "lock.rectangle.stack")
        locked.text = CollectionDetailKitStrings.Collection.Locked.title
        locked.secondaryText = CollectionDetailKitStrings.Collection.Locked.detail
        locked.button = Self.capsule(CollectionDetailKitStrings.Collection.Locked.ask, filled: true)
        locked.button.showsActivityIndicator = model.action == .requestAccess
        locked.buttonProperties.isEnabled = model.action == nil
        locked.buttonProperties.primaryAction = UIAction { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Collection.Locked.failed) { try await $0.requestAccess() }
        }
        return locked
    }

    private func goneState() -> UIContentUnavailableConfiguration {
        var gone = UIContentUnavailableConfiguration.empty()
        gone.image = UIImage(systemName: "rectangle.stack")
        gone.text = CollectionDetailKitStrings.Collection.Gone.title
        gone.secondaryText = CollectionDetailKitStrings.Collection.Gone.detail
        return gone
    }

    private func failedState() -> UIContentUnavailableConfiguration {
        var failed = UIContentUnavailableConfiguration.empty()
        failed.image = UIImage(systemName: "wifi.exclamationmark")
        failed.text = CollectionDetailKitStrings.Collection.Failed.title
        var retry = UIButton.Configuration.borderless()
        retry.title = CollectionDetailKitStrings.Collection.Failed.retry
        failed.button = retry
        failed.buttonProperties.primaryAction = UIAction { [weak self] _ in
            Task { await self?.model.loadIfNeeded() }
        }
        return failed
    }

    private func barItems(for role: CollectionRole?) -> [UIBarButtonItem] {
        guard let role, role.isMember else {
            return []
        }
        if model.action == .delete || model.action == .leave {
            return [.spinner()]
        }
        let edit = UIAction(title: CollectionDetailKitStrings.Collection.Menu.edit, image: UIImage(systemName: "pencil")) {
            [weak self] _ in self?.openEditor()
        }
        let leave = UIAction(
            title: CollectionDetailKitStrings.Collection.Menu.leave,
            image: UIImage(systemName: "rectangle.portrait.and.arrow.right"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.confirmLeave()
        }
        let delete = UIAction(
            title: CollectionDetailKitStrings.Collection.Menu.delete,
            image: UIImage(systemName: "trash"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.confirmDelete()
        }
        let isFavorites = shown?.kind == .favorites
        let actions = [
            role.canEdit ? edit : nil,
            role == .owner ? nil : leave,
            role.managesPeople && !isFavorites ? delete : nil,
        ].compactMap(\.self)
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), menu: UIMenu(children: actions))
        more.accessibilityLabel = CollectionDetailKitStrings.Collection.A11y.more
        return [more]
    }

    private func share(from source: UIView) {
        guard let shown else {
            return
        }
        guard shown.role.isMember else {
            let activity = UIActivityViewController(
                activityItems: [AppLink.collection(id: model.id).url],
                applicationActivities: nil,
            )
            activity.popoverPresentationController?.sourceItem = source
            return present(activity, animated: true)
        }
        let sheet = CollectionAccessViewController(
            collectionID: model.id,
            role: shown.role,
            draft: CollectionDraft(name: shown.name, about: shown.about, visibility: shown.visibility),
            privateSpotCount: shown.spots.filter(\.isPrivate).count,
        )
        present(UINavigationController(rootViewController: sheet), animated: true)
    }

    private func openEditor() {
        guard let shown else {
            return
        }
        let editor = CollectionEditViewController(model: CollectionEditModel(
            collectionID: model.id,
            shown: shown,
            backdrop: shown.face.backdrop,
        ))
        present(UINavigationController(rootViewController: editor), animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(
            title: shown.map { CollectionDetailKitStrings.Collection.Delete.title($0.face.title) }
                ?? CollectionDetailKitStrings.Collection.Delete.genericTitle,
            message: CollectionDetailKitStrings.Collection.Delete.message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(
            title: CollectionDetailKitStrings.Collection.Delete.confirm,
            style: .destructive,
        ) { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Collection.Delete.failed, closesAfter: true) { try await $0.delete() }
        })
        alert.addAction(UIAlertAction(title: CollectionDetailKitStrings.Alert.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func confirmLeave() {
        let alert = UIAlertController(
            title: shown.map { CollectionDetailKitStrings.Collection.Leave.title($0.face.title) }
                ?? CollectionDetailKitStrings.Collection.Leave.genericTitle,
            message: CollectionDetailKitStrings.Collection.Leave.message,
            preferredStyle: .alert,
        )
        alert.addAction(UIAlertAction(
            title: CollectionDetailKitStrings.Collection.Leave.confirm,
            style: .destructive,
        ) { [weak self] _ in
            self?.run(CollectionDetailKitStrings.Collection.Leave.failed, closesAfter: true) { try await $0.leave() }
        })
        alert.addAction(UIAlertAction(title: CollectionDetailKitStrings.Alert.cancel, style: .cancel))
        present(alert, animated: true)
    }

    private func run(_ failureTitle: String,
                     closesAfter: Bool = false,
                     _ operation: @escaping (CollectionModel) async throws -> Void) {
        Task { [weak self, model] in
            do {
                try await operation(model)
                if closesAfter {
                    self?.isClosing = true
                    self?.close()
                }
            } catch {
                CollectionFailure.show(failureTitle, error)
            }
        }
    }

    /// A screen presented for a link closes first.
    private func showOnMap() {
        guard presentingViewController != nil, navigationController?.viewControllers.first === self else {
            return model.showOnMap()
        }
        dismiss(animated: true) { [model] in model.showOnMap() }
    }

    private func close() {
        guard let navigationController, navigationController.viewControllers.first !== self else {
            return dismiss(animated: true)
        }
        navigationController.popViewController(animated: true)
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            let section = self?.dataSource.sectionIdentifier(for: index)
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.backgroundColor = .clear
            configuration.showsSeparators = section == .spots && self?.shown?.spots.isEmpty == false
            if section == .spots, self?.shown?.role.canEdit == true {
                configuration.trailingSwipeActionsConfigurationProvider = { [weak self] path in
                    self?.removeAction(at: path)
                }
            }
            let list = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            list.contentInsets.top = section == .actions ? 20 : 8
            return list
        }
    }

    private func removeAction(at path: IndexPath) -> UISwipeActionsConfiguration? {
        guard case .spot(let spotID) = dataSource.itemIdentifier(for: path), !model.removing.contains(spotID) else {
            return nil
        }
        let remove = UIContextualAction(
            style: .destructive,
            title: CollectionDetailKitStrings.Collection.Spot.remove,
        ) { [weak self] _, _, done in
            self?.run(CollectionDetailKitStrings.Collection.Spot.removeFailed) { try await $0.remove(spotID) }
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [remove])
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let actions = UICollectionView.CellRegistration<CollectionActionsCell, Item> { [weak self] cell, _, _ in
            cell.onShowOnMap = { [weak self] in self?.showOnMap() }
            cell.onShare = { [weak self, weak cell] in
                guard let cell else {
                    return
                }
                self?.share(from: cell)
            }
            cell.isShowOnMapEnabled = self?.shown?.spots.isEmpty == false
            cell.backgroundConfiguration = .clear()
        }
        let about = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            var content = UIListContentConfiguration.cell()
            content.text = self?.shown?.about
            content.textProperties.font = .preferredFont(forTextStyle: .subheadline)
            content.textProperties.color = .secondaryLabel
            content.directionalLayoutMargins.leading = Self.rowInset
            content.directionalLayoutMargins.trailing = Self.rowInset
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .clear()
        }
        let spot = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, item in
            guard let self, case .spot(let id) = item, let spot = spotsByID[id] else {
                return
            }
            configure(cell, for: spot)
        }
        let loadingMore = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { cell, _, _ in
            var spinner = UIContentUnavailableConfiguration.loading()
            spinner.text = nil
            spinner.directionalLayoutMargins = NSDirectionalEdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0)
            cell.contentConfiguration = spinner
            cell.backgroundConfiguration = .clear()
        }
        let empty = UICollectionView.CellRegistration<UICollectionViewListCell, Item> { [weak self] cell, _, _ in
            var content = UIContentUnavailableConfiguration.empty()
            content.image = UIImage(systemName: "mappin.and.ellipse")
            content.text = CollectionDetailKitStrings.Collection.Empty.title
            content.secondaryText = self?.shown?.role.canEdit == true ? CollectionDetailKitStrings.Collection.Empty.detail : nil
            cell.contentConfiguration = content
            cell.backgroundConfiguration = .clear()
        }
        return UICollectionViewDiffableDataSource(collectionView: collectionView) { view, path, item in
            switch item {
            case .actions: view.dequeueConfiguredReusableCell(using: actions, for: path, item: item)
            case .about: view.dequeueConfiguredReusableCell(using: about, for: path, item: item)
            case .spot: view.dequeueConfiguredReusableCell(using: spot, for: path, item: item)
            case .empty: view.dequeueConfiguredReusableCell(using: empty, for: path, item: item)
            case .loadingMore: view.dequeueConfiguredReusableCell(using: loadingMore, for: path, item: item)
            }
        }
    }

    private func configure(_ cell: UICollectionViewListCell, for spot: SpotIndex) {
        let detail = spot.isPrivate
            ? CollectionDetailKitStrings.Collection.Spot.privateDetail(spot.kind.title)
            : spot.kind.title
        var content = UIListContentConfiguration.subtitleCell()
        content.text = spot.title
        content.textProperties.font = .preferredFont(forTextStyle: .body)
        content.secondaryText = detail
        content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
        content.secondaryTextProperties.color = .secondaryLabel
        content.directionalLayoutMargins.leading = Self.rowInset
        content.directionalLayoutMargins.trailing = Self.rowInset
        content.image = CoverImages.placeholder(
            thumbhash: spot.coverThumbhash,
            symbol: spot.kind.symbolName,
            fallback: spot.kind.tint,
        )
        content.imageProperties.maximumSize = CGSize(width: CoverImages.side, height: CoverImages.side)
        content.imageToTextPadding = 14
        cell.contentConfiguration = content
        cell.accessories = model.removing.contains(spot.id) ? [.spinner()] : []
        cell.accessibilityLabel = CollectionDetailKitStrings.Collection.Spot.a11y(spot.title, detail)
        // Without a chevron the row no longer says it opens something.
        cell.accessibilityTraits.insert(.button)
        guard spot.coverKey != nil else {
            return
        }
        let scale = traitCollection.displayScale
        Task { [weak cell, covers] in
            guard let image = await covers.cover(key: spot.coverKey, scale: scale),
                  var updated = cell?.contentConfiguration as? UIListContentConfiguration,
                  updated.text == spot.title else {
                return
            }
            updated.image = image
            cell?.contentConfiguration = updated
        }
    }
}

// MARK: UICollectionViewDelegate

extension CollectionViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_: UIScrollView) {
        layoutHero()
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay _: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard case .spot = dataSource.itemIdentifier(for: indexPath),
              indexPath.item >= collectionView.numberOfItems(inSection: indexPath.section) - Self.loadMoreAhead else {
            return
        }
        Task { [model] in
            do {
                try await model.loadMoreSpots()
            } catch {
                CollectionFailure.show(CollectionDetailKitStrings.Collection.Spots.moreFailed, error)
            }
        }
    }

    func collectionView(_: UICollectionView, shouldSelectItemAt indexPath: IndexPath) -> Bool {
        switch dataSource.itemIdentifier(for: indexPath) {
        case .spot: true
        case .actions, .about, .empty, .loadingMore, nil: false
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        guard case .spot(let id) = dataSource.itemIdentifier(for: indexPath) else {
            return
        }
        links.open(.spot(id: id))
    }
}
