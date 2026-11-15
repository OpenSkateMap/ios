import AccountKit
import AnalyticsKit
import AppLinkKit
import CollectionsKit
import ComponentKit
import ContributionsKit
import FactoryKit
import ImageKit
import os
import PinLayout
import SpotModelKit
public import SpotsKit
public import UIKit

// MARK: - SpotSheetViewController

public final class SpotSheetViewController: UIViewController {

    // MARK: Static Properties

    public static let smallDetentHeight: CGFloat = 420

    private static let summaryDetent = UISheetPresentationController.Detent.Identifier("summary")
    /// In compact height iOS 27 floats the sheet this far above the bottom yet keeps it full height, so it runs as far
    /// past the top (measured).
    private static let compactHeightInset: CGFloat = 8
    private static let summary = UISheetPresentationController.Detent.custom(identifier: summaryDetent) { context in
        guard #available(iOS 27, *), context.containerTraitCollection.verticalSizeClass == .compact else {
            return smallDetentHeight
        }
        return context.maximumDetentValue - compactHeightInset * 2
    }

    private static let sheetLevel = "spot"
    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "spot-sheet")

    // MARK: Computed Properties

    /// In compact height (iOS 27) the large detent runs past the top, so the summary is the only one.
    private var detents: [UISheetPresentationController.Detent] {
        guard #available(iOS 27, *), traitCollection.verticalSizeClass == .compact else {
            return [Self.summary, .large()]
        }
        return [Self.summary]
    }

    private var accountID: String? {
        guard case .signedIn(let account) = authSession.phase else {
            return nil
        }
        return account.id
    }

    private var isAdmin: Bool {
        guard case .signedIn(let account) = authSession.phase else {
            return false
        }
        return account.role == .admin
    }

    // MARK: Properties

    private let selection: SpotSelection
    private let model = SpotSheetModel()

    @Injected(\.contributionsSession) private var contributions
    @Injected(\.spotsSession) private var spots
    @Injected(\.authSession) private var authSession
    @Injected(\.analyticsManager) private var analytics
    @Injected(\.collectionsSession) private var collections

    private let tint = CAGradientLayer()
    private let scrollView = UIScrollView().softEdges()
    private let pageView = SpotPageView()
    private let titleBar = SpotTitleBarView()

    private var tintedSpot: (id: String, thumbhash: String?, base: UIColor)?
    private var rendered: (page: SpotPage, address: String?)?
    /// Shown until Favorites in SQLite agrees, or the change fails.
    private var tappedStar: (spotID: String, isStarred: Bool)?
    private var toastedDetailsFailure = false
    private var showsTitleBar = false

    // MARK: Lifecycle

    public init(selection: SpotSelection) {
        self.selection = selection
        super.init(nibName: nil, bundle: nil)
        setupSheet()
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
    }

    override public func updateProperties() {
        super.updateProperties()

        if let id = selection.spotID, id != model.spotID {
            scrollView.setContentOffset(.zero, animated: false)
            model.show(id)
        }
        render(model.page, address: model.address)
        showDetailsLoad(spots.selectedID == model.spotID ? spots.selectedDetails : .idle)
        view.setNeedsLayout()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        scrollView.pin
            .all()
        pageView.summaryHeight = traitCollection.verticalSizeClass == .compact ? view.bounds.height : Self.smallDetentHeight
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        tint.frame = CGRect(x: 0, y: 0, width: view.bounds.width, height: 480)
        CATransaction.commit()
        let height = pageView.sizeThatFits(CGSize(width: view.bounds.width, height: .greatestFiniteMagnitude)).height
        pageView.pin
            .top()
            .start()
            .width(view.bounds.width)
            .height(height)
        scrollView.contentSize = CGSize(width: view.bounds.width, height: height)
        titleBar.layoutMargins = UIEdgeInsets(top: 0, left: SpotPageView.margin, bottom: 0, right: SpotPageView.margin)
        titleBar.pin
            .top(SpotTitleBarView.top)
            .horizontally(view.safeAreaInsets)
            .height(SpotTitleBarView.buttonSide)
        pageView.layoutIfNeeded()
        updateTitleBar()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Functions

    private func setupSheet() {
        modalPresentationStyle = .pageSheet
        guard let sheet = sheetPresentationController else {
            return
        }
        sheet.detents = detents
        sheet.selectedDetentIdentifier = Self.summaryDetent
        sheet.setSheetLevel(Self.sheetLevel)
        sheet.largestUndimmedDetentIdentifier = Self.summaryDetent
        sheet.prefersGrabberVisible = true
        sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        sheet.placeBesideMap()
        sheet.delegate = self
        registerForTraitChanges([UITraitVerticalSizeClass.self]) { (controller: Self, _) in
            guard let sheet = controller.sheetPresentationController else {
                return
            }
            sheet.animateChanges { sheet.detents = controller.detents }
        }
    }

    private func setupViews() {
        view.backgroundColor = .systemBackground
        view.layer.addSublayer(tint)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: Self, _) in
            controller.applyTint()
        }
        scrollView.alwaysBounceVertical = true
        scrollView.delegate = self
        scrollView.topEdgeEffect.isHidden = true
        view.addSubview(scrollView)
        scrollView.addSubview(pageView)
        let edgeEffect = UIScrollEdgeElementContainerInteraction()
        edgeEffect.scrollView = scrollView
        edgeEffect.edge = .top
        titleBar.addInteraction(edgeEffect)
        titleBar.alpha = 0
        titleBar.isUserInteractionEnabled = false
        titleBar.accessibilityElementsHidden = true
        view.addSubview(titleBar)
    }

    private func updateTitleBar() {
        let barBottom = SpotTitleBarView.top + SpotTitleBarView.buttonSide
        let shows = scrollView.contentOffset.y + barBottom > pageView.titleBottom
        guard shows != showsTitleBar else {
            return
        }
        showsTitleBar = shows
        titleBar.isUserInteractionEnabled = shows
        titleBar.accessibilityElementsHidden = !shows
        scrollView.topEdgeEffect.isHidden = !shows
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseOut]) {
            self.titleBar.alpha = shows ? 1 : 0
            self.pageView.isTitleHidden = shows
        }
    }

    private func setupActions() {
        let tiles = pageView.tiles
        tiles.directions.showsMenuAsPrimaryAction = true
        tiles.directions.accessibilityHint = SpotDetailKitStrings.Spot.Actions.A11y.directionsHint
        for button in [tiles.directions, titleBar.directions] {
            button.menu = UIMenu(
                title: SpotDetailKitStrings.Spot.Directions.title,
                children: [UIDeferredMenuElement.uncached { [weak self] completion in
                    completion(self?.directionsActions() ?? [])
                }],
            )
        }
        tiles.share.addAction(UIAction { [weak self] _ in self?.share() }, for: .primaryActionTriggered)
        pageView.starButton.addAction(UIAction { [weak self] _ in self?.toggleStar() }, for: .primaryActionTriggered)
        tiles.more.showsMenuAsPrimaryAction = true
        for button in [tiles.more, titleBar.more] {
            button.menu = UIMenu(children: [UIDeferredMenuElement.uncached { [weak self] completion in
                completion(self?.moreActions() ?? [])
            }])
        }
        pageView.detailsStatusButton.addAction(
            UIAction { [weak self] _ in self?.spots.retrySelectedDetails() },
            for: .primaryActionTriggered,
        )
        pageView.ratingView.onVote = { [weak self] vote in self?.vote(vote) }
        pageView.cover.onOpen = { [weak self] index in self?.openPhotos(at: index) }
        pageView.mapCard.addAction(UIAction { [weak self] _ in self?.askForDirections() }, for: .touchUpInside)
        pageView.addressLabel.isUserInteractionEnabled = true
        for view in [pageView.addressLabel, pageView.mapCard] as [UIView] {
            view.addInteraction(UIContextMenuInteraction(delegate: self))
        }
        pageView.addedByButton.addAction(UIAction { [weak self] _ in self?.openAddedBy() }, for: .primaryActionTriggered)
        pageView.addVideoButton.addAction(UIAction { [weak self] _ in self?.openAddVideo() }, for: .primaryActionTriggered)
        pageView.videosSection.onOpen = { [weak self] in self?.view.window?.windowScene?.open($0, options: nil) }
        pageView.videosSection.onDiscard = { [contributions] id in
            Task {
                do {
                    try await contributions.discardVideo(id)
                } catch {
                    Self.logger.error("Removing a video draft failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    private func render(_ page: SpotPage, address: String?) {
        if model.isGone, selection.spotID == model.spotID {
            selection.spotID = nil
        }
        guard let spot = page.spot else {
            return
        }
        if let rendered, rendered.page == page, rendered.address == address {
            return
        }
        rendered = (page, address)
        if tintedSpot?.id != spot.id || tintedSpot?.thumbhash != spot.coverThumbhash {
            let base = spot.coverThumbhash.flatMap { ThumbHashRenderer.averageColor(base64: $0) } ?? spot.kind.tint
            tintedSpot = (spot.id, spot.coverThumbhash, base)
            applyTint()
        }
        pageView.show(page, address: address)
        titleBar.title = spot.title
        pageView.isStarred = starred(page)
    }

    private func applyTint() {
        guard let base = tintedSpot?.base.resolvedColor(with: traitCollection) else {
            return
        }
        let background = UIColor.systemBackground.resolvedColor(with: traitCollection)
        tint.colors = [base.withAlphaComponent(0.35).cgColor, background.withAlphaComponent(0).cgColor]
    }

    private func showDetailsLoad(_ load: DetailsLoad) {
        pageView.detailsLoad = load
        guard load == .failed else {
            toastedDetailsFailure = false
            return
        }
        if model.page.detail == nil, !toastedDetailsFailure {
            toastedDetailsFailure = true
            ToastView.showFailure(SpotDetailKitStrings.Spot.Details.failed)
        }
    }

    /// Someone else's private spot can't go into your Favorites.
    private func starred(_ page: SpotPage) -> Bool? {
        guard let spot = page.spot, !spot.isPrivate || page.detail?.addedByID == accountID else {
            return nil
        }
        if let tapped = tappedStar, tapped.spotID == spot.id, tapped.isStarred != page.isStarred {
            return tapped.isStarred
        }
        tappedStar = nil
        return page.isStarred
    }

    private func toggleStar() {
        guard let spot = model.page.spot, let before = pageView.isStarred else {
            return
        }
        let tap = (spotID: spot.id, isStarred: !before)
        tappedStar = tap
        pageView.isStarred = tap.isStarred
        Task { [weak self, collections] in
            do {
                try await collections.setStarred(tap.isStarred, spotID: spot.id)
            } catch {
                Self.logger.error("A star didn't go through: \(String(describing: type(of: error)), privacy: .public)")
                // A newer tap owns the star now; only this one's own state goes back.
                if let self, tappedStar?.spotID == tap.spotID, tappedStar?.isStarred == tap.isStarred {
                    tappedStar = nil
                    pageView.isStarred = before
                }
                ToastView.showFailure(SpotDetailKitStrings.Spot.Star.failed)
            }
        }
    }

    private func vote(_ vote: SpotVote) {
        guard let id = model.page.spot?.id else {
            return
        }
        Task { [spots] in
            do {
                try await spots.vote(vote, on: id)
            } catch {
                Self.logger.error("A vote didn't go through: \(String(describing: error), privacy: .public)")
                ToastView.showFailure(SpotDetailKitStrings.Spot.Vote.failed)
            }
        }
    }

    private func openPhotos(at index: Int) {
        let cover = pageView.cover
        let viewer = PhotoViewerController(
            photos: cover.pages,
            index: index,
            placeholders: cover.pages.indices.map { cover.pageView(at: $0)?.image },
            scale: traitCollection.displayScale > 0 ? traitCollection.displayScale : 3,
            cardControls: [pageView.starButton],
            sourceView: { [weak cover] in cover?.pageView(at: $0) },
        )
        viewer.onPageChange = { [weak cover] index in cover?.show(page: index, animated: false) }
        present(viewer, animated: true)
    }

    private func askForDirections() {
        let sheet = UIAlertController(
            title: SpotDetailKitStrings.Spot.Directions.chooserTitle,
            message: nil,
            preferredStyle: .actionSheet,
        )
        for app in DirectionsApp.allCases {
            sheet.addAction(UIAlertAction(title: app.title, style: .default) { [weak self] _ in
                self?.getDirections(in: app)
            })
        }
        sheet.addAction(UIAlertAction(title: SpotDetailKitStrings.Spot.Directions.cancel, style: .cancel))
        sheet.popoverPresentationController?.sourceItem = pageView.mapCard
        present(sheet, animated: true)
    }

    private func getDirections(in app: DirectionsApp) {
        guard let spot = model.page.spot else {
            return
        }
        app.open(to: spot, in: view.window?.windowScene)
        analytics.capture(.directionsOpened(spotID: spot.id, app: app.title))
    }

    private func share() {
        guard let spot = model.page.spot else {
            return
        }
        let link = SpotLinkItem(url: AppLink.spot(id: spot.id).url, title: spot.title, image: pageView.coverImage)
        let items: [Any] = [SpotDetailKitStrings.Spot.shareText(spot.title), link]
        let activity = UIActivityViewController(activityItems: items, applicationActivities: nil)
        activity.completionWithItemsHandler = { [analytics] type, completed, _, _ in
            if completed {
                analytics.capture(.spotShared(spotID: spot.id, activity: type?.rawValue))
            }
        }
        activity.popoverPresentationController?.sourceItem = pageView.tiles.share
        present(activity, animated: true)
    }

    private func directionsActions() -> [UIMenuElement] {
        var actions: [UIMenuElement] = DirectionsApp.allCases.map { app in
            UIAction(title: app.title) { [weak self] _ in self?.getDirections(in: app) }
        }
        if let copy = copyAddressAction() {
            actions.append(UIMenu(options: .displayInline, children: [copy]))
        }
        return actions
    }

    private func copyAddressAction() -> UIAction? {
        guard let address = model.address else {
            return nil
        }
        return UIAction(title: SpotDetailKitStrings.Spot.copyAddress, image: UIImage(systemName: "doc.on.doc")) { _ in
            UIPasteboard.general.string = address
        }
    }

    private func moreActions() -> [UIMenuElement] {
        var actions = [UIMenuElement]()
        if let spot = model.page.spot {
            let id = spot.id
            actions.append(UIAction(
                title: SpotDetailKitStrings.Spot.More.saveToCollection,
                image: UIImage(systemName: "bookmark"),
            ) { [weak self] _ in
                if let picker = Container.shared.collectionPickerScreen(id) {
                    self?.presentAbove(picker)
                }
            })
            if !spot.isPrivate, let detail = model.page.detail {
                let isYours = detail.addedByID != nil && detail.addedByID == accountID
                let edits = isYours || isAdmin
                actions.append(UIAction(
                    title: edits ? SpotDetailKitStrings.Spot.More.edit : SpotDetailKitStrings.Spot.More.suggestEdit,
                    image: UIImage(systemName: "pencil"),
                ) { [weak self] _ in
                    self?.openSuggestEdit()
                })
            }
            actions.append(UIMenu(options: .displayInline, children: [
                UIAction(title: SpotDetailKitStrings.Spot.More.report, image: UIImage(systemName: "flag")) { [weak self] _ in
                    if let report = Container.shared.spotReportScreen(id) {
                        self?.presentAbove(report)
                    }
                }
            ]))
            if isAdmin {
                actions.append(UIMenu(options: .displayInline, children: [
                    UIAction(
                        title: SpotDetailKitStrings.Spot.More.delete,
                        image: UIImage(systemName: "trash"),
                        attributes: .destructive,
                    ) { [weak self] _ in
                        self?.presentAbove(SpotDeleteViewController.inNavigation(spot: spot))
                    }
                ]))
            }
        }
        return actions
    }

    private func openAddVideo() {
        guard let spot = model.page.spot,
              let sheet = Container.shared.addVideoScreen(AddVideoTarget(spotID: spot.id, spotTitle: spot.title)) else {
            return
        }
        presentAbove(sheet)
    }

    private func presentAbove(_ controller: UIViewController) {
        controller.sheetPresentationController?.hidesSheet(at: Self.sheetLevel)
        controller.sheetPresentationController?.placeBesideMap()
        present(controller, animated: true)
    }

    private func openSuggestEdit() {
        guard let spot = model.page.spot, let detail = model.page.detail else {
            return
        }
        let target = SpotEditTarget(
            spotID: spot.id,
            title: spot.title,
            about: detail.about,
            kind: spot.kind,
            obstacles: detail.obstacles,
            condition: spot.condition,
            latitude: spot.latitude,
            longitude: spot.longitude,
            address: model.address,
            photos: model.page.photos,
        )
        guard let sheet = Container.shared.suggestEditScreen(target) else {
            return
        }
        presentAbove(sheet)
    }

    private func openAddedBy() {
        guard let id = model.page.detail?.addedByID, let profile = Container.shared.userProfileScreen(id) else {
            return
        }
        presentAbove(profile)
    }
}

// MARK: UIScrollViewDelegate

extension SpotSheetViewController: UIScrollViewDelegate {
    public func scrollViewDidScroll(_: UIScrollView) {
        updateTitleBar()
    }
}

// MARK: UISheetPresentationControllerDelegate

extension SpotSheetViewController: UISheetPresentationControllerDelegate {
    /// Cleared as the swipe starts, so the map deselects the pin alongside it; a swipe given up brings the spot back.
    public func presentationControllerWillDismiss(_: UIPresentationController) {
        let spotID = selection.spotID
        selection.spotID = nil
        transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            if context.isCancelled {
                self?.selection.spotID = spotID
            }
        }
    }
}

// MARK: UIContextMenuInteractionDelegate

extension SpotSheetViewController: UIContextMenuInteractionDelegate {
    public func contextMenuInteraction(_: UIContextMenuInteraction, configurationForMenuAtLocation _: CGPoint)
        -> UIContextMenuConfiguration? {
        guard let copy = copyAddressAction() else {
            return nil
        }
        return UIContextMenuConfiguration(actionProvider: { _ in UIMenu(children: [copy]) })
    }
}
