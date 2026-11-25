import AnalyticsKit
import ComponentKit
import FactoryKit
import ImageKit
import MapKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - DiscoverSheetController

final class DiscoverSheetController: UIViewController {

    // MARK: Types

    enum Detent: CaseIterable {
        case collapsed
        case medium
        case large
    }

    private struct ListDrag {
        var movedPanel = false
        var lastMovedPanel = false
    }

    private nonisolated enum Section: Hashable {
        case collections
        case city
        case recent
        case nearby
        case spots
        case places
    }

    private nonisolated enum Item: Hashable {
        case collections
        case spot(String, Section)
        case place(String)
    }

    /// What an item's cell shows, so only items whose content changed are reconfigured.
    private enum Row: Equatable {
        case collections([CollectionCard])
        case spot(SpotIndex, city: String?)
        case place(title: String, subtitle: String, isResolving: Bool)
    }

    // MARK: Static Properties

    private static let margin: CGFloat = 16
    private static let sideInset: CGFloat = 8
    /// The system map card keeps this far from the screen's edges in landscape (iOS 27, measured).
    private static let besideMapMargin: CGFloat = 23
    private static let topCornerRadius: CGFloat = 36
    private static let grabberBand: CGFloat = 16
    private static let fadeDistance: CGFloat = 56
    private static let rubberBand: CGFloat = 0.3

    // MARK: Computed Properties

    var isBesideMap: Bool {
        traitCollection.placesCardBesideMap
    }

    /// How far the card, locate and the map's logo keep from the screen's edges beside the map. In landscape iOS
    /// reports the sensor housing's inset on both sides; it's kept only on the housing's side.
    var besideMapEdges: UIEdgeInsets {
        let housing = view.window?.deviceTopEdge
        return UIEdgeInsets(
            top: safeArea.top,
            left: housing == .right ? Self.besideMapMargin : max(safeArea.left, Self.besideMapMargin),
            bottom: max(safeArea.bottom, Self.besideMapMargin),
            right: housing == .left ? Self.besideMapMargin : max(safeArea.right, Self.besideMapMargin),
        )
    }

    private var fieldHeight: CGFloat {
        max(44, ceil(textField.font?.lineHeight ?? 22) + 22)
    }

    private var headerHeight: CGFloat {
        Self.grabberBand + fieldHeight + 12
    }

    private var chipHeight: CGFloat {
        max(36, ceil(UIFont.preferredFont(forTextStyle: .subheadline).lineHeight) + 18)
    }

    private var listTop: CGFloat {
        search == nil ? filterBar.frame.maxY + 8 : headerHeight
    }

    private var restingTop: CGFloat {
        let top = top(for: detent)
        return top + (container.height - top) * covered
    }

    private var sideBottom: CGFloat {
        container.height - besideMapEdges.bottom
    }

    private var sideWidth: CGFloat {
        let available = container.width - besideMapEdges.left - besideMapEdges.right
        return min(available, 400, max(320, available * 0.45))
    }

    private var sideX: CGFloat {
        view.effectiveUserInterfaceLayoutDirection == .rightToLeft
            ? container.width - besideMapEdges.right - sideWidth
            : besideMapEdges.left
    }

    private var bottomClearance: CGFloat {
        isBesideMap ? keyboardOverlap : max(safeArea.bottom, keyboardOverlap)
    }

    private var barChips: [UIButton] {
        (model.listedCollection == nil ? [] : [collectionChip, collectionInfoChip]) + [
            filtersChip,
            kindChip,
            conditionChip,
            obstaclesChip,
        ]
    }

    // MARK: Properties

    var onPickSpot: ((SpotIndex, AnalyticsEvent.SpotSource) -> Void)?
    var onPickPlace: ((_ region: MKCoordinateRegion, _ mark: MKPointAnnotation) -> Void)?
    var onAdd: (() -> Void)?
    var onMove: ((UIViewPropertyAnimator?) -> Void)?
    private(set) var edgeTop = CGFloat.greatestFiniteMagnitude
    private(set) var detent = Detent.medium

    private let model: SpotsMapModel
    private let glass = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    private let fill = UIView()
    private let grabber = UIButton(configuration: .plain())
    private let grabberBar = UIView()
    private let field = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
    private let fieldGlyph = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let textField = UITextField()
    private let trailingButton = UIButton(configuration: .glass())
    private let cityLabel = Label()
    private let filterBar = UIScrollView().softEdges()
    private let filtersChip = UIButton(configuration: .glass())
    private let kindChip = UIButton(configuration: .glass())
    private let conditionChip = UIButton(configuration: .glass())
    private let obstaclesChip = UIButton(configuration: .glass())
    private let collectionChip = UIButton(configuration: .glass())
    private let collectionInfoChip = UIButton(configuration: .glass())

    private lazy var collectionView = RegulatedCollectionView(frame: .zero, collectionViewLayout: makeLayout()).softEdges()
    private let listContainer = UIView()
    private let listFade = CAGradientLayer()
    private lazy var dataSource = makeDataSource()
    private let emptyView = UIContentUnavailableView(configuration: .empty())

    private var search: SpotSearchModel?
    private var placeLookup: Task<Void, Never>?
    private var resolvingPlaceID: String?
    private var shownFirstLoad: SpotsMapModel.FirstLoad?
    private var detentBeforeSearch = Detent.medium
    private var shownSpots = [String: SpotIndex]()
    private var shownPlaces = [String: SpotSearchModel.Place]()
    private var shownRows = [Item: Row]()
    private var shownFilter: SpotFilter?
    private var shownCollection: CollectionFocus?
    private var covered: CGFloat = 0
    private var container = CGRect.zero
    private var safeArea = UIEdgeInsets.zero
    private var keyboardOverlap: CGFloat = 0
    private var headerDragY: CGFloat?
    private var listDrag: ListDrag?
    private var animator: UIViewPropertyAnimator?

