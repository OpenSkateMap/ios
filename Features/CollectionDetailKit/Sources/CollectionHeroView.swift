import ComponentKit
import ImageKit
import PinLayout
import SpotModelKit
import UIKit

final class CollectionHeroView: UIView {

    // MARK: Types

    enum Backdrop: Equatable {
        case photo(key: String, thumbhash: String?)
        case image(UIImage)
        case look(CollectionLook, symbol: String)
    }

    struct Content: Equatable {
        var title: String
        var subtitle: String?
        var backdrop: Backdrop
    }

    // MARK: Static Properties

    private static let inset: CGFloat = 20

    // MARK: Computed Properties

    var titleRise: CGFloat {
        layoutIfNeeded()
        return bounds.height - pageOverlap - titleLabel.frame.minY
    }

    // MARK: Properties

    var content: Content? {
        didSet {
            guard content != oldValue else {
                return
            }
            apply()
        }
    }

    /// How far the page below reaches up into the hero, and its top corners' radius. The hero leaves that shape unpainted
    /// rather than a view covering it, which would hang on layer order (a snapshot's render ignores `zPosition`).
    var pageOverlap: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    var pageCornerRadius: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    var textAlpha: CGFloat = 1 {
        didSet {
            titleLabel.alpha = textAlpha
            subtitleLabel.alpha = textAlpha
        }
    }

    private let artwork = CollectionArtworkView()
    private let loader = PhotoLoader()
    private let scrim = CAGradientLayer()
    private let pageCutout = CAShapeLayer()
    private let titleLabel = Label()
    private let subtitleLabel = Label()

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
            .all()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        scrim.frame = CGRect(x: 0, y: bounds.height * 0.45, width: bounds.width, height: bounds.height * 0.55)
        layoutPageCutout()
        CATransaction.commit()
        let sides = UIEdgeInsets(
            top: 0,
            left: Self.inset + safeAreaInsets.left,
            bottom: 0,
            right: Self.inset + safeAreaInsets.right,
        )
        subtitleLabel.pin
            .horizontally(sides)
            .sizeToFit(.width)
        titleLabel.pin
            .horizontally(sides)
            .sizeToFit(.width)
        let subtitleHeight = subtitleLabel.isHidden ? 0 : subtitleLabel.frame.height + 2
        titleLabel.pin
            .bottom(Self.inset + pageOverlap + subtitleHeight)
        subtitleLabel.pin
            .below(of: titleLabel)
            .marginTop(2)
    }

    // MARK: Functions

    private func layoutPageCutout() {
        guard pageOverlap > 0 else {
            layer.mask = nil
            return
        }
        let page = CGRect(x: 0, y: bounds.height - pageOverlap, width: bounds.width, height: pageOverlap + pageCornerRadius)
        let path = UIBezierPath(rect: bounds)
        path.append(UIBezierPath(
            roundedRect: page,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: pageCornerRadius, height: pageCornerRadius),
        ))
        pageCutout.frame = bounds
        pageCutout.path = path.cgPath
        layer.mask = pageCutout
    }

    private func setupViews() {
        clipsToBounds = true
        pageCutout.fillRule = .evenOdd
        artwork.symbolScale = 0.28
        scrim.colors = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.55).cgColor]
        titleLabel.font = .preferredFont(forTextStyle: .largeTitle, weight: .heavy)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = .white
        titleLabel.numberOfLines = 2
        titleLabel.accessibilityTraits = .header
        subtitleLabel.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textColor = UIColor(white: 1, alpha: 0.85)
        subtitleLabel.numberOfLines = 2
        addSubview(artwork)
        layer.addSublayer(scrim)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
    }

    private func apply() {
        titleLabel.text = content?.title
        subtitleLabel.text = content?.subtitle
        subtitleLabel.isHidden = content?.subtitle?.isEmpty != false
        switch content?.backdrop {
        case .photo(let key, let thumbhash):
            artwork.content = .photo
            loader.show(key: key, thumbhash: thumbhash, size: .page, scale: traitCollection.displayScale, in: artwork.photoView)

        case .image(let image):
            loader.cancel()
            artwork.content = .image(image)

        case .look(let look, let symbol):
            loader.cancel()
            artwork.content = .look(look, symbol: symbol)

        case nil:
            loader.cancel()
            artwork.content = .photo
        }
        setNeedsLayout()
    }
}
