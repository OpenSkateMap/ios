import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

// MARK: - SpotVideosSectionView

final class SpotVideosSectionView: UIView {

    // MARK: Static Properties

    private static let peek: CGFloat = 36
    private static let spacing: CGFloat = 10

    // MARK: Properties

    var onOpen: ((URL) -> Void)?
    var onDiscard: ((String) -> Void)?

    private let scrollView = UIScrollView().softEdges()
    private var cards = [SpotVideoCardView]()
    private let emptyLabel = Label()
    private let statusLabel = Label()
    private let statusButton = UIButton(configuration: .plain())
    private var shownVideos = [SpotVideo]()
    private var shownDraft: VideoDraft?
    private var cardWidth: CGFloat = 0
    private let loader: ImageLoader

    // MARK: Lifecycle

    init(loader: ImageLoader) {
        self.loader = loader
        super.init(frame: .zero)
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.clipsToBounds = false
        scrollView.decelerationRate = .fast
        scrollView.delegate = self
        emptyLabel.text = SpotDetailKitStrings.Spot.Videos.empty
        emptyLabel.font = .preferredFont(forTextStyle: .body)
        emptyLabel.adjustsFontForContentSizeCategory = true
        emptyLabel.textColor = .sheetSecondaryLabel
        emptyLabel.numberOfLines = 0
        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = .sheetSecondaryLabel
        statusLabel.numberOfLines = 0
        statusButton.configuration?.contentInsets = .zero
        statusButton.configuration?.title = SpotDetailKitStrings.Spot.Videos.Draft.remove
        statusButton.addAction(UIAction { [weak self] _ in
            if let id = self?.shownDraft?.id {
                self?.onDiscard?(id)
            }
        }, for: .primaryActionTriggered)
        statusButton.configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = .preferredFont(forTextStyle: .footnote, weight: .semibold)
            return attributes
        }
        addSubview(scrollView)
        addSubview(emptyLabel)
        addSubview(statusLabel)
        addSubview(statusButton)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: ceil(layout(width: size.width)))
    }

    // MARK: Functions

    func show(_ videos: [SpotVideo], draft: VideoDraft?) {
        if videos != shownVideos {
            shownVideos = videos
            for card in cards {
                card.removeFromSuperview()
            }
            cards = videos.map { video in
                let card = SpotVideoCardView(loader: loader)
                card.show(video)
                // The cards are plain controls, which send touch events but not `.primaryActionTriggered`.
                card.addAction(UIAction { [weak self] _ in
                    if let url = URL(string: video.url) {
                        self?.onOpen?(url)
                    }
                }, for: .touchUpInside)
                scrollView.addSubview(card)
                return card
            }
            scrollView.contentOffset = .zero
        }
        emptyLabel.isHidden = !videos.isEmpty
        shownDraft = draft
        switch draft?.status {
        case .pending, .uploading:
            statusLabel.text = SpotDetailKitStrings.Spot.Videos.Draft.sending
            statusButton.isHidden = true

        case .failed:
            statusLabel.text = draft?.problem ?? SpotDetailKitStrings.Spot.Videos.Draft.failed
            statusButton.isHidden = false

        case nil:
            statusLabel.text = nil
            statusButton.isHidden = true
        }
        statusLabel.isHidden = statusLabel.text == nil
        setNeedsLayout()
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        var bottom: CGFloat = 0
        if cards.isEmpty {
            scrollView.frame = .zero
            emptyLabel.pin
                .top()
                .start()
                .width(width)
                .sizeToFit(.width)
            bottom = emptyLabel.frame.maxY
        } else {
            cardWidth = cards.count == 1 ? width : width - Self.peek
            let cardHeight = (cardWidth * 9 / 16).rounded()
            scrollView.pin
                .top()
                .start()
                .width(width)
                .height(cardHeight)
            scrollView.layoutRow(cards, spacing: Self.spacing) { _ in CGSize(width: cardWidth, height: cardHeight) }
            bottom = cardHeight
        }
        if !statusLabel.isHidden {
            let buttonWidth = statusButton.isHidden ? 0 : statusButton.sizeThatFits(.zero).width + 12
            statusLabel.pin
                .top(bottom + 10)
                .start()
                .width(width - buttonWidth)
                .sizeToFit(.width)
            statusButton.pin
                .vCenter(to: statusLabel.edge.vCenter)
                .end()
                .sizeToFit()
            bottom = statusLabel.frame.maxY
        }
        return bottom
    }
}

