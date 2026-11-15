import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class SearchResultCell: CardListCell {

    // MARK: Static Properties

    private static let thumbnailSide: CGFloat = 44

    // MARK: Properties

    private let thumbnailView = UIImageView()
    private let glyphView = UIImageView()
    private let titleLabel = Label()
    private let subtitleLabel = Label()
    private let loader = PhotoLoader()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.layer.cornerRadius = 10
        thumbnailView.layer.cornerCurve = .continuous
        glyphView.contentMode = .center
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.linesAtAccessibilitySizes = 0
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.linesAtAccessibilitySizes = 0
        subtitleLabel.textColor = .secondaryLabel
        for view in [thumbnailView, glyphView, titleLabel, subtitleLabel] {
            contentView.addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        var background = UIBackgroundConfiguration.listCell().updated(for: state)
        if !state.isHighlighted, !state.isSelected {
            background.backgroundColor = .clear
        }
        backgroundConfiguration = background
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        loader.cancel()
        thumbnailView.image = nil
        thumbnailView.image = nil
        glyphView.image = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let margin = directionalLayoutMargins.leading
        thumbnailView.pin
            .vCenter()
            .start(margin)
            .size(Self.thumbnailSide)
        glyphView.pin
            .center(to: thumbnailView.anchor.center)
            .size(Self.thumbnailSide)
        let textStart = margin + Self.thumbnailSide + 14
        let width = contentView.bounds.width - textStart - directionalLayoutMargins.trailing
        titleLabel.pin
            .start(textStart)
            .width(width)
            .sizeToFit(.width)
        subtitleLabel.pin
            .start(textStart)
            .width(width)
            .sizeToFit(.width)
        let textHeight = titleLabel.frame.height + (subtitleLabel.text == nil ? 0 : subtitleLabel.frame.height + 2)
        titleLabel.pin
            .top((contentView.bounds.height - textHeight) / 2)
        subtitleLabel.pin
            .below(of: titleLabel)
            .marginTop(2)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width - Self.thumbnailSide - 14 - directionalLayoutMargins.leading -
            directionalLayoutMargins.trailing
        let title = titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let subtitle = subtitleLabel.text == nil
            ? 0
            : subtitleLabel.sizeThatFits(
                CGSize(width: width, height: .greatestFiniteMagnitude)
            ).height + 2
        return CGSize(width: size.width, height: max(Self.thumbnailSide, title + subtitle) + 16)
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = sizeThatFits(CGSize(width: attributes.size.width, height: .greatestFiniteMagnitude)).height
        return fitted
    }

    // MARK: Functions

    func show(_ spot: SpotIndex, city: String?) {
        show(spot, detail: city.map { SpotsMapKitStrings.Search.Result.subtitle(spot.kind.title, $0) } ?? spot.kind.title)
    }

    func show(_ spot: SpotIndex, detail: String) {
        titleLabel.text = spot.title
        subtitleLabel.text = detail
        accessibilityLabel = SpotsMapKitStrings.Search.Result.a11y(spot.title, detail)
        accessibilityUserInputLabels = [spot.title]
        thumbnailView.backgroundColor = spot.kind.tint
        // A place row before reuse made it a circle.
        thumbnailView.layer.cornerRadius = 10
        glyphView.tintColor = .white
        if spot.coverKey == nil, spot.coverThumbhash == nil {
            loader.cancel()
            thumbnailView.image = nil
            glyphView.image = UIImage(systemName: spot.kind.symbolName)
        } else {
            glyphView.image = nil
            let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : 3
            loader.show(key: spot.coverKey, thumbhash: spot.coverThumbhash, size: .pin, scale: scale, in: thumbnailView)
        }
        setNeedsLayout()
    }

    func show(placeTitle: String, subtitle: String) {
        titleLabel.text = placeTitle
        subtitleLabel.text = subtitle.isEmpty ? nil : subtitle
        accessibilityLabel = subtitle.isEmpty ? placeTitle : SpotsMapKitStrings.Search.Result.a11y(placeTitle, subtitle)
        accessibilityUserInputLabels = [placeTitle]
        loader.cancel()
        thumbnailView.image = nil
        thumbnailView.backgroundColor = .tertiarySystemFill
        thumbnailView.layer.cornerRadius = Self.thumbnailSide / 2
        glyphView.tintColor = .secondaryLabel
        glyphView.image = UIImage(systemName: "mappin")
        setNeedsLayout()
    }
}
