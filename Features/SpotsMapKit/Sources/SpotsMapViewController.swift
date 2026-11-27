import AnalyticsKit
import ComponentKit
import FactoryKit
import ImageKit
public import MapKit
import PinLayout
public import SpotModelKit
import SpotsKit
public import UIKit

// MARK: - SpotsMapViewController

public final class SpotsMapViewController: UIViewController {

    // MARK: Static Properties

    private static let titleWidth = 6000.0
    private static let detailDemand = 100
    private static let annotationCap = 1500
    /// Locate's bottom above the cards' bottom edge: Legal's 11 pt and a gap.
    private static let locateAboveEdge: CGFloat = 24

    // MARK: Computed Properties

    public var topSheet: UIViewController? {
        guard let sheet, sheet.presentingViewController != nil else {
            return nil
        }
        return sheet
    }

    // MARK: Properties

    private let model = SpotsMapModel()
    private let spotSheet: SpotSheet
    private let mapView = MKMapView()
    private var linkToast: ToastView?
    private let locateButton = UIButton(configuration: .glass())

    private let spotEdge = SheetEdgeTracker()
    private var chromeAnimator: UIViewPropertyAnimator?
    private lazy var discover: DiscoverSheetController = {
        let discover = DiscoverSheetController(model: model)
        discover.onPickSpot = { [weak self] spot, source in self?.model.focus(on: spot, from: source) }
        discover.onPickPlace = { [weak self] region, mark in self?.model.focus(onPlace: region, mark: mark) }
        discover.onAdd = { [weak self] in self?.openNewSpot() }
        discover.onMove = { [weak self] animator in self?.followDiscover(animator) }
        return discover
    }()

    /// MapKit selects a pin only after its double-tap zoom fails (~0.5 s after lift); this selects on the tap itself.
    private lazy var pinTap: UITapGestureRecognizer = {
        let tap = UITapGestureRecognizer(target: self, action: #selector(pinTapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        tap.delegate = self
        return tap
    }()

    private let flight = GlobeFlight()
    private var isGlobe = false
    private var isMeasuring = false
    private var pendingFlight: MKMapCamera?

    private var annotations = [String: SpotAnnotation]()
    private var shownPlaceMark: MKPointAnnotation?
    private var isMapReady = false
    private var appliedCamera: MapCamera?
    private var sheet: UIViewController?
    /// Re-applying an unchanged selection would deselect the pin MapKit is selecting mid-tap.
    private var followedSpotID: String?
    private var showsTitles = false
    private var regionChangeIsUser = false
    private weak var zoomingCluster: MKClusterAnnotation?

    // MARK: Lifecycle

    public init(spotSheet: SpotSheet) {
        self.spotSheet = spotSheet
        super.init(nibName: nil, bundle: nil)
    }

    override public func viewDidLoad() {
        super.viewDidLoad()

        setupMap()
        setupViews()
        setupActions()
        setupObservers()
        model.start()
    }

    override public func updateProperties() {
        super.updateProperties()

        if isMapReady {
            apply(model.spots, queried: model.box)
            showPlaceMark(model.placeMark)
        }
        if let camera = model.camera, camera != appliedCamera {
            appliedCamera = camera
            move(to: camera)
        }
        mapView.showsUserLocation = model.showsUserLocation
        locateButton.configuration?.showsActivityIndicator = model.isLocating
        follow(model.selection.spotID)
        if let notice = model.notice {
            show(notice)
        }
        showLinkLoading(model.isOpeningLink)
        view.setNeedsLayout()
    }

    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        mapView.pin
            .all()
        discover.layout(in: view.bounds, safeArea: view.safeAreaInsets)
        layoutChrome()
    }