    // MARK: Lifecycle

    init(model: SpotsMapModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupViews()
        setupActions()
    }

    override func updateProperties() {
        super.updateProperties()

        // Only a collection going on or off the list animates it; other list updates don't.
        let refocused = model.listedCollection != shownCollection && view.window != nil
        if let search {
            resolvingPlaceID = search.resolvingPlaceID
            showSearch(search.content)
        } else {
            showCity(animated: refocused)
        }
        if model.filter != shownFilter || model.listedCollection != shownCollection {
            shownFilter = model.filter
            shownCollection = model.listedCollection
            UIView.transition(with: filterBar, duration: refocused ? 0.3 : 0, options: .transitionCrossDissolve) {
                self.updateChips()
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
        }
        view.setNeedsLayout()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        let width = view.bounds.width
        glass.pin
            .all()
        fill.pin
            .all()
        grabber.pin
            .top()
            .hCenter()
            .width(80)
            .height(Self.grabberBand)
        grabberBar.pin
            .top(5)
            .hCenter()
            .width(36)
            .height(5)
        // Beside the map the card's place already clears the sensor housing (`CardListCell`).
        let safeArea = isBesideMap ? .zero : view.safeAreaInsets
        collectionView.insetsLayoutMarginsFromSafeArea = !isBesideMap
        let sides = UIEdgeInsets(top: 0, left: Self.margin + safeArea.left, bottom: 0, right: Self.margin + safeArea.right)
        trailingButton.pin
            .top(Self.grabberBand)
            .end(sides)
            .size(fieldHeight)
        field.pin
            .top(Self.grabberBand)
            .start(sides)
            .before(of: trailingButton)
            .height(fieldHeight)
            .marginEnd(10)
        fieldGlyph.pin
            .vCenter()
            .start(14)
            .sizeToFit()
        textField.pin
            .vertically()
            .after(of: fieldGlyph)
            .end(10)
            .marginStart(8)

        cityLabel.pin
            .top(headerHeight + 4)
            .horizontally(sides)
            .sizeToFit(.width)
        let chipHeight = chipHeight
        filterBar.pin
            .below(of: cityLabel)
            .start()
            .width(width)
            .height(chipHeight)
            .marginTop(12)
        let (leading, trailing) = filterBar.isLTR() ? (sides.left, sides.right) : (sides.right, sides.left)
        filterBar.layoutRow(
            barChips,
            spacing: 8,
            insets: NSDirectionalEdgeInsets(top: 0, leading: leading, bottom: 0, trailing: trailing),
        ) { chip in
            CGSize(
                width: chip.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: chipHeight)).width,
                height: chipHeight,
            )
        }

