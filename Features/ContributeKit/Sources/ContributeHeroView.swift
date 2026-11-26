import ComponentKit
import PinLayout
import UIKit

final class ContributeHeroView: UIView {

    // MARK: Types

    struct Content: Equatable {
        var headline: String
        var message: String
    }

    // MARK: Static Properties

    private static let inset: CGFloat = 20

    // MARK: Properties

    var onAddSpot: (() -> Void)?

    private let headlineLabel = Label()
    private let messageLabel = Label()
    private let addButton = UIButton(configuration: .primaryCapsule(title: ContributeKitStrings.Contribute.Hero.addSpot))

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        overrideUserInterfaceStyle = .dark
        backgroundColor = UIColor(white: 0.09, alpha: 1)
        layer.cornerRadius = 26
        layer.cornerCurve = .continuous
        layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        headlineLabel.numberOfLines = 0
        headlineLabel.textColor = .white
        headlineLabel.accessibilityTraits = .header
        headlineLabel.adjustsFontForContentSizeCategory = true
        headlineLabel.font = UIFontMetrics(forTextStyle: .largeTitle)
            .scaledFont(for: .systemFont(ofSize: 34, weight: .bold, width: .compressed), maximumPointSize: 56)
        messageLabel.numberOfLines = 0
        messageLabel.textColor = UIColor.white.withAlphaComponent(0.78)
        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.adjustsFontForContentSizeCategory = true
        addButton.configuration?.image = UIImage(systemName: "plus")
        addButton.configuration?.imagePadding = 8
        addButton.addAction(UIAction { [weak self] _ in self?.onAddSpot?() }, for: .primaryActionTriggered)
        for view in [headlineLabel, messageLabel, addButton] {
            addSubview(view)
        }
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
        CGSize(width: size.width, height: autoSizeThatFits(size) { layout(width: size.width) }.height)
    }

    // MARK: Functions

    func show(_ content: Content) {
        headlineLabel.text = content.headline
        headlineLabel.accessibilityLabel = content.headline.capitalized
        messageLabel.text = content.message
        setNeedsLayout()
    }

    private func layout(width: CGFloat) {
        let inset = Self.inset
        let inner = width - inset * 2
        headlineLabel.pin
            .top(inset + 2)
            .start(inset)
            .width(inner)
            .sizeToFit(.width)
        messageLabel.pin
            .below(of: headlineLabel)
            .start(inset)
            .width(inner)
            .marginTop(8)
            .sizeToFit(.width)
        addButton.pin
            .below(of: messageLabel)
            .start(inset)
            .width(inner)
            .height(addButton.capsuleHeight(fitting: inner))
            .marginTop(18)
            .marginBottom(inset)
    }
}