// MARK: UIScrollViewDelegate

extension SpotVideosSectionView: UIScrollViewDelegate {
    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity _: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let stride = cardWidth + Self.spacing
        guard stride > 0 else {
            return
        }
        let maximum = max(scrollView.contentSize.width - scrollView.bounds.width, 0)
        let card = (targetContentOffset.pointee.x / stride).rounded()
        targetContentOffset.pointee.x = min(card * stride, maximum)
    }
}

// MARK: - SpotVideoCardView

private final class SpotVideoCardView: UIControl {

    // MARK: Static Properties

    private static let thumbnailSize = CGSize(width: 360, height: 203)

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            UIView.animate(withDuration: isHighlighted ? 0 : 0.2) {
                self.alpha = self.isHighlighted ? 0.7 : 1
            }
        }
    }

    // MARK: Properties

    private let backdrop = CAGradientLayer()
    private let thumbnailView = UIImageView()
    private let scrim = CAGradientLayer()
    private let playBadge = UIVisualEffectView(effect: UIGlassEffect(style: .clear))
    private let playGlyph = UIImageView(image: UIImage(systemName: "play.fill"))
    private let captionLabel = Label()
    private let creditLabel = Label()
    private let loader: ImageLoader
    private var loading: Task<Void, Never>?

    // MARK: Lifecycle

    init(loader: ImageLoader) {
        self.loader = loader
        super.init(frame: .zero)
        clipsToBounds = true
        layer.cornerRadius = SpotPageView.cardCornerRadius
        layer.cornerCurve = .continuous
        backdrop.colors = [UIColor(white: 0.2, alpha: 1), UIColor(white: 0.08, alpha: 1)].map(\.cgColor)
        layer.addSublayer(backdrop)
        thumbnailView.contentMode = .scaleAspectFill
        thumbnailView.clipsToBounds = true
        thumbnailView.isUserInteractionEnabled = false
        thumbnailView.accessibilityIgnoresInvertColors = true
        addSubview(thumbnailView)
        scrim.colors = [UIColor.black.withAlphaComponent(0), UIColor.black.withAlphaComponent(0.7)].map(\.cgColor)
        scrim.locations = [0.35, 1]
        layer.addSublayer(scrim)
        playBadge.cornerConfiguration = .capsule()
        playBadge.isUserInteractionEnabled = false
        playGlyph.tintColor = .white
        playGlyph.contentMode = .center
        playGlyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        playBadge.contentView.addSubview(playGlyph)
        captionLabel.font = .preferredFont(forTextStyle: .headline)
        captionLabel.adjustsFontForContentSizeCategory = true
        captionLabel.textColor = .white
        captionLabel.numberOfLines = 2
        creditLabel.font = .preferredFont(forTextStyle: .footnote)
        creditLabel.adjustsFontForContentSizeCategory = true
        creditLabel.linesAtAccessibilitySizes = 2
        creditLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        for view in [playBadge, captionLabel, creditLabel] {
            addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        loading?.cancel()
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        backdrop.frame = bounds
        scrim.frame = bounds
        CATransaction.commit()
        thumbnailView.pin
            .all()
        playBadge.pin
            .center()
            .size(52)
        playGlyph.pin
            .all()
        creditLabel.pin
            .bottom(12)
            .horizontally(14)
            .sizeToFit(.width)
        captionLabel.pin
            .above(of: creditLabel)
            .horizontally(14)
            .marginBottom(2)
            .sizeToFit(.width)
    }

    // MARK: Functions

    func show(_ video: SpotVideo) {
        let platform = video.provider.title
        let caption = video.caption.isEmpty ? SpotDetailKitStrings.Spot.Videos.Card.untitled(platform) : video.caption
        let credit = video.addedByName.map { SpotDetailKitStrings.Spot.Videos.Card.credit(platform, $0) } ?? platform
        captionLabel.text = caption
        creditLabel.text = credit
        thumbnailView.image = nil
        accessibilityLabel = SpotDetailKitStrings.Spot.Videos.Card.A11y.label(caption, credit)
        accessibilityHint = SpotDetailKitStrings.Spot.Videos.Card.A11y.hint(platform)
        loading?.cancel()
        guard let thumbnail = video.thumbnailURL.flatMap(URL.init(string:)) else {
            return
        }
        loading = Task { [weak self, loader] in
            guard let image = try? await loader.image(thumbnail, Self.thumbnailSize), !Task.isCancelled else {
                return
            }
            self?.thumbnailView.image = image
        }
    }
}