        // The list runs up under the chips (in search, the field) and fades in across them, so nothing shows under the
        // title and rows ease out under its top edge effect.
        let edge = search == nil ? filterBar.frame : field.frame
        if isBesideMap {
            // As tall as the card at its highest, so a drag that resizes the card doesn't lay the list out again.
            listContainer.pin
                .top(edge.minY)
                .horizontally()
                .height(max(sideBottom - top(for: .large) - edge.minY, 0))
        } else {
            listContainer.pin
                .top(edge.minY)
                .bottom()
                .horizontally()
        }
        collectionView.pin
            .all()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        listFade.frame = listContainer.bounds
        listFade.locations = [0, NSNumber(value: Double(edge.height / max(listContainer.bounds.height, 1)))]
        CATransaction.commit()
        setListInset(top: listTop - edge.minY)
        layoutEmptyView(panelTop: view.frame.minY)
        collectionView.contentInset.bottom = bottomClearance
        collectionView.verticalScrollIndicatorInsets.bottom = bottomClearance
    }

    // MARK: Static Functions

    /// UIKit's sheet settle spring, measured on iOS 27.
    private static func settleSpring(velocity: CGFloat) -> UISpringTimingParameters {
        UISpringTimingParameters(mass: 1, stiffness: 333.33, damping: 36.51, initialVelocity: CGVector(dx: 0, dy: velocity))
    }

    private static func chipConfiguration(title: String?, symbol: String?, isActive: Bool) -> UIButton.Configuration {
        var configuration: UIButton.Configuration = isActive ? .prominentGlass() : .glass()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14)
        configuration.imagePadding = 6
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .footnote)
        if let symbol {
            configuration.image = UIImage(systemName: symbol)
        } else {
            configuration.image = UIImage(systemName: "chevron.down")
            configuration.imagePlacement = .trailing
        }
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .subheadline, weight: .medium)
            return attributes
        }
        return configuration
    }

    private static func collectionChipConfiguration(title: String) -> UIButton.Configuration {
        var configuration = chipConfiguration(title: title, symbol: "xmark", isActive: true)
        configuration.imagePlacement = .trailing
        return configuration
    }

    private static func chipTitle(_ name: String, picked: [String]) -> String {
        switch picked.count {
        case 0: name
        case 1: picked[0]
        default: SpotsMapKitStrings.Filters.Chip.count(name, picked.count)
        }
    }

    private static func detail(for spot: SpotIndex) -> String {
        let obstacles = spot.obstacles.prefix(2).map(SpotObstacle.title(of:))
        guard !obstacles.isEmpty else {
            return spot.kind.title
        }
        return SpotsMapKitStrings.Search.Result.subtitle(spot.kind.title, obstacles.formatted(.list(type: .and, width: .narrow)))
    }

    // MARK: Functions

    func layout(in bounds: CGRect, safeArea: UIEdgeInsets) {
        container = bounds
        self.safeArea = safeArea
        showDetentForAccessibility()
        guard headerDragY == nil, listDrag == nil, animator == nil else {
            return
        }
        let top = restingTop
        edgeTop = top
        place(top)
    }

    func setCovered(_ amount: CGFloat) {
        guard amount != covered else {
            return
        }
        covered = amount
        showDetentForAccessibility()
        guard headerDragY == nil, listDrag == nil else {
            return
        }
        stopSettling()
        let top = restingTop
        edgeTop = top
        place(top)
    }

    func endSearch() {
        guard search != nil else {
            return
        }
        closeSearch(settlingAt: detentBeforeSearch)
    }

    func revealMap() {
        if detent == .large {
            settle(at: .medium, velocity: 0)
        }
    }

    private func showPlaceholder() {
        textField.placeholder = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? SpotsMapKitStrings.Search.placeholderShort
            : SpotsMapKitStrings.Search.placeholder
    }

    private func setupViews() {
        let corners = UICornerConfiguration.corners(
            topLeftRadius: .fixed(Self.topCornerRadius),
            topRightRadius: .fixed(Self.topCornerRadius),
            bottomLeftRadius: .containerConcentric(minimum: Self.topCornerRadius),
            bottomRightRadius: .containerConcentric(minimum: Self.topCornerRadius),
        )
        view.cornerConfiguration = corners
        view.clipsToBounds = true
        glass.cornerConfiguration = corners
        fill.backgroundColor = .systemBackground
        fill.isUserInteractionEnabled = false
        grabberBar.backgroundColor = .tertiaryLabel
        grabberBar.layer.cornerRadius = 2.5
        grabberBar.isUserInteractionEnabled = false
        grabber.addSubview(grabberBar)
        grabber.accessibilityLabel = SpotsMapKitStrings.Discover.A11y.grabber

        field.cornerConfiguration = .capsule()
        fieldGlyph.tintColor = .secondaryLabel
        fieldGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        fieldGlyph.isAccessibilityElement = false
        // Capped as the system's bars are; past that a field this wide shrinks its placeholder to fit.
        textField.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17), maximumPointSize: 34)
        textField.adjustsFontForContentSizeCategory = true
        showPlaceholder()
        registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: Self, _) in self.showPlaceholder() }
        textField.returnKeyType = .search
        textField.clearButtonMode = .whileEditing
        textField.autocorrectionType = .no
        textField.enablesReturnKeyAutomatically = true
        textField.delegate = self
        field.contentView.addSubview(fieldGlyph)
        field.contentView.addSubview(textField)
        showTrailingButton()

        cityLabel.numberOfLines = 0
        cityLabel.accessibilityTraits = .header
        filterBar.showsHorizontalScrollIndicator = false
        filterBar.contentInsetAdjustmentBehavior = .never
        filterBar.showsVerticalScrollIndicator = false
        filterBar.alwaysBounceHorizontal = true
        filterBar.clipsToBounds = false
        filtersChip.accessibilityLabel = SpotsMapKitStrings.Filters.title
        for chip in [kindChip, conditionChip, obstaclesChip] {
            chip.showsMenuAsPrimaryAction = true
        }
        collectionInfoChip.configuration = Self.chipConfiguration(title: nil, symbol: "info", isActive: false)
        collectionInfoChip.accessibilityLabel = SpotsMapKitStrings.Collections.Card.open
        for chip in [collectionChip, collectionInfoChip, filtersChip, kindChip, conditionChip, obstaclesChip] {
            filterBar.addSubview(chip)
        }
        trailingButton.preferredMenuElementOrder = .fixed
        for header in [field, trailingButton, filterBar] as [UIView] {
            let interaction = UIScrollEdgeElementContainerInteraction()
            interaction.scrollView = collectionView
            interaction.edge = .top
            header.addInteraction(interaction)
        }
        updateChips()

        collectionView.backgroundColor = .clear
        listFade.colors = [UIColor.clear.cgColor, UIColor.black.cgColor]
        listContainer.layer.mask = listFade
        listContainer.addSubview(collectionView)
        collectionView.keyboardDismissMode = .onDrag
        // Made now: the layout's section provider reads it.
        _ = dataSource
        emptyView.isHidden = true
        for subview in [
            glass,
            fill,
            listContainer,
            emptyView,
            cityLabel,
            filterBar,
            field,
            trailingButton,
            grabber,
        ] {
            view.addSubview(subview)
        }
        showDetentForAccessibility()
    }

    private func setupActions() {
        grabber.addAction(UIAction { [weak self] _ in self?.cycleDetent() }, for: .primaryActionTriggered)
        trailingButton.addAction(UIAction { [weak self] _ in self?.trailingButtonTapped() }, for: .primaryActionTriggered)
        filtersChip.addAction(UIAction { [weak self] _ in self?.openFilters() }, for: .primaryActionTriggered)
        collectionChip.addAction(UIAction { [weak self] _ in self?.model.clearCollection() }, for: .primaryActionTriggered)
        collectionInfoChip.addAction(UIAction { [weak self] _ in self?.openListedCollection() }, for: .primaryActionTriggered)
        textField.addAction(
            UIAction { [weak self] _ in self?.search?.setQuery(self?.textField.text ?? "") },
            for: .editingChanged,
        )
        collectionView.delegate = self
        collectionView.regulator = self
        let pan = UIPanGestureRecognizer(target: self, action: #selector(headerPanned(_:)))
        pan.delegate = self
        view.addGestureRecognizer(pan)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChange(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(differentiateWithoutColorChanged),
            name: UIAccessibility.differentiateWithoutColorDidChangeNotification,
            object: nil,
        )
    }

    private func top(for detent: Detent) -> CGFloat {
        switch detent {
        case .collapsed: (isBesideMap ? sideBottom : container.height - safeArea.bottom) - headerHeight

        case .medium:
            isBesideMap
                ? ((top(for: .large) + top(for: .collapsed)) / 2).rounded()
                : min((container.height / 2).rounded(), top(for: .collapsed))

        case .large: safeArea.top + 10
        }
    }

    private func place(_ top: CGFloat) {
        if isBesideMap {
            // Below its collapsed height it keeps that height and slides away.
            let height = sideBottom - min(top, self.top(for: .collapsed))
            view.frame = CGRect(x: sideX, y: top, width: sideWidth, height: height)
            fill.alpha = 0
        } else {
            let medium = self.top(for: .medium)
            let large = self.top(for: .large)
            let full = medium > large ? min(max((medium - top) / (medium - large), 0), 1) : 0
            let inset = Self.sideInset * (1 - full)
            view.frame = CGRect(x: inset, y: top, width: container.width - inset * 2, height: container.height - large)
            fill.alpha = full
        }
        let risen = self.top(for: .collapsed) - top
        let shown = search == nil ? min(max(risen / Self.fadeDistance, 0), 1) : 1
        collectionView.alpha = shown
        emptyView.alpha = shown
        layoutEmptyView(panelTop: top)
        for content in [cityLabel, filterBar] as [UIView] {
            content.alpha = search == nil ? shown : 0
        }
    }

    /// Keeps how far the list is scrolled (search's header is shorter than the city's).
    private func setListInset(top: CGFloat) {
        let inset = collectionView.contentInset.top
        guard inset != top else {
            return
        }
        let scrolled = collectionView.contentOffset.y + inset
        collectionView.contentInset.top = top
        collectionView.verticalScrollIndicatorInsets.top = top
        collectionView.contentOffset.y = scrolled - top
    }

    private func layoutEmptyView(panelTop: CGFloat) {
        let visibleBottom = (isBesideMap ? sideBottom : container.height) - bottomClearance - panelTop
        var top = listTop
        if let path = dataSource.indexPath(for: .collections), let cards = collectionView.layoutAttributesForItem(at: path) {
            top = max(top, collectionView.convert(cards.frame, to: view).maxY)
        }
        emptyView.pin
            .top(top)
            .horizontally()
            .height(max(visibleBottom - top, 0))
    }

    private func move(to top: CGFloat, velocity: CGFloat, animated: Bool) {
        stopSettling()
        edgeTop = top
        guard animated else {
            place(top)
            onMove?(nil)
            return
        }
        let distance = top - view.frame.minY
        let relative = abs(distance) > 1 ? velocity / distance : 0
        let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: Self.settleSpring(velocity: relative))
        animator.addAnimations { [weak self] in self?.place(top) }
        animator.addCompletion { [weak self, weak animator] _ in
            if self?.animator === animator {
                self?.animator = nil
            }
        }
        self.animator = animator
        onMove?(animator)
        animator.startAnimation()
    }

    private func settle(at detent: Detent, velocity: CGFloat) {
        self.detent = detent
        showDetentForAccessibility()
        move(to: top(for: detent), velocity: velocity, animated: view.window != nil)
    }

    private func settle(releasedAt velocity: CGFloat) {
        let projected = view.frame.minY + velocity * 0.2
        let target = Detent.allCases.min { abs(top(for: $0) - projected) < abs(top(for: $1) - projected) }
        settle(at: target ?? detent, velocity: velocity)
    }

    private func drag(to top: CGFloat) {
        let highest = self.top(for: .large)
        let lowest = self.top(for: .collapsed)
        let current = view.frame.minY
        let delta = top - current
        let outside = top < highest || top > lowest
        let moved = current + (outside ? delta * Self.rubberBand : delta)
        edgeTop = moved
        place(moved)
        onMove?(nil)
    }

    private func stopSettling() {
        animator?.stopAnimation(true)
        animator = nil
    }

    private func cycleDetent() {
        switch detent {
        case .collapsed: settle(at: .medium, velocity: 0)
        case .medium: settle(at: .large, velocity: 0)
        case .large: settle(at: .collapsed, velocity: 0)
        }
    }

    private func showDetentForAccessibility() {
        grabber.accessibilityValue =
            switch detent {
            case .collapsed: SpotsMapKitStrings.Discover.A11y.collapsed
            case .medium: SpotsMapKitStrings.Discover.A11y.halfScreen
            case .large: SpotsMapKitStrings.Discover.A11y.expanded
            }
        view.accessibilityViewIsModal = detent == .large && !isBesideMap && covered == 0
    }

    private func showTrailingButton() {
        if search == nil {
            trailingButton.configuration = .glassIcon("plus", textStyle: .title3, scale: .medium)
            trailingButton.accessibilityLabel = SpotsMapKitStrings.Discover.A11y.add
            trailingButton.menu = UIMenu(children: [
                UIAction(
                    title: SpotsMapKitStrings.Discover.Add.spot,
                    image: UIImage(systemName: "mappin.and.ellipse"),
                ) { [weak self] _ in
                    self?.onAdd?()
                },
                UIAction(
                    title: SpotsMapKitStrings.Discover.Add.collection,
                    image: UIImage(systemName: "rectangle.stack.badge.plus"),
                ) { [weak self] _ in
                    self?.present(Container.shared.newCollectionScreen())
                },
            ])
            trailingButton.showsMenuAsPrimaryAction = true
        } else {
            trailingButton.configuration = .glassIcon("xmark", textStyle: .body, scale: .medium)
            trailingButton.accessibilityLabel = SpotsMapKitStrings.Search.A11y.close
            trailingButton.menu = nil
            trailingButton.showsMenuAsPrimaryAction = false
        }
    }

    private func trailingButtonTapped() {
        if search != nil {
            closeSearch(settlingAt: detentBeforeSearch)
        }
    }

    private func openSearch() {
        guard search == nil else {
            return
        }
        model.clearPlaceMark()
        let search = SpotSearchModel()
        if let region = model.visibleRegion {
            search.open(over: region)
        }
        self.search = search
        detentBeforeSearch = detent == .collapsed ? .medium : detent
        showTrailingButton()
        settle(at: .large, velocity: 0)
        setNeedsUpdateProperties()
    }

    private func closeSearch(settlingAt detent: Detent) {
        placeLookup?.cancel()
        textField.text = nil
        textField.resignFirstResponder()
        search = nil
        showTrailingButton()
        settle(at: detent, velocity: 0)
        setNeedsUpdateProperties()
    }

    private func openFilters() {
        let filters = FiltersSheet.make(filter: model.filter, count: { [model] in await model.count(matching: $0) }) {
            [weak self] filter in
            self?.model.setFilter(filter)
        }
        filters.sheetPresentationController?.placeBesideMap()
        present(filters, animated: true)
    }

    private func updateFilter(_ change: (inout SpotFilter) -> Void) {
        var filter = model.filter
        change(&filter)
        model.setFilter(filter)
    }

    private func updateChips() {
        let filter = model.filter
        collectionChip.isHidden = model.listedCollection == nil
        collectionInfoChip.isHidden = model.listedCollection == nil
        collectionChip.configuration = model.listedCollection
            .map { Self.collectionChipConfiguration(title: $0.kind.title(named: $0.name)) }
        collectionChip.accessibilityHint = SpotsMapKitStrings.Collections.Chip.hint
        let marksFilterWithShape = !filter.isEmpty && UIAccessibility.shouldDifferentiateWithoutColor
        filtersChip.configuration = Self.chipConfiguration(
            title: nil,
            symbol: marksFilterWithShape ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease",
            isActive: !filter.isEmpty,
        )
        kindChip.configuration = Self.chipConfiguration(
            title: Self.chipTitle(SpotsMapKitStrings.Filters.kind, picked: filter.kinds.map(\.title)),
            symbol: nil,
            isActive: !filter.kinds.isEmpty,
        )
        conditionChip.configuration = Self.chipConfiguration(
            title: Self.chipTitle(SpotsMapKitStrings.Filters.condition, picked: filter.conditions.map(\.title)),
            symbol: nil,
            isActive: !filter.conditions.isEmpty,
        )
        obstaclesChip.configuration = Self.chipConfiguration(
            title: Self.chipTitle(SpotsMapKitStrings.Filters.obstacles, picked: filter.obstacles.map(SpotObstacle.title(of:))),
            symbol: nil,
            isActive: !filter.obstacles.isEmpty,
        )
        kindChip.menu = kindMenu()
        conditionChip.menu = conditionMenu()
        obstaclesChip.menu = obstaclesMenu()
        view.setNeedsLayout()
    }

    private func filterMenu<Option: Hashable>(options: [Option],
                                              picked: Set<Option>,
                                              title: (Option) -> String,
                                              image: (Option) -> UIImage?,
                                              set: @escaping (inout SpotFilter, Set<Option>) -> Void,
                                              chip: UIButton,
                                              rebuild: @escaping () -> UIMenu) -> UIMenu {
        let refresh = { [weak chip] in
            chip?.contextMenuInteraction?.updateVisibleMenu { _ in rebuild() }
        }
        let any = UIAction(title: SpotsMapKitStrings.Filters.any, state: picked.isEmpty ? .on : .off) { [weak self] _ in
            self?.updateFilter { set(&$0, []) }
        }
        let items = options.map { option in
            UIAction(
                title: title(option),
                image: image(option),
                attributes: .keepsMenuPresented,
                state: picked.contains(option) ? .on : .off,
            ) { [weak self] _ in
                self?.updateFilter { filter in set(&filter, picked.symmetricDifference([option])) }
                refresh()
            }
        }
        return UIMenu(children: [
            UIMenu(options: .displayInline, children: [any]),
            UIMenu(options: .displayInline, children: items),
        ])
    }

    private func kindMenu() -> UIMenu {
        filterMenu(
            options: SpotKind.allCases,
            picked: model.filter.kinds,
            title: \.title,
            image: { UIImage(systemName: $0.symbolName) },
            set: { $0.kinds = $1 },
            chip: kindChip,
            rebuild: { [weak self] in self?.kindMenu() ?? UIMenu() },
        )
    }

    private func conditionMenu() -> UIMenu {
        filterMenu(
            options: SpotCondition.allCases,
            picked: model.filter.conditions,
            title: \.title,
            image: { _ in nil },
            set: { $0.conditions = $1 },
            chip: conditionChip,
            rebuild: { [weak self] in self?.conditionMenu() ?? UIMenu() },
        )
    }

    private func obstaclesMenu() -> UIMenu {
        let picked = model.filter.obstacles
        return filterMenu(
            options: SpotObstacle.choices(including: picked),
            picked: picked,
            title: SpotObstacle.title(of:),
            image: { _ in nil },
            set: { $0.obstacles = $1 },
            chip: obstaclesChip,
            rebuild: { [weak self] in self?.obstaclesMenu() ?? UIMenu() },
        )
    }

    private func showCityLabel(count: Int, animated: Bool) {
        let heading = model.listedCollection.map { $0.kind.title(named: $0.name) } ?? model.place?.name
        guard let heading else {
            cityLabel.attributedText = nil
            return
        }
        let text = NSMutableAttributedString(string: heading, attributes: [
            .font: UIFont.preferredFont(forTextStyle: .title2, weight: .bold),
            .foregroundColor: UIColor.label,
        ])
        let isEmptyPlace = count == 0 && model.listedCollection == nil && model.filter.isEmpty
        let spots = isEmptyPlace ? SpotsMapKitStrings.Discover.noSpots : SpotsMapKitStrings.Discover.spots(count)
        text.append(NSAttributedString(string: " · \(spots)", attributes: [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.secondaryLabel,
        ]))
        UIView.transition(with: cityLabel, duration: animated ? 0.3 : 0, options: .transitionCrossDissolve) {
            self.cityLabel.attributedText = text
        }
        cityLabel.accessibilityLabel = "\(heading), \(spots)"
    }

    private func showCity(animated: Bool) {
        let rows = model.citySpots
        showCityLabel(count: rows.count, animated: animated)
        shownSpots = Dictionary(rows.map { ($0.id, $0.spot) }) { first, _ in first }
        shownPlaces = [:]
        let showsCards = model.listedCollection == nil && !model.collectionCards.isEmpty
        let items: [Item] = (showsCards ? [.collections] : []) + rows.map { .spot($0.id, .city) }
        let sections: [Section] = (showsCards ? [.collections] : []) + (rows.isEmpty ? [] : [.city])
        apply(items, sections: sections, animated: animated)
        if model.listedCollection != nil, rows.isEmpty {
            showEmpty(
                title: SpotsMapKitStrings.Collections.Empty.title,
                detail: SpotsMapKitStrings.Collections.Empty.detail,
                button: SpotsMapKitStrings.Collections.Empty.showAll,
            ) { [weak self] in self?.model.clearCollection() }
        } else if model.listedCollection != nil {
            emptyView.isHidden = true
        } else if let firstLoad = model.firstLoad {
            showFirstLoad(firstLoad)
        } else if model.place == nil {
            showEmpty(
                title: SpotsMapKitStrings.Discover.NoCity.title,
                detail: SpotsMapKitStrings.Discover.NoCity.detail,
                button: SpotsMapKitStrings.Discover.Empty.search,
            ) { [weak self] in self?.textField.becomeFirstResponder() }
        } else if rows.isEmpty, !model.filter.isEmpty {
            showEmpty(
                title: SpotsMapKitStrings.Discover.NoMatches.title,
                detail: SpotsMapKitStrings.Discover.NoMatches.detail,
                button: SpotsMapKitStrings.Discover.NoMatches.clear,
            ) { [weak self] in self?.model.setFilter(SpotFilter()) }
        } else {
            emptyView.isHidden = true
        }
    }

    private func showSearch(_ content: SpotSearchModel.Content) {
        emptyView.isHidden = true
        var items = [Item]()
        var sections = [Section]()
        shownSpots = [:]
        shownPlaces = [:]
        func add(_ spots: [SpotIndex], to section: Section) {
            guard !spots.isEmpty else {
                return
            }
            sections.append(section)
            for spot in spots {
                shownSpots[spot.id] = spot
                items.append(.spot(spot.id, section))
            }
        }
        switch content {
        case .browsing(let recent, let nearby):
            add(recent, to: .recent)
            add(nearby, to: .nearby)

        case .results(let spots, let places):
            add(spots, to: .spots)
            if !places.isEmpty {
                sections.append(.places)
                for place in places {
                    shownPlaces[place.id] = place
                    items.append(.place(place.id))
                }
            }
        }
        apply(items, sections: sections, animated: false)
    }

    private func showFirstLoad(_ firstLoad: SpotsMapModel.FirstLoad) {
        defer { shownFirstLoad = firstLoad }
        switch firstLoad {
        case .loading:
            var configuration = UIContentUnavailableConfiguration.loading()
            configuration.text = SpotsMapKitStrings.Discover.loading
            emptyView.configuration = configuration
            emptyView.isHidden = false

        case .failed:
            if shownFirstLoad != .failed {
                ToastView.showFailure(SpotsMapKitStrings.Discover.Failed.title)
            }
            showEmpty(
                title: SpotsMapKitStrings.Discover.Failed.title,
                detail: SpotsMapKitStrings.Discover.Failed.detail,
                button: SpotsMapKitStrings.Discover.Failed.retry,
            ) { [weak self] in self?.model.retrySync() }
        }
    }

    private func showEmpty(title: String, detail: String, button: String, action: @escaping () -> Void) {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "map")
        configuration.text = title
        configuration.secondaryText = detail
        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = button
        buttonConfiguration.cornerStyle = .capsule
        configuration.button = buttonConfiguration
        configuration.buttonProperties.primaryAction = UIAction { _ in action() }
        emptyView.configuration = configuration
        emptyView.isHidden = false
        view.setNeedsLayout()
    }

    private func apply(_ items: [Item], sections: [Section], animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections(sections)
        for item in items {
            switch item {
            case .collections: snapshot.appendItems([item], toSection: .collections)
            case .spot(_, let section): snapshot.appendItems([item], toSection: section)
            case .place: snapshot.appendItems([item], toSection: .places)
            }
        }
        let rows = Dictionary(items.compactMap { item in row(for: item).map { (item, $0) } }) { first, _ in first }
        snapshot.reconfigureItems(items.filter { item in shownRows[item].map { $0 != rows[item] } ?? false })
        shownRows = rows
        dataSource.apply(snapshot, animatingDifferences: animated)
    }

    private func row(for item: Item) -> Row? {
        switch item {
        case .collections:
            .collections(model.collectionCards)

        case .spot(let id, let section):
            shownSpots[id].map { .spot($0, city: section == .city ? nil : model.cityName(for: $0)) }

        case .place(let id):
            shownPlaces[id].map { .place(title: $0.title, subtitle: $0.subtitle, isResolving: id == resolvingPlaceID) }
        }
    }

    private func makeLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout { [weak self] index, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .plain)
            configuration.backgroundColor = .clear
            configuration.showsSeparators = false
            let section = self?.dataSource.sectionIdentifier(for: index)
            configuration.headerMode = section == nil ? .none : .supplementary
            configuration.headerTopPadding = 8
            let list = NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
            // Headers scroll away with their rows; a plain list pins them by default.
            for header in list.boundarySupplementaryItems {
                header.pinToVisibleBounds = false
            }
            return list
        }
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, Item> {
        let cards = UICollectionView.CellRegistration<CollectionCardsCell, Item> { [weak self] cell, _, _ in
            guard let self else {
                return
            }
            cell.show(model.collectionCards)
            cell.onPick = { [weak self] id in self?.model.show(collectionID: id) }
            cell.menu = { [weak self] id in self?.cardMenu(for: id) }
        }
        let cell = UICollectionView.CellRegistration<SearchResultCell, Item> { [weak self] cell, _, item in
            guard let self else {
                return
            }
            cell.accessories = []
            switch item {
            case .collections:
                break

            case .spot(let id, .city):
                if let spot = shownSpots[id] {
                    cell.show(spot, detail: Self.detail(for: spot))
                }

            case .spot(let id, _):
                if let spot = shownSpots[id] {
                    cell.show(spot, city: model.cityName(for: spot))
                }

            case .place(let id):
                if let place = shownPlaces[id] {
                    cell.show(placeTitle: place.title, subtitle: place.subtitle)
                }
                if id == resolvingPlaceID {
                    cell.accessories = [.spinner()]
                }
            }
        }
        let header = UICollectionView.SupplementaryRegistration<CardListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let self, let section = dataSource.sectionIdentifier(for: indexPath.section) else {
                return
            }
            var content = UIListContentConfiguration.header()
            content.text =
                switch section {
                case .collections: SpotsMapKitStrings.Collections.header
                case .recent: SpotsMapKitStrings.Search.Section.recent
                case .nearby: SpotsMapKitStrings.Search.Section.nearby
                case .spots, .city: SpotsMapKitStrings.Search.Section.spots
                case .places: SpotsMapKitStrings.Search.Section.places
                }
            // Capped so a long word ("Collections") still fits beside See All instead of breaking.
            content.textProperties.font = UIFontMetrics(forTextStyle: .title3)
                .scaledFont(for: .systemFont(ofSize: 20, weight: .semibold), maximumPointSize: 32)
            content.textProperties.color = .label
            content.textProperties.transform = .none
            header.contentConfiguration = content
            var background = UIBackgroundConfiguration.listHeader()
            background.backgroundColor = .clear
            header.backgroundConfiguration = background
            header.accessories =
                switch section {
                case .recent: [.customView(configuration: clearRecentAccessory())]
                case .collections: [.customView(configuration: seeAllAccessory())]
                default: []
                }
        }
        let dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) {
            collectionView, indexPath, item in
            switch item {
            case .collections: collectionView.dequeueConfiguredReusableCell(using: cards, for: indexPath, item: item)
            case .spot, .place: collectionView.dequeueConfiguredReusableCell(using: cell, for: indexPath, item: item)
            }
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: header, for: indexPath)
        }
        return dataSource
    }

    private func seeAllAccessory() -> UICellAccessory.CustomViewConfiguration {
        headerTextAccessory(SpotsMapKitStrings.Collections.seeAll) { [weak self] in
            self?.present(Container.shared.discoverCollectionsScreen())
        }
    }

    private func headerTextAccessory(_ title: String, action: @escaping () -> Void) -> UICellAccessory.CustomViewConfiguration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = title
        configuration.contentInsets = .zero
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: 17), maximumPointSize: 28)
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.addAction(UIAction { _ in action() }, for: .primaryActionTriggered)
        button.sizeToFit()
        // A tap target's height; the title stays centred.
        button.frame.size.height = max(button.frame.height, 44)
        return .init(customView: button, placement: .trailing())
    }

    private func cardMenu(for id: String) -> UIMenu {
        UIMenu(children: [
            UIAction(title: SpotsMapKitStrings.Collections.Card.showOnMap, image: UIImage(systemName: "map")) { [weak self] _ in
                self?.model.show(collectionID: id)
                self?.revealMap()
            },
            UIAction(
                title: SpotsMapKitStrings.Collections.Card.open,
                image: UIImage(systemName: "rectangle.stack"),
            ) { [weak self] _ in
                self?.present(Container.shared.discoverCollectionScreen(id))
            },
        ])
    }

    private func openListedCollection() {
        if let id = model.listedCollection?.id {
            present(Container.shared.discoverCollectionScreen(id))
        }
    }

    private func present(_ screen: UIViewController?) {
        guard let screen else {
            return
        }
        screen.sheetPresentationController?.placeBesideMap()
        present(screen, animated: true)
    }

    private func clearRecentAccessory() -> UICellAccessory.CustomViewConfiguration {
        let accessory = headerTextAccessory(SpotsMapKitStrings.Search.clearRecent) { [weak self] in self?.search?.clearRecent() }
        accessory.customView.accessibilityLabel = SpotsMapKitStrings.Search.A11y.clearRecent
        return accessory
    }

    @objc
    private func keyboardWillChange(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let window = view.window else {
            return
        }
        let keyboard = view.convert(window.convert(frame, from: window.screen.coordinateSpace), from: window)
        keyboardOverlap = max(0, view.bounds.maxY - keyboard.minY)
        view.setNeedsLayout()
    }

    @objc
    private func differentiateWithoutColorChanged() {
        updateChips()
    }
}

