import ComponentKit
import PinLayout
import UIKit

/// The spot's name with Directions and More, shown once the page scrolls past the title.
final class SpotTitleBarView: UIView {

    // MARK: Static Properties

    static let top: CGFloat = 14
    static let buttonSide: CGFloat = 44

    // MARK: Computed Properties

    var title: String? {
        get { titleLabel.text }
        set {
            titleLabel.text = newValue
            setNeedsLayout()
        }
    }

    // MARK: Properties

    let directions = UIButton(configuration: .glassIcon("arrow.trianglehead.turn.up.right.diamond.fill", textStyle: .body))
    let more = UIButton(configuration: .glassIcon("ellipsis", textStyle: .body))

    private let titleLabel = Label()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.accessibilityTraits = .header
        directions.accessibilityLabel = SpotDetailKitStrings.Spot.Actions.directions
        directions.accessibilityHint = SpotDetailKitStrings.Spot.Actions.A11y.directionsHint
        more.accessibilityLabel = SpotDetailKitStrings.Spot.Actions.more
        for button in [directions, more] {
            button.showsMenuAsPrimaryAction = true
            addSubview(button)
        }
        addSubview(titleLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        more.pin
            .vCenter()
            .end(layoutMargins)
            .size(Self.buttonSide)
        directions.pin
            .before(of: more, aligned: .center)
            .size(Self.buttonSide)
            .marginEnd(8)
        titleLabel.pin
            .vCenter()
            .start(layoutMargins)
            .end(to: directions.edge.start)
            .marginEnd(12)
            .sizeToFit(.width)
    }
}
