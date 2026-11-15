import ComponentKit
import PinLayout
import TipJarKit
import UIKit

// MARK: - TipChoiceView

final class TipChoiceView: UIView {

    // MARK: Static Properties

    private static let inset: CGFloat = 16

    // MARK: Properties

    private(set) var selected: Tip
    var onChange: ((Tip) -> Void)?

    private let tips: [Tip]
    private let rows: [TipRowView]
    private let separators: [UIView]

    // MARK: Lifecycle

    init(tips: [Tip]) {
        self.tips = tips
        selected = tips[tips.count / 2]
        rows = tips.map(TipRowView.init(tip:))
        separators = tips.dropFirst().map { _ in UIView() }
        super.init(frame: .zero)
        setupViews()
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
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    private func setupViews() {
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        clipsToBounds = true
        for (row, tip) in zip(rows, tips) {
            row.addAction(UIAction { [weak self] _ in self?.select(tip) }, for: .touchUpInside)
            addSubview(row)
        }
        for separator in separators {
            separator.backgroundColor = .separator
            addSubview(separator)
        }
        showSelection()
    }

    private func select(_ tip: Tip) {
        guard tip != selected else {
            return
        }
        UISelectionFeedbackGenerator(view: self).selectionChanged()
        selected = tip
        showSelection()
        onChange?(tip)
    }

    private func showSelection() {
        for (row, tip) in zip(rows, tips) {
            row.isChosen = tip == selected
        }
    }

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        var top: CGFloat = 0
        for (index, row) in rows.enumerated() {
            if index > 0 {
                separators[index - 1].pin
                    .top(top)
                    .start(TipRowView.textLeading)
                    .end()
                    .height(1 / max(traitCollection.displayScale, 1))
            }
            let height = row.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            row.pin
                .top(top)
                .horizontally()
                .height(height)
            top += height
        }
        return top
    }
}

// MARK: - TipRowView

private final class TipRowView: UIControl {

    // MARK: Static Properties

    static let textLeading: CGFloat = 16 + 24 + 12

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? .tertiarySystemFill : nil
        }
    }

    // MARK: Properties

    var isChosen = false {
        didSet {
            radioView.image = UIImage(systemName: isChosen ? "checkmark.circle.fill" : "circle")
            radioView.tintColor = isChosen ? .label : .tertiaryLabel
            accessibilityTraits = isChosen ? [.button, .selected] : .button
        }
    }

    private let radioView = UIImageView()
    private let titleLabel = Label()
    private let priceLabel = Label()

    // MARK: Lifecycle

    init(tip: Tip) {
        super.init(frame: .zero)

        radioView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .title3)
        radioView.contentMode = .center
        titleLabel.text = tip.title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = 0
        priceLabel.text = tip.price
        priceLabel.font = .preferredFont(forTextStyle: .body)
        priceLabel.adjustsFontForContentSizeCategory = true
        priceLabel.textColor = .secondaryLabel
        for view in [radioView, titleLabel, priceLabel] {
            view.isUserInteractionEnabled = false
            addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityLabel = ProfileKitStrings.Support.Tip.a11y(tip.title, tip.price)
        isChosen = false
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
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        priceLabel.pin
            .end(16)
            .sizeToFit()
        let titleWidth = max(width - Self.textLeading - priceLabel.frame.width - 16 - 12, 0)
        let titleHeight = titleLabel.sizeThatFits(CGSize(width: titleWidth, height: .greatestFiniteMagnitude)).height
        let height = max(52, ceil(titleHeight) + 28)
        titleLabel.pin
            .vCenter()
            .start(Self.textLeading)
            .width(titleWidth)
            .height(titleHeight)
        priceLabel.pin
            .vCenter()
            .end(16)
        radioView.pin
            .vCenter()
            .start(16)
            .size(24)
        return height
    }
}
