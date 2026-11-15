import ComponentKit
import MapKit
import PinLayout
import SpotModelKit
import UIKit

final class SpotClusterAnnotationView: MKAnnotationView {

    // MARK: Static Properties

    static let reuseIdentifier = "cluster"

    private static let fan: [(angle: CGFloat, offset: CGFloat)] = [(-0.16, -7), (0.12, 7), (0, 0)]

    private static let inseparableSpan: CLLocationDistance = 30

    // MARK: Properties

    var onPick: ((String) -> Void)?

    private let cards = (0..<3).map { _ in PinCardView() }
    private let label = PinArt.titleLabel()
    private let listButton = UIButton(type: .custom)

    // MARK: Lifecycle

    override init(annotation: any MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)

        frame = CGRect(x: 0, y: 0, width: PinArt.side + 16, height: PinArt.side)
        centerOffset = CGPoint(x: 0, y: -PinArt.side / 2)
        collisionMode = .rectangle
        displayPriority = .defaultHigh
        for card in cards {
            addSubview(card)
        }
        addSubview(label)
        listButton.showsMenuAsPrimaryAction = true
        listButton.isHidden = true
        addSubview(listButton)
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

        // MKAnnotationView's prepareForReuse() puts the display priority back to its default, .required.
        displayPriority = .defaultHigh
        for card in cards {
            card.reset()
        }
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()

        configure()
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        for (card, fan) in zip(cards, Self.fan) {
            card.transform = .identity
            card.pin
                .top()
                .hCenter(fan.offset)
                .size(PinArt.side)
            card.transform = CGAffineTransform(rotationAngle: fan.angle)
        }
        label.pin
            .below(of: cards[2], aligned: .center)
            .width(140)
            .marginTop(6)
            .sizeToFit(.width)
        listButton.pin
            .all()
    }

    // MARK: Static Functions

    static func isInseparable(_ cluster: MKClusterAnnotation) -> Bool {
        let rect = cluster.memberAnnotations.reduce(MKMapRect.null) { rect, member in
            rect.union(MKMapRect(origin: MKMapPoint(member.coordinate), size: MKMapSize(width: 0, height: 0)))
        }
        let span = max(rect.width, rect.height) / MKMapPointsPerMeterAtLatitude(cluster.coordinate.latitude)
        return span < inseparableSpan
    }

    // MARK: Functions

    /// MapKit hands a cluster view new members without saying so; this re-reads them each time.
    func configure() {
        guard let cluster = annotation as? MKClusterAnnotation else {
            return
        }
        let members = cluster.memberAnnotations
            .compactMap { ($0 as? SpotAnnotation)?.spot }
            .sorted { $0.version > $1.version }
        let shown = Array(members.prefix(cards.count).reversed())
        for (index, card) in cards.enumerated() {
            let offset = index - (cards.count - shown.count)
            card.isHidden = offset < 0
            if offset >= 0 {
                card.show(shown[offset])
            }
        }
        let others = members.count - 1
        let title = members.first?.title ?? ""
        label.attributedText = PinArt.title(
            others > 0 ? SpotsMapKitStrings.Cluster.title(title, others) : title,
            traits: traitCollection,
        )
        accessibilityLabel = SpotsMapKitStrings.Cluster.A11y.label(members.count, title)
        accessibilityUserInputLabels = [title]
        let inseparable = Self.isInseparable(cluster)
        listButton.isHidden = !inseparable
        listButton.menu = inseparable ? list(members) : nil
        isAccessibilityElement = !inseparable
        accessibilityHint = SpotsMapKitStrings.Cluster.A11y.zoomHint
        listButton.accessibilityLabel = accessibilityLabel
        listButton.accessibilityUserInputLabels = [title]
        listButton.accessibilityHint = SpotsMapKitStrings.Cluster.A11y.listHint
        setNeedsLayout()
    }

    private func list(_ members: [SpotIndex]) -> UIMenu {
        UIMenu(title: SpotsMapKitStrings.Cluster.menuTitle(members.count), children: members.map { spot in
            UIAction(
                title: spot.title,
                subtitle: spot.kind.title,
                image: UIImage(systemName: spot.kind.symbolName),
            ) { [weak self] _ in
                self?.onPick?(spot.id)
            }
        })
    }
}
