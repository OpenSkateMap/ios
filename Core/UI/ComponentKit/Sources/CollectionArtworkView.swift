import PinLayout
public import SpotModelKit
public import UIKit

public final class CollectionArtworkView: UIView {

    // MARK: Types

    public enum Content: Equatable {
        /// A loader fills `photoView`.
        case photo
        case image(UIImage)
        case look(CollectionLook, symbol: String)
    }

    // MARK: Properties

    public var content = Content.photo {
        didSet {
            guard content != oldValue else {
                return
            }
            apply()
        }
    }

    /// The symbol's height as a share of the view's shorter side.
    public var symbolScale: CGFloat = 0.36 {
        didSet { setNeedsLayout() }
    }

    public let photoView = UIImageView()

    private let gradient = CAGradientLayer()
    private let glyphView = UIImageView()

    // MARK: Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    override public func updateProperties() {
        super.updateProperties()

        let (start, end): (UIColor, UIColor) =
            switch content {
            case .look(let look, _): look.color.tones(for: traitCollection)
            case .photo, .image: (.secondarySystemFill, .secondarySystemFill)
            }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.colors = [start, end].map { $0.resolvedColor(with: traitCollection).cgColor }
        CATransaction.commit()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        gradient.frame = bounds
        CATransaction.commit()
        photoView.pin
            .all()
        glyphView.pin
            .center()
            .size(min(bounds.width, bounds.height) * symbolScale)
    }

    // MARK: Functions

    private func setupViews() {
        clipsToBounds = true
        isAccessibilityElement = false
        gradient.startPoint = CGPoint(x: 0, y: 0)
        gradient.endPoint = CGPoint(x: 1, y: 1)
        layer.addSublayer(gradient)
        photoView.contentMode = .scaleAspectFill
        photoView.clipsToBounds = true
        glyphView.contentMode = .scaleAspectFit
        glyphView.tintColor = .white
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(weight: .semibold)
        addSubview(photoView)
        addSubview(glyphView)
        apply()
    }

    private func apply() {
        switch content {
        case .photo:
            glyphView.image = nil
            photoView.isHidden = false

        case .image(let image):
            photoView.image = image
            photoView.isHidden = false
            glyphView.image = nil

        case .look(_, let symbol):
            photoView.image = nil
            photoView.isHidden = true
            glyphView.image = UIImage(systemName: symbol)
        }
        setNeedsUpdateProperties()
    }

}
