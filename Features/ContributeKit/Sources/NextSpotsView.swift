import ComponentKit
import PinLayout
import UIKit

/// Spot Submitted's next ask: one line in the magazine voice and a row for each of the nearest spots without a photo.
final class NextSpotsView: UIView {

    // MARK: Static Properties

    private static let rowSpacing: CGFloat = 8

    // MARK: Properties

    var onOpen: ((String) -> Void)?
    var onAddPhotos: ((String) -> Void)?

    private let headlineLabel = Label()
    private var rows = [NextSpotRow]()
    private var spots = [NearYou.Spot]()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.numberOfLines = 0
        headlineLabel.accessibilityTraits = .header
        addSubview(headlineLabel)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        _ = layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    func show(_ spots: [NearYou.Spot]) {
        guard spots != self.spots else {
            return
        }
        self.spots = spots
        headlineLabel.text = spots.count == 1
            ? ContributeKitStrings.SpotSubmitted.NextSpots.one
            : ContributeKitStrings.SpotSubmitted.NextSpots.two
        for row in rows {
            row.removeFromSuperview()
        }
        rows = spots.map { spot in
            let row = NextSpotRow(spot: spot)
            row.addAction(UIAction { [weak self] _ in self?.onOpen?(spot.id) }, for: .touchUpInside)
            row.onAddPhotos = { [weak self] in self?.onAddPhotos?(spot.id) }
            addSubview(row)
            return row
        }
        setNeedsLayout()
    }

    private func layout(width: CGFloat) -> CGFloat {
        headlineLabel.pin
            .top()
            .start()
            .width(width)
            .sizeToFit(.width)
        var bottom = headlineLabel.frame.maxY + 4
        for row in rows {
            row.pin
                .top(bottom + Self.rowSpacing)
                .start()
                .width(width)
                .height(row.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height)
            bottom = row.frame.maxY
        }
        return bottom
    }
}