    override public func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard let target = pendingFlight else {
            return
        }
        pendingFlight = nil
        if let path = flightPath(to: target) {
            flight.fly(path, onScreen: true)
        } else {
            mapView.setCamera(target, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }

    override public func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        if let path = flight.path {
            flight.interrupt()
            pendingFlight = path.destination
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    /// Turning from one landscape side to the other keeps the size and the safe area, so nothing else lays out again;
    /// the card moves off the sensor housing's new side.
    override public func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate { [weak self] _ in
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        }
    }

    // MARK: Functions

    /// With `suggestingEdit`, the spot's Suggest an Edit opens over its sheet once the page has loaded.
    public func openSpot(id: String, suggestingEdit: Bool = false) {
        discover.endSearch()
        model.open(spotID: id, suggestingEdit: suggestingEdit)
    }

    public func showCollection(_ focus: CollectionFocus) {
        discover.endSearch()
        discover.revealMap()
        closeSpot { [model] in model.show(focus) }
    }

    public func closeSpot(then completion: @escaping @MainActor () -> Void) {
        model.select(nil)
        guard let sheet = topSheet else {
            return completion()
        }
        sheet.presentingViewController?.dismiss(animated: true, completion: completion)
    }

    private func setupMap() {
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        isGlobe = MapGlobeProjection.apply(to: mapView)
        // An appearance change can rebuild MapKit's configuration, flat again; the globe goes back on.
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (controller: Self, _) in
            controller.isGlobe = MapGlobeProjection.apply(to: controller.mapView)
        }
        mapView.selectableMapFeatures = []
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.insetsLayoutMarginsFromSafeArea = false
        mapView.delegate = self
        mapView.addGestureRecognizer(pinTap)
        mapView.register(SpotAnnotationView.self, forAnnotationViewWithReuseIdentifier: SpotAnnotationView.reuseIdentifier)
        mapView.register(
            SpotClusterAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: SpotClusterAnnotationView.reuseIdentifier,
        )
    }

    private func setupViews() {
        locateButton.configuration = .glassIcon("location.fill")
        locateButton.accessibilityLabel = SpotsMapKitStrings.Map.A11y.locate
        view.addSubview(mapView)
        view.addSubview(locateButton)
        addChild(discover)
        view.addSubview(discover.view)
        discover.didMove(toParent: self)
    }

    private func setupActions() {
        locateButton.addAction(UIAction { [weak self] _ in self?.model.locate() }, for: .primaryActionTriggered)
    }

    private func setupObservers() {
        flight.onFrame = { [weak self] camera in self?.mapView.camera = camera }
        flight.onArrival = { [weak self] in self?.cameraSettled() }
        spotEdge.onChange = { [weak self] motion in self?.moveChrome(motion) }
    }

    private func layoutChrome() {
        let safeArea = view.pin.safeArea
        let height = view.bounds.height
        if discover.isBesideMap {
            // The logo and Legal sit in the trailing corner under locate, clear of the cards on the leading edge, with the
            // cards' margins.
            let edges = discover.besideMapEdges
            let trailing = view.effectiveUserInterfaceLayoutDirection == .leftToRight ? edges.right : edges.left
            mapView.placeAttributionInTrailingCorner(top: safeArea.top + 4, trailing: trailing, bottom: edges.bottom)
            locateButton.pin
                .bottom(edges.bottom + Self.locateAboveEdge)
                .end(trailing)
                .size(48)
            return
        }
        var covered = max(safeArea.bottom, min(height - discover.edgeTop, (height / 2).rounded()))
        if let window = view.window, let top = spotEdge.top {
            let resting = spotSheet.lowestDetentHeight + window.safeAreaInsets.bottom
            covered = max(covered, min(window.bounds.height - top, resting))
        }
        mapView.layoutMargins = UIEdgeInsets(top: safeArea.top + 4, left: 7, bottom: covered + 10, right: 7)
        locateButton.pin
            .bottom(covered + 16)
            .end(safeArea)
            .size(48)
            .marginEnd(16)
    }

    private func moveChrome(_ motion: SheetEdgeTracker.Motion) {
        chromeAnimator?.stopAnimation(true)
        chromeAnimator = nil
        switch motion {
        case .immediate:
            coverDiscover()
            relayoutChrome()

        case .spring(let timing):
            let animator = UIViewPropertyAnimator(duration: 0.5, timingParameters: timing)
            animator.addAnimations { [weak self] in
                self?.coverDiscover()
                self?.relayoutChrome()
            }
            animator.startAnimation()
            chromeAnimator = animator
        }
    }

    private func coverDiscover() {
        var covered: CGFloat = 0
        if let window = view.window, let top = spotEdge.top {
            let resting = spotSheet.lowestDetentHeight + window.safeAreaInsets.bottom
            covered = min(max((window.bounds.height - top) / resting, 0), 1)
        }
        discover.setCovered(covered)
    }

