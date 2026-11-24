import PinLayout
public import UIKit

/// Marks a photo that has a clip: a small glass capsule with a play glyph and how long the clip runs ("0:12").
public final class ClipBadgeView: UIVisualEffectView {

    // MARK: Static Properties

    private static let spacing: CGFloat = 3

    // MARK: Computed Properties

    private var padding: UIEdgeInsets {
        isCompact
            ? UIEdgeInsets(top: 2, left: 5, bottom: 2, right: 6)
            : UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 9)
    }

    // MARK: Properties

    public var milliseconds = 0 {
        didSet {
            label.text = Self.lengthText(milliseconds: milliseconds)
            accessibilityLabel = Self.accessibilityText(milliseconds: milliseconds)
            setNeedsLayout()
        }
    }

    /// Smaller type and padding, for a thumbnail.
    public var isCompact = false {
        didSet {
            applyStyle()
        }
    }

    private let glyph = UIImageView(image: UIImage(systemName: "play.fill"))
    private let label = Label()

    // MARK: Lifecycle

    public init() {
        super.init(effect: UIGlassEffect())

        cornerConfiguration = .capsule()
        isUserInteractionEnabled = false
        isAccessibilityElement = true
        glyph.tintColor = .label
        glyph.contentMode = .center
        label.textColor = .label
        label.adjustsFontForContentSizeCategory = true
        contentView.addSubview(glyph)
        contentView.addSubview(label)
        applyStyle()
        milliseconds = 0
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        let padding = padding
        let glyphSize = glyph.sizeThatFits(.zero)
        glyph.pin
            .vCenter()
            .start(padding.left)
            .size(glyphSize)
        label.pin
            .after(of: glyph, aligned: .center)
            .marginStart(Self.spacing)
            .sizeToFit()
    }

    override public func sizeThatFits(_: CGSize) -> CGSize {
        let padding = padding
        let glyphSize = glyph.sizeThatFits(.zero)
        let text = label.sizeThatFits(CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude))
        return CGSize(
            width: padding.left + glyphSize.width + Self.spacing + text.width + padding.right,
            height: padding.top + max(glyphSize.height, text.height) + padding.bottom,
        )
    }

    // MARK: Static Functions

    /// Minutes and seconds in the app's language, as the system shows a video's length.
    public static func lengthText(milliseconds: Int) -> String {
        Duration.milliseconds(milliseconds).formatted(.time(pattern: .minuteSecond(
            padMinuteToLength: 1,
            roundFractionalSeconds: .toNearestOrAwayFromZero,
        )))
    }

    /// What VoiceOver says for the badge: that it's a video, and its length in words.
    public static func accessibilityText(milliseconds: Int) -> String {
        let seconds = Duration.seconds((Double(milliseconds) / 1000).rounded())
        return ComponentKitStrings.ClipBadge.a11y(seconds.formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
    }

    // MARK: Functions

    private func applyStyle() {
        let style: UIFont.TextStyle = isCompact ? .caption2 : .caption1
        let defaultSize = UIFontDescriptor
            .preferredFontDescriptor(withTextStyle: style, compatibleWith: UITraitCollection(preferredContentSizeCategory: .large))
            .pointSize
        label.font = UIFontMetrics(forTextStyle: style).scaledFont(
            for: .monospacedDigitSystemFont(ofSize: defaultSize, weight: .semibold),
        )
        glyph.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: style, scale: .small)
            .applying(UIImage.SymbolConfiguration(weight: .semibold))
        setNeedsLayout()
    }
}
