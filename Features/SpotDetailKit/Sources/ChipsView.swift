import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

final class ChipsView: UIView {

    // MARK: Static Properties

    private static let spacing: CGFloat = 8

    // MARK: Computed Properties

    private var chipHeight: CGFloat {
        max(30, ceil(UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: traitCollection).lineHeight) + 12)
    }

    // MARK: Properties

    private var chips = [(pill: UIView, label: Label)]()

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layoutChips(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layoutChips(width: size.width, apply: false))
    }

    // MARK: Functions

    func show(_ titles: [String]) {
        for chip in chips {
            chip.pill.removeFromSuperview()
        }
        chips = titles.map { title in
            let label = Label()
            label.text = SpotDetailKitStrings.Spot.obstacle(SpotObstacle.title(of: title))
            label.font = .preferredFont(forTextStyle: .subheadline)
            label.adjustsFontForContentSizeCategory = true
            label.textAlignment = .center
            // Its own view, not the label's background: a label paints that into its text, which glass redraws.
            let pill = UIView()
            pill.backgroundColor = .sheetTertiaryFill
            pill.layer.cornerCurve = .continuous
            pill.addSubview(label)
            addSubview(pill)
            return (pill, label)
        }
        setNeedsLayout()
    }

    @discardableResult
    private func layoutChips(width: CGFloat, apply: Bool = true) -> CGFloat {
        let height = chipHeight
        let sizes = chips.map { CGSize(width: min(width, ceil($0.label.intrinsicContentSize.width) + 24), height: height) }
        let frames = FlowLayout.frames(for: sizes, width: width, spacing: Self.spacing)
        if apply {
            for (chip, frame) in zip(chips, frames) {
                chip.pill.pin
                    .top(frame.minY)
                    .start(frame.minX)
                    .size(frame.size)
                chip.pill.layer.cornerRadius = height / 2
                chip.label.pin
                    .all()
            }
        }
        return frames.map(\.maxY).max() ?? 0
    }
}
