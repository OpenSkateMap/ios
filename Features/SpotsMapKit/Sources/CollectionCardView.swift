import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class CollectionCardView: UIControl {

    // MARK: Static Properties

    private static let standardSide: CGFloat = 132
    private static let widestSide: CGFloat = 264

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.7 : 1 }
    }

    // MARK: Computed Properties

    private var side: CGFloat {
        guard traitCollection.preferredContentSizeCategory.isAccessibilityCategory else {
            return Self.standardSide
        }
        let scaled = UIFontMetrics(forTextStyle: .subheadline).scaledValue(
            for: Self.standardSide,
            compatibleWith: traitCollection,
        )
        return min(scaled, Self.widestSide)
    }

    // MARK: Properties

    private let artwork = CollectionArtworkView()
    private let nameLabel = Label()
    private let countLabel = Label()
    private let loader = PhotoLoader()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        artwork.pin
            .top()
            .horizontally()
            .height(side)
        nameLabel.pin
            .below(of: artwork)
            .horizontally()
            .marginTop(8)
            .sizeToFit(.width)
        countLabel.pin
            .below(of: nameLabel)
            .horizontally()
            .marginTop(1)
            .sizeToFit(.width)
    }

    override func sizeThatFits(_: CGSize) -> CGSize {
        let side = side
        let fitting = CGSize(width: side, height: .greatestFiniteMagnitude)
        return CGSize(
            width: side,
            height: side + 8 + nameLabel.sizeThatFits(fitting).height + 1 + countLabel.sizeThatFits(fitting).height,
        )
    }

    // MARK: Functions

    func show(_ card: CollectionCard, scale: CGFloat) {
        let collection = card.collection
        let look = collection.look
        let name = collection.kind.title(named: collection.name)
        let count = SpotsMapKitStrings.Discover.spots(card.spotCount)
        nameLabel.text = name
        countLabel.text = count
        accessibilityLabel = SpotsMapKitStrings.Collections.Card.a11y(name, count)
        accessibilityUserInputLabels = [name]
        let key = look.pictureKey(cover: collection.coverKey)
        let thumbhash = look.pictureThumbhash(cover: collection.coverThumbhash)
        guard key != nil || thumbhash != nil else {
            loader.cancel()
            artwork.content = .look(look, symbol: collection.kind.pictureSymbol)
            return
        }
        artwork.content = .photo
        loader.show(key: key, thumbhash: thumbhash, size: .card, scale: scale, in: artwork.photoView)
        setNeedsLayout()
    }

    private func setupViews() {
        artwork.layer.cornerRadius = 12
        artwork.layer.cornerCurve = .continuous
        nameLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        nameLabel.adjustsFontForContentSizeCategory = true
        nameLabel.linesAtAccessibilitySizes = 0
        countLabel.font = .preferredFont(forTextStyle: .footnote)
        countLabel.adjustsFontForContentSizeCategory = true
        countLabel.linesAtAccessibilitySizes = 0
        countLabel.textColor = .secondaryLabel
        isAccessibilityElement = true
        accessibilityTraits = .button
        for subview in [artwork, nameLabel, countLabel] {
            subview.isUserInteractionEnabled = false
            addSubview(subview)
        }
    }
}
