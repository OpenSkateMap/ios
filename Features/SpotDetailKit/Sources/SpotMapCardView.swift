import ComponentKit
import MapKit
import PinLayout
import UIKit

final class SpotMapCardView: UIControl {

    // MARK: Types

    private struct Snapshot: Equatable {
        let size: CGSize
        let style: UIUserInterfaceStyle
        let latitude: Double
        let longitude: Double
    }

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0 : 0.2) {
                self.imageView.alpha = self.isHighlighted ? 0.6 : 1
            }
        }
    }

    // MARK: Properties

    private let imageView = UIImageView()
    private var coordinate: CLLocationCoordinate2D?
    private var rendered: Snapshot?
    private var requested: Snapshot?
    private var snapshotter: MKMapSnapshotter?
    private var snapshotting: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .sheetSecondaryFill
        clipsToBounds = true
        layer.cornerRadius = SpotPageView.cardCornerRadius
        layer.cornerCurve = .continuous
        imageView.contentMode = .scaleAspectFill
        addSubview(imageView)
        isAccessibilityElement = true
        accessibilityLabel = SpotDetailKitStrings.Spot.Map.A11y.label
        accessibilityTraits = .button
        accessibilityHint = SpotDetailKitStrings.Spot.Map.A11y.hint
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        snapshotting?.cancel()
        snapshotter?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        imageView.pin
            .all()
        snapshotIfNeeded()
    }

    // MARK: Functions

    func show(_ coordinate: CLLocationCoordinate2D) {
        if self.coordinate?.latitude != coordinate.latitude || self.coordinate?.longitude != coordinate.longitude {
            imageView.image = nil
        }
        self.coordinate = coordinate
        setNeedsLayout()
    }

    private func snapshotIfNeeded() {
        guard let coordinate, bounds.width > 0, bounds.height > 0 else {
            return
        }
        let wanted = Snapshot(
            size: bounds.size,
            style: traitCollection.userInterfaceStyle,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
        )
        guard wanted != rendered, wanted != requested else {
            return
        }
        requested = wanted
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 500, longitudinalMeters: 500)
        options.size = bounds.size
        options.traitCollection = traitCollection
        options.preferredConfiguration = MKStandardMapConfiguration(emphasisStyle: .muted)
        let snapshotter = MKMapSnapshotter(options: options)
        let traits = traitCollection
        self.snapshotter?.cancel()
        self.snapshotter = snapshotter
        snapshotting?.cancel()
        snapshotting = Task { [weak self] in
            let snapshot = try? await snapshotter.start()
            guard let self, !Task.isCancelled else {
                return
            }
            // A failed one (offline, throttled) is asked for again at the next layout.
            requested = nil
            guard let snapshot else {
                return
            }
            rendered = wanted
            imageView.image = snapshot.image.resolved(with: traits)
        }
    }
}