    private func relayoutChrome() {
        layoutChrome()
        mapView.layoutIfNeeded()
    }

    private func followDiscover(_ animator: UIViewPropertyAnimator?) {
        chromeAnimator?.stopAnimation(true)
        chromeAnimator = nil
        guard let animator else {
            relayoutChrome()
            return
        }
        animator.addAnimations { [weak self] in self?.relayoutChrome() }
    }

    /// Spots stay when the map moves away: removing and re-adding clustered annotations leaves MapKit with stale clusters.
    private func apply(_ spots: [SpotIndex], queried box: CoordinateBox?) {
        var incoming = [String: SpotIndex]()
        for spot in spots {
            incoming[spot.id] = spot
        }
        let selected = model.selection.spotID
        let filter = model.effectiveFilter
        let overCap = annotations.count > Self.annotationCap
        let gone = annotations.values.filter { annotation in
            guard incoming[annotation.id] == nil, annotation.id != selected else {
                return false
            }
            guard filter.matches(annotation.spot) else {
                return true
            }
            let queried = box?
                .contains(latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude) ?? false
            return queried || overCap
        }
        if !gone.isEmpty {
            mapView.removeAnnotations(gone)
            for annotation in gone {
                annotations[annotation.id] = nil
            }
        }
        var added = [SpotAnnotation]()
        for spot in spots {
            if let annotation = annotations[spot.id] {
                guard annotation.spot.version != spot.version else {
                    continue
                }
                annotation.update(spot)
                (mapView.view(for: annotation) as? SpotAnnotationView)?.configure()
            } else {
                let annotation = SpotAnnotation(spot)
                annotations[spot.id] = annotation
                added.append(annotation)
            }
        }
        if !added.isEmpty {
            mapView.addAnnotations(added)
            if let selected, let annotation = added.first(where: { $0.id == selected }) {
                mapView.selectAnnotation(annotation, animated: true)
            }
        }
    }

    private func follow(_ spotID: String?) {
        guard spotID != followedSpotID else {
            return
        }
        followedSpotID = spotID
        model.selectionChanged(spotID)
        // A change made inside this pass doesn't schedule another; the pins may change with the selection.
        setNeedsUpdateProperties()
        guard let spotID else {
            for annotation in mapView.selectedAnnotations {
                mapView.deselectAnnotation(annotation, animated: true)
            }
            guard let sheet else {
                return
            }
            if sheet.isBeingDismissed, let transition = sheet.transitionCoordinator {
                transition.animate(alongsideTransition: nil) { [weak self] context in
                    guard let self, !context.isCancelled, self.sheet === sheet else {
                        return
                    }
                    self.sheet = nil
                    // Beside the map the logo made room for the sheet; after a swipe nothing else lays it out again.
                    UIView.animate(withDuration: 0.25) { self.relayoutChrome() }
                }
                spotEdge.dismissing()
            } else {
                self.sheet = nil
                // The sheet dismissing itself would close only a sheet it presents; its presenter closes both.
                sheet.presentingViewController?.dismiss(animated: true)
                spotEdge.dismissing()
            }
            return
        }
        if let annotation = annotations[spotID], !mapView.selectedAnnotations.contains(where: { $0 === annotation }) {
            mapView.selectAnnotation(annotation, animated: true)
        }
        presentSpotSheetIfNeeded()
    }

    private func presentSpotSheetIfNeeded() {
        guard model.selection.spotID != nil, sheet == nil, presentedViewController == nil else {
            return
        }
        let sheet = spotSheet.make(model.selection)
        self.sheet = sheet
        present(sheet, animated: true)
        spotEdge.track(sheet)
    }

    private func openNewSpot() {
        guard presentedViewController == nil, let newSpot = Container.shared.addSpotScreen() else {
            return
        }
        newSpot.sheetPresentationController?.placeBesideMap()
        present(newSpot, animated: true)
    }

    private func cameraSettled() {
        model.regionChanged(mapView.region, byUser: regionChangeIsUser)
        regionChangeIsUser = false
        updateTitles()
        reportVisibleSpots()
    }

