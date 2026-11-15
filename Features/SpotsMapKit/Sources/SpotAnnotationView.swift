import MapKit
import PinLayout
import SpotModelKit
import UIKit

final class SpotAnnotationView: MKAnnotationView {

    // MARK: Static Properties

    static let reuseIdentifier = "spot"
    /// Never nil: MapKit crashes looking up cluster views for a nil id.
    static let clusterID = "spots"

    private static let selectedScale = CGAffineTransform(scaleX: 1.2, y: 1.2)

    private static let lockImage: UIImage = {
        let side: CGFloat = 18
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            UIColor.black.withAlphaComponent(0.78).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: side, height: side))
            let glyph = UIImage(
                systemName: "lock.fill",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold),
            )?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            if let glyph {
                glyph.draw(at: CGPoint(x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2))
            }
        }
    }()

    // MARK: Properties

    var showsTitle = false {
        didSet {
            titleLabel.isHidden = !showsTitle
        }
    }

    private let card = PinCardView()
    private let titleLabel = PinArt.titleLabel()
    private let lockBadge = UIImageView(image: SpotAnnotationView.lockImage)

    // MARK: Lifecycle

    override init(annotation: any MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        frame = CGRect(x: 0, y: 0, width: PinArt.side, height: PinArt.side)
        centerOffset = CGPoint(x: 0, y: -PinArt.side / 2)
        collisionMode = .rectangle
        joinClusters()
        titleLabel.isHidden = true
        lockBadge.isHidden = true
        addSubview(card)
        addSubview(lockBadge)
        addSubview(titleLabel)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: Self, _) in
            view.configure()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func prepareForReuse() {
        super.prepareForReuse()

        // MKAnnotationView's prepareForReuse() puts the cluster id and display priority back to their defaults.
        joinClusters()
        card.reset()
        card.isSelected = false
        transform = .identity
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()

        configure()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // The cluster id stays put: changing it here makes MapKit re-cluster and drop the selection the tap just made.
        guard animated else {
            card.isSelected = selected
            transform = selected ? Self.selectedScale : .identity
            return
        }
        // A swipe on the spot sheet deselects with UIKit's animations off; the pin then animates on the next turn.
        guard UIView.areAnimationsEnabled else {
            Task { @MainActor [weak self] in
                self?.animateSelection()
            }
            return
        }
        animateSelection()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        card.pin
            .all()
        lockBadge.pin
            .top(-4)
            .end(-4)
            .size(18)
        titleLabel.pin
            .below(of: card, aligned: .center)
            .width(120)
            .marginTop(4)
            .sizeToFit(.width)
    }

    // MARK: Functions

    func configure() {
        guard let annotation = annotation as? SpotAnnotation else {
            return
        }
        card.show(annotation.spot)
        titleLabel.attributedText = PinArt.title(annotation.spot.title, traits: traitCollection)
        lockBadge.isHidden = !annotation.spot.isPrivate
        accessibilityLabel = annotation.spot.isPrivate
            ? SpotsMapKitStrings.Pin.A11y.privateSpot(annotation.spot.title)
            : annotation.spot.title
        accessibilityUserInputLabels = [annotation.spot.title]
        setNeedsLayout()
    }

    private func joinClusters() {
        clusteringIdentifier = Self.clusterID
        displayPriority = .defaultHigh
    }

    private func animateSelection() {
        let selected = isSelected
        UIView.transition(with: card, duration: 0.2, options: [.transitionCrossDissolve, .allowUserInteraction]) {
            self.card.isSelected = selected
        }
        let scale = selected ? Self.selectedScale : .identity
        guard !UIAccessibility.isReduceMotionEnabled else {
            transform = scale
            return
        }
        UIView.animate(springDuration: 0.3, bounce: selected ? 0.3 : 0) {
            self.transform = scale
        }
    }

}