// MARK: Actions

extension DiscoverSheetController {
    @objc
    private func headerPanned(_ pan: UIPanGestureRecognizer) {
        let y = pan.translation(in: view.superview).y
        switch pan.state {
        case .began:
            stopSettling()
            headerDragY = y

        case .changed:
            guard let last = headerDragY else {
                return
            }
            headerDragY = y
            drag(to: view.frame.minY + y - last)

        case .ended, .cancelled, .failed:
            guard headerDragY != nil else {
                return
            }
            headerDragY = nil
            settle(releasedAt: pan.state == .ended ? pan.velocity(in: view.superview).y : 0)

        default:
            break
        }
    }
}

// MARK: ScrollRegulator

extension DiscoverSheetController: ScrollRegulator {
    func scrollView(_ scrollView: UIScrollView,
                    regulating proposed: CGPoint,
                    from previous: CGPoint,
                    pan: UIPanGestureRecognizer) -> CGPoint {
        if pan.state == .began {
            stopSettling()
            listDrag = ListDrag()
        }
        guard var drag = listDrag else {
            return proposed
        }
        defer { listDrag = drag }
        drag.lastMovedPanel = false
        let delta = proposed.y - previous.y
        let top = view.frame.minY
        let highest = self.top(for: .large)
        let listTop = -scrollView.adjustedContentInset.top
        if delta > 0, top > highest + 0.5 {
            let rise = min(delta, top - highest)
            self.drag(to: top - rise)
            drag.movedPanel = true
            drag.lastMovedPanel = true
            return CGPoint(x: proposed.x, y: max(previous.y, listTop) + delta - rise)
        }
        if delta < 0, previous.y <= listTop + 0.5 || top > highest + 0.5 {
            self.drag(to: top - delta)
            drag.movedPanel = true
            drag.lastMovedPanel = true
            return CGPoint(x: proposed.x, y: max(previous.y, listTop))
        }
        return proposed
    }