    private func move(to request: MapCamera) {
        flight.interrupt()
        switch request.target {
        case .planet(let longitude):
            mapView.camera = GlobeCameraMath.orbitCamera(longitude: longitude)

        case .region(let region):
            switch request.move {
            case .jump:
                mapView.setRegion(mapView.regionThatFits(region), animated: false)

            case .travel:
                let target = camera(fitting: region)
                guard isGlobe, let path = flightPath(to: target) else {
                    mapView.setRegion(mapView.regionThatFits(region), animated: !UIAccessibility.isReduceMotionEnabled)
                    return
                }
                guard view.window != nil else {
                    pendingFlight = target
                    return
                }
                flight.fly(path, onScreen: true)
            }
        }
    }

    private func flightPath(to target: MKMapCamera) -> FlightPath? {
        let current = mapView.camera
        if current.centerCoordinateDistance > 1_500_000 {
            return .descent(from: current, to: target)
        }
        let distance = MKMapPoint(current.centerCoordinate).distance(to: MKMapPoint(target.centerCoordinate))
        return distance > 300_000 ? .arc(from: current, to: target) : nil
    }

    private func camera(fitting region: MKCoordinateRegion) -> MKMapCamera {
        isMeasuring = true
        defer { isMeasuring = false }
        let current = mapView.camera.copy() as? MKMapCamera ?? mapView.camera
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
        let fitted = mapView.camera.copy() as? MKMapCamera ?? mapView.camera
        mapView.camera = current
        return fitted
    }

    private func showLinkLoading(_ isOpening: Bool) {
        if isOpening, linkToast == nil {
            let toast = ToastView()
            toast.update(with: .loading(title: SpotsMapKitStrings.Map.openingSpot))
            linkToast = toast
        } else if !isOpening, let toast = linkToast {
            linkToast = nil
            toast.update(with: .hidden)
        }
    }

    private func showPlaceMark(_ mark: MKPointAnnotation?) {
        guard mark !== shownPlaceMark else {
            return
        }
        if let shownPlaceMark {
            mapView.removeAnnotation(shownPlaceMark)
        }
        shownPlaceMark = mark
        if let mark {
            mapView.addAnnotation(mark)
        }
    }

    private func show(_ notice: MapNotice) {
        model.dismissNotice()
        // Only the denied notice needs a button (Settings), which a toast can't take.
        guard notice.offersSettings else {
            let failure = ToastViewEvent.icon(predefinedIcon: .failure, title: notice.title, subtitle: notice.message)
            let toast = linkToast ?? ToastView()
            linkToast = nil
            Task { await toast.show(failure) }
            return
        }
        let alert = UIAlertController(title: notice.title, message: notice.message, preferredStyle: .alert)
        if notice.offersSettings, let settings = URL(string: UIApplication.openSettingsURLString) {
            alert.addAction(UIAlertAction(title: SpotsMapKitStrings.Map.Notice.settings, style: .default) { _ in
                UIApplication.shared.open(settings)
            })
        }
        alert.addAction(UIAlertAction(title: SpotsMapKitStrings.Map.Notice.ok, style: .cancel))
        topPresented.present(alert, animated: true)
    }

    private func reportVisibleSpots() {
        let center = MKMapPoint(mapView.centerCoordinate)
        let visible = mapView.annotations(in: mapView.visibleMapRect)
            .compactMap { $0 as? SpotAnnotation }
            .sorted { MKMapPoint($0.coordinate).distance(to: center) < MKMapPoint($1.coordinate).distance(to: center) }
            .prefix(Self.detailDemand)
        model.showing(visible.map(\.id))
    }

    private func updateTitles() {
        let metersAcross = mapView.visibleMapRect.width / MKMapPointsPerMeterAtLatitude(mapView.centerCoordinate.latitude)
        let showsTitles = metersAcross < Self.titleWidth
        guard showsTitles != self.showsTitles else {
            return
        }
        self.showsTitles = showsTitles
        for annotation in annotations.values {
            (mapView.view(for: annotation) as? SpotAnnotationView)?.showsTitle = showsTitles
        }
    }

    @objc
    private func pinTapped(_ tap: UITapGestureRecognizer) {
        guard let annotation = annotationView(at: tap.location(in: mapView))?.annotation,
              !mapView.selectedAnnotations.contains(where: { $0 === annotation }) else {
            return
        }
        mapView.selectAnnotation(annotation, animated: true)
    }

