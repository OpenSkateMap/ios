import ComponentKit
import FactoryKit
import LocationKit
import MapKit
import PinLayout
import UIKit

// MARK: - AdjustPinViewController

final class AdjustPinViewController: UIViewController {

    // MARK: Properties

    @Injected(\.locationManager) private var location

    private let start: CLLocationCoordinate2D?
    private let onDone: (CLLocationCoordinate2D) -> Void
    private let mapView = MKMapView()
    private let pinView = CenterPinView()
    private let hintLabel = InsetLabel()
    private let locateButton = UIButton(configuration: .glass())
    private var locating: Task<Void, Never>?

    // MARK: Lifecycle

    init(start: CLLocationCoordinate2D?, onDone: @escaping (CLLocationCoordinate2D) -> Void) {
        self.start = start
        self.onDone = onDone
        super.init(nibName: nil, bundle: nil)
        title = start == nil ? ContributeKitStrings.AdjustPin.dropTitle : ContributeKitStrings.AdjustPin.title
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        locating?.cancel()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavigationItems()
        setupMap()
        setupViews()
        setupActions()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        mapView.pin
            .all()
        pinView.placeTip(at: CGPoint(x: mapView.frame.midX, y: mapView.frame.midY))
        hintLabel.pin
            .top(view.pin.safeArea.top + 12)
            .hCenter()
            .width(min(360, view.bounds.width - 32))
            .sizeToFit(.width)
        locateButton.pin
            .bottom(view.pin.safeArea.bottom + 16)
            .end(view.pin.layoutMargins)
            .size(48)
        mapView.layoutMargins = UIEdgeInsets(top: 0, left: 7, bottom: view.safeAreaInsets.bottom + 10, right: 7)
    }

    // MARK: Static Functions

    private static func startRegion(around coordinate: CLLocationCoordinate2D?) -> MKCoordinateRegion {
        guard let coordinate else {
            return .lastMap()
        }
        return MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004))
    }

    // MARK: Functions

    private func setupNavigationItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) },
        )
        let done = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in self?.done() })
        done.style = .prominent
        navigationItem.rightBarButtonItem = done
    }

    private func setupMap() {
        mapView.preferredConfiguration = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        mapView.showsUserLocation = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.setRegion(Self.startRegion(around: start), animated: false)
        mapView.delegate = self
    }

    private func setupViews() {
        view.backgroundColor = .systemBackground
        hintLabel.text = ContributeKitStrings.AdjustPin.hint
        hintLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.backgroundColor = .systemBackground.withAlphaComponent(0.9)
        hintLabel.layer.cornerRadius = 14
        hintLabel.layer.cornerCurve = .continuous
        hintLabel.clipsToBounds = true
        locateButton.configuration?.image = UIImage(systemName: "location.fill")
        locateButton.configuration?.cornerStyle = .capsule
        locateButton.accessibilityLabel = ContributeKitStrings.AdjustPin.A11y.locate
        for subview in [mapView, pinView, hintLabel, locateButton] {
            view.addSubview(subview)
        }
    }

    private func setupActions() {
        locateButton.addAction(UIAction { [weak self] _ in self?.locate() }, for: .primaryActionTriggered)
    }

    private func done() {
        onDone(mapView.centerCoordinate)
        dismiss(animated: true)
    }

    private func locate() {
        locating?.cancel()
        locateButton.configuration?.showsActivityIndicator = true
        locating = Task { [location, weak self] in
            do {
                let coordinate = try await location.currentLocation()
                guard !Task.isCancelled, let self else {
                    return
                }
                locateButton.configuration?.showsActivityIndicator = false
                mapView.setRegion(
                    MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)),
                    animated: !UIAccessibility.isReduceMotionEnabled,
                )
            } catch let error as LocationError {
                guard !Task.isCancelled, let self else {
                    return
                }
                locateButton.configuration?.showsActivityIndicator = false
                error.show(from: self)
            } catch {
                // Cancelled by a newer tap.
            }
        }
    }
}

// MARK: MKMapViewDelegate

extension AdjustPinViewController: MKMapViewDelegate {
    func mapView(_: MKMapView, regionWillChangeAnimated _: Bool) {
        pinView.setLifted(true)
    }

    func mapView(_: MKMapView, regionDidChangeAnimated _: Bool) {
        pinView.setLifted(false)
    }
}
