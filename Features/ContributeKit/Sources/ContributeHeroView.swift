import ComponentKit
import PinLayout
import UIKit

/// Add a Spot as one control: a brand-orange slab with ink type and a see-through pill, so it reads apart from Near
/// You's cards and their white buttons. The pill sits beside the text, or under it when the text needs the width.
final class ContributeHeroView: UIControl {

    // MARK: Types

    struct Content: Equatable {
        var headline: String
        var message: String
    }

    // MARK: Static Properties

    /// The website's accent; black type on it keeps small text above 4.5:1, which white wouldn't.
    private static let brand = UIColor(red: 0xF5 / 255, green: 0x52 / 255, blue: 0x0A / 255, alpha: 1)
    private static let ink = UIColor.black
    private static let inset: CGFloat = 20
    private static let pillGap: CGFloat = 16
    private static let pillHeight: CGFloat = 36
    /// Measured from the reference banner's press: 0.97 over 0.3 s on this curve.
    private static let pressCurve = UICubicTimingParameters(
        controlPoint1: CGPoint(x: 0.23, y: 1),
        controlPoint2: CGPoint(x: 0.32, y: 1),
    )
    private static let grain = grainImage()

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            guard isHighlighted != oldValue else {
                return
            }
            showPress()
        }
    }

    // MARK: Properties

    var onAddSpot: (() -> Void)?

    private let grainView = UIView()
    private let headlineLabel = Label()
    private let messageLabel = Label()
    private let pill = UIButton(configuration: .plain())
    private var content = Content(headline: "", message: "")

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = Self.brand
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        clipsToBounds = true
        grainView.backgroundColor = Self.grain.map(UIColor.init(patternImage:))
        grainView.alpha = 0.07
        grainView.isUserInteractionEnabled = false
        headlineLabel.numberOfLines = 0
        headlineLabel.textColor = Self.ink
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.font = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .systemFont(ofSize: 30, weight: .heavy, width: .compressed), maximumPointSize: 52)
        messageLabel.numberOfLines = 0
        messageLabel.textColor = Self.ink.withAlphaComponent(0.72)
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        pill.isUserInteractionEnabled = false
        pill.configuration = Self.pillConfiguration()
        pill.layer.cornerRadius = Self.pillHeight / 2
        pill.layer.cornerCurve = .continuous
        pill.layer.borderWidth = 1
        pill.layer.borderColor = Self.ink.withAlphaComponent(0.3).cgColor
        pill.backgroundColor = Self.ink.withAlphaComponent(0.1)
        for view in [grainView, headlineLabel, messageLabel, pill] {
            addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityLabel = ContributeKitStrings.Contribute.Hero.addSpot
        addAction(UIAction { [weak self] _ in self?.onAddSpot?() }, for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        grainView.pin
            .all()
        _ = layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Static Functions

    private static func pillConfiguration() -> UIButton.Configuration {
        var configuration = UIButton.Configuration.plain()
        configuration.title = ContributeKitStrings.Contribute.Hero.addSpot
        configuration.image = UIImage(systemName: "plus")
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        configuration.imagePadding = 5
        configuration.baseForegroundColor = ink
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 14)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .subheadline, weight: .semibold)
            return attributes
        }
        return configuration
    }

    /// Static film grain: grey noise tiled at low opacity over the slab.
    private static func grainImage() -> UIImage? {
        let side = 96
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        let pixels = (0..<(side * side)).map { _ -> UInt8 in
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return UInt8(truncatingIfNeeded: state)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(
                  width: side,
                  height: side,
                  bitsPerComponent: 8,
                  bitsPerPixel: 8,
                  bytesPerRow: side,
                  space: CGColorSpaceCreateDeviceGray(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: false,
                  intent: .defaultIntent,
              ) else {
            return nil
        }
        return UIImage(cgImage: image, scale: 2, orientation: .up)
    }

    // MARK: Functions

    func show(_ content: Content) {
        self.content = content
        headlineLabel.text = content.headline
        messageLabel.text = content.message
        accessibilityValue = [content.headline.capitalized, content.message].joined(separator: ", ")
        setNeedsLayout()
    }

    private func showPress() {
        let pressed = isHighlighted
        guard !UIAccessibility.isReduceMotionEnabled else {
            alpha = pressed ? 0.85 : 1
            return
        }
        let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: Self.pressCurve)
        animator.addAnimations {
            self.transform = pressed ? CGAffineTransform(scaleX: 0.97, y: 0.97) : .identity
        }
        animator.startAnimation()
    }

    /// Lays out for `width` and returns the height it takes.
    private func layout(width: CGFloat) -> CGFloat {
        let inset = Self.inset
        let inner = max(width - inset * 2, 0)
        let fitted = pill.sizeThatFits(CGSize(width: inner, height: .greatestFiniteMagnitude))
        let pillSize = CGSize(width: min(ceil(fitted.width), inner), height: max(Self.pillHeight, ceil(fitted.height)))
        let besideWidth = inner - pillSize.width - Self.pillGap
        let messageLines = messageLabel.sizeThatFits(CGSize(width: max(besideWidth, 1), height: .greatestFiniteMagnitude)).height
            / messageLabel.font.lineHeight
        // A long message beside the pill would make a tall, narrow column: the pill goes under it instead.
        let stacks = besideWidth < 150 || messageLines > 2.5 || traitCollection.preferredContentSizeCategory
            .isAccessibilityCategory
        let textWidth = stacks ? inner : besideWidth
        headlineLabel.pin
            .top(inset)
            .start(inset)
            .width(textWidth)
            .sizeToFit(.width)
        messageLabel.pin
            .below(of: headlineLabel)
            .start(inset)
            .width(textWidth)
            .marginTop(4)
            .sizeToFit(.width)
        let textBottom = messageLabel.frame.maxY
        if stacks {
            pill.pin
                .below(of: messageLabel)
                .start(inset)
                .size(pillSize)
                .marginTop(14)
            return pill.frame.maxY + inset
        }
        pill.pin
            .top(inset + (textBottom - inset - pillSize.height) / 2)
            .end(inset)
            .size(pillSize)
        return textBottom + inset
    }
}
