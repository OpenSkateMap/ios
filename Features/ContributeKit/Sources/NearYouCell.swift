import ComponentKit
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

/// A spot in Near You: its cover (or its kind's glyph), the name, how far and what's there, and Add Photos.
final class NearYouCell: UICollectionViewCell {

    // MARK: Static Properties

    static let width: CGFloat = 168
    private static let photoAspect: CGFloat = 132 / 168
    private static let inset: CGFloat = 12

    // MARK: Properties

    var onAddPhotos: (() -> Void)?

    @Injected(\.thumbHashRenderer) private var renderer
    @Injected(\.imageLoader) private var loader
    @Injected(\.photoURLBuilder) private var urls

    private let photoView = UIImageView()
    private let badgeLabel = InsetLabel()
    private let titleLabel = Label()
    private let detailLabel = Label()
    private let addButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.Contribute.NearYou.addPhotos))
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.backgroundColor = .secondarySystemBackground
        contentView.layer.cornerRadius = 20
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true
        photoView.clipsToBounds = true
        photoView.tintColor = .white
        photoView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title1)
        badgeLabel.text = ContributeKitStrings.Contribute.NearYou.noPhoto
        badgeLabel.font = .preferredFont(forTextStyle: .caption1, weight: .semibold)
        badgeLabel.adjustsFontForContentSizeCategory = true
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        badgeLabel.insets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        badgeLabel.layer.cornerRadius = 10
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true
        titleLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.linesAtAccessibilitySizes = 2
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.linesAtAccessibilitySizes = 2
        addButton.configuration?.buttonSize = .small
        addButton.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 12, bottom: 9, trailing: 12)
        addButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .subheadline, weight: .semibold)
            return attributes
        }
        addButton.addAction(UIAction { [weak self] _ in self?.onAddPhotos?() }, for: .primaryActionTriggered)
        for view in [photoView, badgeLabel, titleLabel, detailLabel, addButton] {
            contentView.addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityCustomActions = [
            UIAccessibilityCustomAction(name: ContributeKitStrings.Contribute.NearYou.addPhotos) { [weak self] _ in
                self?.onAddPhotos?()
                return true
            },
        ]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override var isHighlighted: Bool {
        didSet {
            contentView.alpha = isHighlighted ? 0.7 : 1
        }
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        loading?.cancel()
        loading = nil
        photoView.image = nil
        onAddPhotos = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: contentView.bounds.width)
    }

    // MARK: Static Functions

    static func detail(for spot: NearYou.Spot) -> String {
        let distance = spot.distanceMeters.map { meters in
            Measurement(value: Double(meters), unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road))
        }
        let what = spot.spot.obstacles.first.map(SpotObstacle.title(of:)) ?? spot.spot.kind.title
        return [distance, what].compactMap(\.self).joined(separator: " · ")
    }

    /// The tallest of these cards at `width`, measured with the text they'd show.
    static func height(fitting spots: [NearYou.Spot], width: CGFloat, traits: UITraitCollection) -> CGFloat {
        let sizing = NearYouCell()
        sizing.traitOverrides.preferredContentSizeCategory = traits.preferredContentSizeCategory
        return spots.map { spot in
            sizing.showText(for: spot)
            return sizing.height(fitting: width)
        }.max() ?? 0
    }

    // MARK: Functions

    func configure(with spot: NearYou.Spot) {
        let index = spot.spot
        let hasPhoto = index.coverKey != nil
        showText(for: spot)
        badgeLabel.isHidden = hasPhoto
        // The spots that need a photo most get the strongest button.
        addButton.configuration?.baseBackgroundColor = hasPhoto ? .tertiarySystemFill : .label
        addButton.configuration?.baseForegroundColor = hasPhoto ? .label : .inverseLabel
        accessibilityLabel = index.title
        accessibilityValue = [detailLabel.text, hasPhoto ? nil : badgeLabel.text].compactMap(\.self).joined(separator: ", ")
        accessibilityUserInputLabels = [index.title]
        photoView.backgroundColor = index.kind.tint
        photoView.image = UIImage(systemName: index.kind.symbolName)
        photoView.contentMode = .center
        loading?.cancel()
        let photoURL = index.coverKey.flatMap { urls.url(for: $0, size: .card, scale: traitCollection.displayScale) }
        loading = photoURL == nil
            ? nil
            : Task { [renderer, loader, weak self] in
                if let thumbhash = index.coverThumbhash, let placeholder = await renderer.image(base64: thumbhash) {
                    guard !Task.isCancelled else {
                        return
                    }
                    self?.showPhoto(placeholder)
                }
                guard let photoURL, let photo = try? await loader.photo(photoURL, .card), !Task.isCancelled else {
                    return
                }
                self?.showPhoto(photo)
            }
        setNeedsLayout()
    }

    private func showText(for spot: NearYou.Spot) {
        titleLabel.text = spot.spot.title
        detailLabel.text = Self.detail(for: spot)
    }

    private func showPhoto(_ image: UIImage) {
        photoView.image = image
        photoView.contentMode = .scaleAspectFill
    }

    private func height(fitting width: CGFloat) -> CGFloat {
        layout(width: width)
        return addButton.frame.maxY + Self.inset
    }

    private func layout(width: CGFloat) {
        let inset = Self.inset
        let inner = width - inset * 2
        photoView.pin
            .top()
            .start()
            .width(width)
            .height((width * Self.photoAspect).rounded())
        badgeLabel.pin
            .top(8)
            .start(8)
            .maxWidth(width - 16)
            .sizeToFit()
        titleLabel.pin
            .below(of: photoView)
            .start(inset)
            .width(inner)
            .marginTop(10)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: titleLabel)
            .start(inset)
            .width(inner)
            .marginTop(1)
            .sizeToFit(.width)
        addButton.pin
            .below(of: detailLabel)
            .start(inset)
            .width(inner)
            .height(max(36, ceil(addButton.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude)).height)))
            .marginTop(8)
    }
}
