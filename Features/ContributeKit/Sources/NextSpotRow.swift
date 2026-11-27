import ComponentKit
import PinLayout
import SpotModelKit
import UIKit

/// A nearby spot without a photo on Spot Submitted: its kind's glyph, the name, how far and what's there, and Add Photos.
/// A tap elsewhere opens the spot on the map, as a Near You card does.
final class NextSpotRow: UIControl {

    // MARK: Static Properties

    private static let inset: CGFloat = 12
    private static let tileSide: CGFloat = 44
    private static let gap: CGFloat = 12

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            alpha = isHighlighted ? 0.7 : 1
        }
    }

    // MARK: Properties

    var onAddPhotos: (() -> Void)?

    private let tileView = UIImageView()
    private let titleLabel = Label()
    private let detailLabel = Label()
    private let addButton = UIButton(configuration: NearYouCell.addPhotosConfiguration())

    // MARK: Lifecycle

    init(spot: NearYou.Spot) {
        super.init(frame: .zero)

        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 20
        layer.cornerCurve = .continuous
        tileView.backgroundColor = spot.spot.kind.tint
        tileView.image = UIImage(systemName: spot.spot.kind.symbolName)
        tileView.tintColor = .white
        tileView.contentMode = .center
        tileView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        tileView.layer.cornerRadius = 12
        tileView.layer.cornerCurve = .continuous
        tileView.clipsToBounds = true
        tileView.isUserInteractionEnabled = false
        titleLabel.text = spot.spot.title
        titleLabel.font = .preferredFont(forTextStyle: .body, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.linesAtAccessibilitySizes = 0
        detailLabel.text = NearYouCell.detail(for: spot)
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.linesAtAccessibilitySizes = 0
        addButton.addAction(UIAction { [weak self] _ in self?.onAddPhotos?() }, for: .primaryActionTriggered)
        for view in [tileView, titleLabel, detailLabel, addButton] {
            addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = spot.spot.title
        accessibilityValue = detailLabel.text
        accessibilityUserInputLabels = [spot.spot.title]
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: ContributeKitStrings.Contribute.NearYou.addPhotos) { [weak self] _ in
                self?.onAddPhotos?()
                return true
            }
        ]
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

    /// Lays out for `width` and returns the height it takes; at accessibility sizes Add Photos goes under the text.
    private func layout(width: CGFloat) -> CGFloat {
        let inset = Self.inset
        let inner = max(width - inset * 2, 0)
        let stacks = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let fitted = addButton.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude))
        let buttonSize = CGSize(width: stacks ? inner : ceil(fitted.width), height: max(36, ceil(fitted.height)))
        let textWidth = max(inner - Self.tileSide - Self.gap - (stacks ? 0 : buttonSize.width + Self.gap), 0)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        let detailHeight = detailLabel.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height
        let textHeight = ceil(titleHeight) + 2 + ceil(detailHeight)
        let rowHeight = max(Self.tileSide, textHeight, stacks ? 0 : buttonSize.height)
        tileView.pin
            .top(inset + (stacks ? 0 : (rowHeight - Self.tileSide) / 2))
            .start(inset)
            .size(Self.tileSide)
        titleLabel.pin
            .top(inset + (rowHeight - textHeight) / 2)
            .after(of: tileView)
            .width(textWidth)
            .height(ceil(titleHeight))
            .marginStart(Self.gap)
        detailLabel.pin
            .below(of: titleLabel)
            .start(to: titleLabel.edge.start)
            .width(textWidth)
            .height(ceil(detailHeight))
            .marginTop(2)
        if stacks {
            addButton.pin
                .top(inset + rowHeight + 10)
                .start(inset)
                .size(buttonSize)
            return addButton.frame.maxY + inset
        }
        addButton.pin
            .top(inset + (rowHeight - buttonSize.height) / 2)
            .end(inset)
            .size(buttonSize)
        return inset * 2 + rowHeight
    }
}