    private func annotationView(at point: CGPoint) -> MKAnnotationView? {
        var view = mapView.hitTest(point, with: nil)
        while let current = view, !(current is MKAnnotationView) {
            view = current.superview
        }
        return view as? MKAnnotationView
    }

    private func zoom(into cluster: MKClusterAnnotation) {
        var rect = cluster.memberAnnotations.reduce(MKMapRect.null) { rect, member in
            rect.union(MKMapRect(origin: MKMapPoint(member.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        let minimum = 300 * MKMapPointsPerMeterAtLatitude(cluster.coordinate.latitude)
        if rect.width < minimum || rect.height < minimum {
            rect = rect.insetBy(dx: -max(0, minimum - rect.width) / 2, dy: -max(0, minimum - rect.height) / 2)
        }
        mapView.setVisibleMapRect(
            rect,
            edgePadding: UIEdgeInsets(top: 48, left: 60, bottom: 48, right: 60),
            animated: !UIAccessibility.isReduceMotionEnabled,
        )
    }
}

// MARK: MKMapViewDelegate

extension SpotsMapViewController: MKMapViewDelegate {
    public func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
        switch annotation {
        case let cluster as MKClusterAnnotation:
            let view = mapView.dequeueReusableAnnotationView(
                withIdentifier: SpotClusterAnnotationView.reuseIdentifier,
                for: cluster,
            )
            (view as? SpotClusterAnnotationView)?.onPick = { [weak self] id in self?.model.select(id, from: .map) }
            return view

        case let spot as SpotAnnotation:
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: SpotAnnotationView.reuseIdentifier, for: spot)
            (view as? SpotAnnotationView)?.showsTitle = showsTitles
            return view

        default:
            return nil
        }
    }

    public func mapView(_: MKMapView, didAdd views: [MKAnnotationView]) {
        // Selected, MapKit's user location raises a contact photo balloon over the dot; disabled, it stays the dot,
        // and a tap on it reaches the pin beneath.
        for view in views where view.annotation is MKUserLocation {
            view.isEnabled = false
            view.isUserInteractionEnabled = false
        }
    }

    public func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
        switch annotation {
        case let cluster as MKClusterAnnotation:
            mapView.deselectAnnotation(cluster, animated: false)
            guard cluster !== zoomingCluster, !SpotClusterAnnotationView.isInseparable(cluster) else {
                return
            }
            zoomingCluster = cluster
            zoom(into: cluster)

        case let spot as SpotAnnotation:
            model.select(spot.id, from: .map)

        default:
            break
        }
    }

    public func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
        guard annotation is SpotAnnotation else {
            return
        }
        // Moving between pins deselects first; only a deselection that leaves nothing selected closes the spot.
        Task { [weak self] in
            guard let self, mapView.selectedAnnotations.isEmpty else {
                return
            }
            model.select(nil)
        }
    }

    public func mapView(_ mapView: MKMapView, regionWillChangeAnimated _: Bool) {
        guard !isMeasuring else {
            return
        }
        // MapKit doesn't say who moved the map; a gesture recognizer in flight means a person did.
        regionChangeIsUser = mapView.subviews.first?.gestureRecognizers?
            .contains { $0.state == .began || $0.state == .changed } ?? false
        if regionChangeIsUser, flight.isFlying {
            flight.interrupt()
        }
    }

    public func mapView(_: MKMapView, regionDidChangeAnimated _: Bool) {
        guard !isMeasuring, !flight.isFlying else {
            return
        }
        cameraSettled()
    }

    public func mapViewDidFinishRenderingMap(_: MKMapView, fullyRendered _: Bool) {
        // Annotations added before the first render get no views; start drawing pins only once it has happened.
        guard !isMapReady else {
            return
        }
        isMapReady = true
        setNeedsUpdateProperties()
    }
}

// MARK: UIGestureRecognizerDelegate

extension SpotsMapViewController: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        annotationView(at: touch.location(in: mapView)) != nil
    }

    public func gestureRecognizer(_: UIGestureRecognizer,
                                  shouldRecognizeSimultaneouslyWith _: UIGestureRecognizer) -> Bool {
        true
    }
}
