import ComponentKit
import FactoryKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class YourSpotCell: UICollectionViewListCell {

    // MARK: Static Properties

    private static let thumbnailSide: CGFloat = 64
    private static let dateFormat = Date.FormatStyle(date: .abbreviated, time: .omitted)
    private static let badgeInset: CGFloat = 7
    /// The spinner drawn small enough to sit in the caption-sized badge.
    private static let spinnerScale: CGFloat = 0.5
    private static let spinnerSide: CGFloat = 10

    // MARK: Properties

    var onRetry: (() -> Void)?
    var onWayBack: ((YourSpot.WayBack.Action) -> Void)?

    @Injected(\.thumbHashRenderer) private var renderer
    @Injected(\.imageLoader) private var loader
    @Injected(\.photoURLBuilder) private var urls

    private let thumbnailView = UIImageView()
    private let badgeLabel = InsetLabel()
    private let sendingSpinner = UIActivityIndicatorView(style: .medium)
    private let titleLabel = Label()
    private let detailLabel = Label()
    private let reasonLabel = Label()
    private let wayBackLabel = Label()
    private let actionButton = UIButton(configuration: .tinted())
    private var action: (() -> Void)?
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        thumbnailView.layer.cornerRadius = 12
        thumbnailView.layer.cornerCurve = .continuous
        thumbnailView.clipsToBounds = true
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.tintColor = .white
        badgeLabel.font = .preferredFont(forTextStyle: .caption2, weight: .semibold)
        badgeLabel.adjustsFontForContentSizeCategory = true
        badgeLabel.linesAtAccessibilitySizes = 0
        badgeLabel.textAlignment = .center
        badgeLabel.layer.cornerRadius = 8
        badgeLabel.layer.cornerCurve = .continuous
        badgeLabel.clipsToBounds = true
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 2
        titleLabel.linesAtAccessibilitySizes = 0
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.linesAtAccessibilitySizes = 0
        detailLabel.textColor = .secondaryLabel
        reasonLabel.font = .preferredFont(forTextStyle: .footnote)
        reasonLabel.adjustsFontForContentSizeCategory = true
        reasonLabel.numberOfLines = 0
        wayBackLabel.font = .preferredFont(forTextStyle: .footnote, weight: .medium)
        wayBackLabel.adjustsFontForContentSizeCategory = true
        wayBackLabel.numberOfLines = 0
        actionButton.configuration?.buttonSize = .small
        actionButton.configuration?.cornerStyle = .capsule
        actionButton.addAction(UIAction { [weak self] _ in self?.action?() }, for: .primaryActionTriggered)
        sendingSpinner.transform = CGAffineTransform(scaleX: Self.spinnerScale, y: Self.spinnerScale)
        sendingSpinner.hidesWhenStopped = true
        for view in [
            thumbnailView,
            badgeLabel,
            sendingSpinner,
            titleLabel,
            detailLabel,
            reasonLabel,
            wayBackLabel,
            actionButton,
        ] {
            contentView.addSubview(view)
        }
        isAccessibilityElement = true
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func prepareForReuse() {
        super.prepareForReuse()

        loading?.cancel()
        loading = nil
        thumbnailView.image = nil
        onRetry = nil
        onWayBack = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        contentView.frame.size.width = size.width
        layout()
        let text = [reasonLabel, wayBackLabel, actionButton].filter { !$0.isHidden }.map(\.frame.maxY).max() ?? 0
        let bottom = max(badgeLabel.frame.maxY, text)
        return CGSize(width: size.width, height: max(bottom, detailLabel.frame.maxY) + 12)
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = sizeThatFits(CGSize(width: attributes.size.width, height: .greatestFiniteMagnitude)).height
        return fitted
    }

    // MARK: Static Functions

    private static func colors(for badge: YourSpot.Badge) -> (UIColor, UIColor) {
        switch badge {
        case .sending, .pending, .private: (.label, .secondarySystemBackground)
        case .waitingForNetwork: (.white, .systemOrange)
        case .failed, .rejected: (.white, .systemRed)
        case .approved: (.white, .systemGreen)
        case .removed: (.white, .systemGray)
        }
    }

    // MARK: Functions

    func configure(with spot: YourSpot) {
        titleLabel.text = spot.title
        let place = "\(spot.cityName ?? spot.kind.title) · \(spot.date.formatted(Self.dateFormat))"
        detailLabel.text = spot.isEdit ? ContributeKitStrings.Contribute.YourSpots.suggestedEdit(place) : place
        badgeLabel.text = spot.badge.title
        let (foreground, background) = Self.colors(for: spot.badge)
        badgeLabel.textColor = foreground
        badgeLabel.backgroundColor = background
        let isSending = spot.badge == .sending
        badgeLabel.insets.leading = isSending ? Self.badgeInset + Self.spinnerSide + 3 : Self.badgeInset
        sendingSpinner.color = foreground
        if isSending {
            sendingSpinner.startAnimating()
        } else {
            sendingSpinner.stopAnimating()
        }
        var actionTitle: String?
        action = nil
        wayBackLabel.text = nil
        switch spot.badge {
        case .failed(let reason):
            reasonLabel.text = reason
            reasonLabel.textColor = .systemRed
            actionTitle = ContributeKitStrings.Contribute.YourSpots.retry
            action = { [weak self] in self?.onRetry?() }

        case .pending:
            reasonLabel.text = spot.isEdit
                ? ContributeKitStrings.Contribute.YourSpots.Pending.edit
                : ContributeKitStrings.Contribute.YourSpots.Pending.spot
            reasonLabel.textColor = .secondaryLabel

        case .rejected(let reason, let wayBack):
            reasonLabel.text = reason
            reasonLabel.textColor = .secondaryLabel
            wayBackLabel.text = wayBack.line
            if let wayBackAction = wayBack.action {
                actionTitle = wayBackAction.title
                action = { [weak self] in self?.onWayBack?(wayBackAction) }
            }

        case .private(let collection):
            reasonLabel.text = collection.map(ContributeKitStrings.Contribute.YourSpots.addedTo)
            reasonLabel.textColor = .secondaryLabel

        case .removed(let reason):
            reasonLabel.text = reason
            reasonLabel.textColor = .secondaryLabel

        default:
            reasonLabel.text = nil
        }
        actionButton.configuration?.title = actionTitle
        actionButton.isHidden = actionTitle == nil
        reasonLabel.isHidden = reasonLabel.text == nil
        wayBackLabel.isHidden = wayBackLabel.text == nil
        accessibilityLabel = spot.title
        accessibilityValue = [spot.badge.title, detailLabel.text, reasonLabel.text, wayBackLabel.text]
            .compactMap(\.self)
            .joined(separator: ", ")
        accessibilityTraits = spot.spotID == nil ? .none : .button
        accessibilityCustomActions = actionTitle.map { title in
            [UIAccessibilityCustomAction(name: title) { [weak self] _ in
                self?.action?()
                return true
            }]
        }
        thumbnailView.backgroundColor = spot.kind.tint
        thumbnailView.image = UIImage(systemName: spot.kind.symbolName)
        thumbnailView.contentMode = .center
        loading?.cancel()
        let photoURL = spot.coverKey.flatMap { urls.url(for: $0, size: .avatar, scale: traitCollection.displayScale) }
        loading = spot.thumbhash == nil && photoURL == nil
            ? nil
            : Task { [renderer, loader, weak self] in
                if let thumbhash = spot.thumbhash, let placeholder = await renderer.image(base64: thumbhash) {
                    guard !Task.isCancelled else {
                        return
                    }
                    self?.showThumbnail(placeholder)
                }
                guard let photoURL, let photo = try? await loader.photo(photoURL, .avatar), !Task.isCancelled else {
                    return
                }
                self?.showThumbnail(photo)
            }
        setNeedsLayout()
    }

    private func showThumbnail(_ image: UIImage) {
        thumbnailView.image = image
        thumbnailView.contentMode = .scaleAspectFill
    }

    private func layout() {
        let side = Self.thumbnailSide
        thumbnailView.pin
            .top(12)
            .start(contentView.layoutMargins)
            .size(side)
        titleLabel.pin
            .top(12)
            .after(of: thumbnailView)
            .end(contentView.layoutMargins)
            .marginStart(14)
            .sizeToFit(.width)
        detailLabel.pin
            .below(of: titleLabel)
            .start(to: titleLabel.edge.start)
            .end(to: titleLabel.edge.end)
            .marginTop(2)
            .sizeToFit(.width)
        let badgeUnderDetails = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        if badgeUnderDetails {
            let fitted = badgeLabel.sizeThatFits(CGSize(width: titleLabel.frame.width, height: .greatestFiniteMagnitude))
            badgeLabel.pin
                .below(of: detailLabel)
                .start(to: titleLabel.edge.start)
                .width(min(max(fitted.width, 44), titleLabel.frame.width))
                .height(fitted.height)
                .marginTop(6)
        } else {
            badgeLabel.pin
                .minWidth(44)
                .maxWidth(side + 48)
                .sizeToFit()
            badgeLabel.pin
                .vCenter(to: thumbnailView.edge.bottom)
                .hCenter(to: thumbnailView.edge.hCenter)
        }
        sendingSpinner.pin
            .vCenter(to: badgeLabel.edge.vCenter)
            .hCenter(to: badgeLabel.edge.start)
            .marginStart(Self.badgeInset + Self.spinnerSide / 2)
        let lastLine: UIView = badgeUnderDetails ? badgeLabel : detailLabel
        reasonLabel.pin
            .below(of: lastLine)
            .start(to: titleLabel.edge.start)
            .end(to: titleLabel.edge.end)
            .marginTop(4)
            .sizeToFit(.width)
        wayBackLabel.pin
            .below(of: reasonLabel.isHidden ? lastLine : reasonLabel)
            .start(to: titleLabel.edge.start)
            .end(to: titleLabel.edge.end)
            .marginTop(reasonLabel.isHidden ? 4 : 2)
            .sizeToFit(.width)
        let lastText = [wayBackLabel, reasonLabel].first { !$0.isHidden } ?? lastLine
        // Measured, not `sizeToFit()`: a reused cell's last title would cap the width and wrap a longer one.
        let actionSize = actionButton.sizeThatFits(CGSize(width: titleLabel.frame.width, height: .greatestFiniteMagnitude))
        actionButton.pin
            .below(of: lastText)
            .start(to: titleLabel.edge.start)
            .width(min(ceil(actionSize.width), titleLabel.frame.width))
            .height(ceil(actionSize.height))
            .marginTop(8)
    }

}
