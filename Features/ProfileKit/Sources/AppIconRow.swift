import ComponentKit
import PinLayout
import UIKit

final class AppIconRow: UIControl {

    // MARK: Static Properties

    private static let iconSide: CGFloat = 60

    // MARK: Overridden Properties

    override var isSelected: Bool {
        didSet { updateAppearance() }
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.6 : 1 }
    }

    // MARK: Properties

    private let iconView = UIImageView()
    private let titleLabel = Label()
    private let detailLabel = Label()
    private let checkView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))

    // MARK: Lifecycle

    init(icon: AppIcon) {
        super.init(frame: .zero)

        setupViews(icon)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        iconView.pin
            .vCenter()
            .start()
            .size(Self.iconSide)
        checkView.pin
            .vCenter()
            .end()
            .sizeToFit()
        titleLabel.pin
            .after(of: iconView)
            .before(of: checkView)
            .marginStart(14)
            .marginEnd(12)
            .sizeToFit(.width)
        detailLabel.pin
            .start(to: titleLabel.edge.start)
            .end(to: titleLabel.edge.end)
            .sizeToFit(.width)
        let textHeight = titleLabel.frame.height + 2 + detailLabel.frame.height
        titleLabel.pin
            .top((bounds.height - textHeight) / 2)
        detailLabel.pin
            .below(of: titleLabel)
            .marginTop(2)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let width = size.width - Self.iconSide - 14 - 12 - checkView.sizeThatFits(size).width
        let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
        let text = titleLabel.sizeThatFits(fitting).height + 2 + detailLabel.sizeThatFits(fitting).height
        return CGSize(width: size.width, height: max(Self.iconSide, text) + 16)
    }

    // MARK: Functions

    private func setupViews(_ icon: AppIcon) {
        iconView.image = icon.preview
        titleLabel.text = icon.title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        detailLabel.text = icon.detail
        detailLabel.font = .preferredFont(forTextStyle: .subheadline)
        detailLabel.adjustsFontForContentSizeCategory = true
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0
        checkView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        checkView.tintColor = .tintColor
        for subview in [iconView, titleLabel, detailLabel, checkView] {
            subview.isUserInteractionEnabled = false
            addSubview(subview)
        }
        isAccessibilityElement = true
        accessibilityLabel = "\(icon.title), \(icon.detail)"
        // A plain UIControl never sends its primary action itself.
        addAction(UIAction { [weak self] _ in self?.sendActions(for: .primaryActionTriggered) }, for: .touchUpInside)
        updateAppearance()
    }

    private func updateAppearance() {
        checkView.isHidden = !isSelected
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }
}