    func scrollView(_: UIScrollView, shouldDecelerate decelerates: Bool) -> Bool {
        guard let drag = listDrag else {
            return decelerates
        }
        listDrag = nil
        guard drag.movedPanel else {
            return decelerates
        }
        settle(releasedAt: collectionView.panGestureRecognizer.velocity(in: view.superview).y)
        return drag.lastMovedPanel ? false : decelerates
    }
}

// MARK: UIGestureRecognizerDelegate

extension DiscoverSheetController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        touch.location(in: view).y < listTop && touch.view?.isDescendant(of: trailingButton) != true
    }

    func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
        guard let pan = recognizer as? UIPanGestureRecognizer else {
            return true
        }
        let velocity = pan.velocity(in: view)
        return abs(velocity.y) >= abs(velocity.x)
    }
}

// MARK: UITextFieldDelegate

extension DiscoverSheetController: UITextFieldDelegate {
    func textFieldDidBeginEditing(_: UITextField) {
        openSearch()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}

// MARK: UICollectionViewDelegate

extension DiscoverSheetController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        switch dataSource.itemIdentifier(for: indexPath) {
        case .collections:
            break

        case .spot(let id, let section):
            guard let spot = shownSpots[id] else {
                return
            }
            if section != .city {
                closeSearch(settlingAt: detentBeforeSearch)
            }
            onPickSpot?(spot, Self.source(of: section))

        case .place(let id):
            guard let place = shownPlaces[id], let search else {
                return
            }
            placeLookup?.cancel()
            placeLookup = Task { [weak self] in
                let found = await search.resolve(place)
                guard let self, !Task.isCancelled else {
                    return
                }
                guard let found else {
                    ToastView.showFailure(SpotsMapKitStrings.Search.Place.failed)
                    return
                }
                closeSearch(settlingAt: .collapsed)
                onPickPlace?(found.region, found.mark)
            }

        case nil:
            break
        }
    }
}

// MARK: - Section + Source

extension DiscoverSheetController {
    private static func source(of section: Section) -> AnalyticsEvent.SpotSource {
        switch section {
        case .city, .collections: .list
        case .recent: .recent
        case .nearby: .nearby
        case .spots, .places: .search
        }
    }
}
