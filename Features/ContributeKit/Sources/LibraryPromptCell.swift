import ComponentKit
import PinLayout
import UIKit

/// From Your Photos without cards to show: what finding shots does and Find My Shots, no access, the scan's progress,
/// or, quietly, that nothing was found.
final class LibraryPromptCell: UICollectionViewCell {

    // MARK: Static Properties

    /// On top of the cell's margins, so the card lines up with the section headers and the other cards.
    private static let extraMargin: CGFloat = 8
    private static let padding: CGFloat = 16
    /// Without a card the text lines up with the section headers, 4 pt in from the cards' edge.
    private static let quietInset: CGFloat = 4

    // MARK: Properties

    var onAction: (() -> Void)?

    private let card = UIView()
    private let headlineLabel = Label()
    private let messageLabel = Label()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let button = UIButton(configuration: .primaryCapsule(title: ""))
    private var isCard = true

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 20
        card.layer.cornerCurve = .continuous
        headlineLabel.font = .preferredFont(forTextStyle: .headline)
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.numberOfLines = 0
        headlineLabel.accessibilityTraits = .header
        messageLabel.adjustsFontForContentSizeCategory = true
        messageLabel.numberOfLines = 0
        messageLabel.textColor = .secondaryLabel
        button.addAction(UIAction { [weak self] _ in self?.onAction?() }, for: .primaryActionTriggered)
        contentView.addSubview(card)
        for view in [headlineLabel, messageLabel, progressView, button] {
            card.addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func prepareForReuse() {
        super.prepareForReuse()

        onAction = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        card.pin
            .top(8)
            .horizontally(contentView.layoutMargins)
            .height(layoutCard(width: cardWidth(in: contentView.bounds.width)))
            .marginHorizontal(Self.extraMargin)
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = layoutCard(width: cardWidth(in: attributes.size.width)) + 8
        return fitted
    }

    // MARK: Functions

    func configure(with prompt: FromYourPhotosModel.Prompt) {
        let strings = ContributeKitStrings.Contribute.FromYourPhotos.self
        var headline: String?
        var message: String
        var action: String?
        var progress: Double?
        switch prompt {
        case .intro:
            (headline, message, action) = (strings.Intro.headline, strings.Intro.message, strings.Intro.button)
        case .denied:
            (headline, message, action) = (strings.Denied.headline, strings.Denied.message, strings.openSettings)
        case .scanning(let value):
            (headline, message, progress) = (strings.Scanning.headline, strings.Scanning.message, value)
        case .nothingFound:
            message = strings.nothingFound
        case .limited(let nothingFound):
            (message, action) = (nothingFound ? strings.Limited.nothingFound : strings.Limited.note, strings.Limited.change)
        }
        isCard = headline != nil
        card.backgroundColor = isCard ? .secondarySystemBackground : .clear
        headlineLabel.text = headline
        headlineLabel.isHidden = headline == nil
        messageLabel.text = message
        messageLabel.font = .preferredFont(forTextStyle: isCard ? .subheadline : .footnote)
        progressView.isHidden = progress == nil
        progressView.setProgress(Float(progress ?? 0), animated: progressView.progress < Float(progress ?? 0))
        button.isHidden = action == nil
        button.configuration = isCard ? .primaryCapsule(title: action ?? "") : .plain()
        if !isCard {
            button.configuration?.title = action
            button.configuration?.contentInsets = .zero
        }
        button.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { [isCard] attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: isCard ? .subheadline : .footnote, weight: .semibold)
            return attributes
        }
        setNeedsLayout()
    }

    private func cardWidth(in width: CGFloat) -> CGFloat {
        width - contentView.layoutMargins.left - contentView.layoutMargins.right - Self.extraMargin * 2
    }

    /// Lays out the card's contents at `width` and returns its height.
    private func layoutCard(width: CGFloat) -> CGFloat {
        let padding = isCard ? Self.padding : Self.quietInset
        let inner = width - padding * 2
        var bottom = isCard ? padding : 0
        if !headlineLabel.isHidden {
            headlineLabel.pin
                .top(bottom)
                .start(padding)
                .width(inner)
                .sizeToFit(.width)
            bottom = headlineLabel.frame.maxY + 4
        }
        messageLabel.pin
            .top(bottom)
            .start(padding)
            .width(inner)
            .sizeToFit(.width)
        bottom = messageLabel.frame.maxY
        if !progressView.isHidden {
            progressView.pin
                .top(bottom + 12)
                .start(padding)
                .width(inner)
                .sizeToFit(.width)
            bottom = progressView.frame.maxY
        }
        if !button.isHidden {
            let fitted = button.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude))
            if isCard {
                button.pin
                    .top(bottom + 12)
                    .start(padding)
                    .width(inner)
                    .height(max(40, ceil(fitted.height)))
            } else {
                button.pin
                    .top(bottom + 4)
                    .start(padding)
                    .width(min(inner, ceil(fitted.width)))
                    .height(max(32, ceil(fitted.height)))
            }
            bottom = button.frame.maxY
        }
        return ceil(bottom + (isCard ? padding : 0))
    }
}
