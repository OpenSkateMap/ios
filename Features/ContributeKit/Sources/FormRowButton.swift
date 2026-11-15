import ComponentKit
import PinLayout
import UIKit

final class FormRowButton: UIControl {

    // MARK: Types

    enum Accessory {
        case none
        case chevron
        case more
        case upDown

        var symbolName: String? {
            switch self {
            case .none: nil
            case .chevron: "chevron.forward"
            case .more: "ellipsis"
            case .upDown: "chevron.up.chevron.down"
            }
        }
    }

    // MARK: Overridden Properties

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? .tertiarySystemFill : .clear
        }
    }

    override var isEnabled: Bool {
        didSet {
            if isEnabled != oldValue {
                updateText()
            }
        }
    }

    // MARK: Computed Properties

    /// A row that can't be changed; a busy one shows its spinner instead.
    private var isDimmed: Bool {
        !isEnabled && !isBusy
    }

    // MARK: Properties

    var menu: UIMenu? {
        didSet {
            isContextMenuInteractionEnabled = menu != nil
        }
    }

    var isPlaceholder = false {
        didSet {
            updateText()
        }
    }

    var title: String {
        didSet {
            updateText()
        }
    }

    var subtitle: String? {
        didSet {
            updateText()
        }
    }

    var value: String? {
        didSet {
            updateText()
        }
    }

    var glyph: UIImage? {
        didSet {
            glyphView.image = glyph
            setNeedsLayout()
        }
    }

    var accessory: Accessory {
        didSet {
            accessoryView.image = accessory.symbolName.flatMap { UIImage(systemName: $0) }
            setNeedsLayout()
        }
    }

    /// Shown under the row at full width, inside the same button: one tap target and one menu for both.
    var attachedView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let attachedView {
                attachedView.isUserInteractionEnabled = false
                addSubview(attachedView)
            }
            setNeedsLayout()
        }
    }

    var titleLines = 1 {
        didSet {
            rowTitleLabel.numberOfLines = titleLines
        }
    }

    var isBusy = false {
        didSet {
            guard isBusy != oldValue else {
                return
            }
            if isBusy {
                spinner.startAnimating()
            } else {
                spinner.stopAnimating()
            }
            isEnabled = !isBusy
            updateText()
        }
    }

    private let glyphView = UIImageView()
    private let rowTitleLabel = Label()
    private let secondLineLabel = Label()
    private let valueLabel = Label()
    private let accessoryView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .medium)

    // MARK: Lifecycle

    init(glyph: UIImage?, title: String, accessory: Accessory = .chevron) {
        self.title = title
        self.glyph = glyph
        self.accessory = accessory
        super.init(frame: .zero)
        glyphView.image = glyph
        glyphView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        glyphView.contentMode = .center
        rowTitleLabel.font = .preferredFont(forTextStyle: .body)
        rowTitleLabel.adjustsFontForContentSizeCategory = true
        rowTitleLabel.linesAtAccessibilitySizes = 0
        secondLineLabel.font = .preferredFont(forTextStyle: .subheadline)
        secondLineLabel.adjustsFontForContentSizeCategory = true
        secondLineLabel.numberOfLines = 2
        secondLineLabel.linesAtAccessibilitySizes = 0
        valueLabel.font = .preferredFont(forTextStyle: .body)
        valueLabel.adjustsFontForContentSizeCategory = true
        valueLabel.linesAtAccessibilitySizes = 0
        accessoryView.image = accessory.symbolName.flatMap { UIImage(systemName: $0) }
        accessoryView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .footnote, scale: .medium)
        accessoryView.contentMode = .center
        spinner.hidesWhenStopped = true
        for view in [glyphView, rowTitleLabel, secondLineLabel, valueLabel, accessoryView, spinner] {
            view.isUserInteractionEnabled = false
            view.accessibilityElementsHidden = true
            addSubview(view)
        }
        isAccessibilityElement = true
        accessibilityTraits = .button
        // A control has no primary action of its own: a tap is it, as on a button, unless the tap opens the menu.
        addAction(UIAction { [weak self] _ in
            guard let self, menu == nil || !showsMenuAsPrimaryAction else {
                return
            }
            sendActions(for: .primaryActionTriggered)
        }, for: .touchUpInside)
        updateText()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func updateProperties() {
        super.updateProperties()

        valueLabel.textAlignment = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
            ? .natural
            : traitCollection.trailingTextAlignment
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    /// A UIButton's menu morphs out of the button and hides it; a control's menu opens over it.
    override func contextMenuInteraction(_: UIContextMenuInteraction,
                                         configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration? {
        menu.map { menu in UIContextMenuConfiguration(actionProvider: { _ in menu }) }
    }

    // MARK: Functions

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        let inset: CGFloat = 16
        let isAccessibilitySize = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let hasGlyph = glyphView.image != nil
        // One scaled slot for every row at accessibility sizes, so the titles line up whatever the symbol's width.
        let glyphSide = isAccessibilitySize
            ? UIFontMetrics(forTextStyle: .body).scaledValue(for: 28, compatibleWith: traitCollection).rounded(.up)
            : 24
        let textStart = hasGlyph ? inset + glyphSide + 12 : inset
        let hasAccessory = accessoryView.image != nil || isBusy
        let valueEnd = hasAccessory ? inset + 16 + 8 : inset
        let stacksValue = isAccessibilitySize && valueLabel.text != nil
        let valueWidth = valueLabel.text == nil || stacksValue ? 0 : min(valueLabel.sizeThatFits(.zero).width, width * 0.45)
        let textWidth = max(0, width - valueEnd - (valueWidth > 0 ? valueWidth + 12 : 0) - textStart)
        let column = [rowTitleLabel] + (secondLineLabel.isHidden ? [] : [secondLineLabel]) + (stacksValue ? [valueLabel] : [])
        let heights = column.map { $0.sizeThatFits(CGSize(width: textWidth, height: .greatestFiniteMagnitude)).height }
        let columnHeight = heights.reduce(0, +) + 2 * CGFloat(column.count - 1)
        let height = max(56, columnHeight + 28)
        var y = (height - columnHeight) / 2
        for (label, labelHeight) in zip(column, heights) {
            label.pin
                .top(y)
                .start(textStart)
                .width(textWidth)
                .height(labelHeight)
            y += labelHeight + 2
        }
        let glyphMidY = isAccessibilitySize ? rowTitleLabel.frame.minY + (rowTitleLabel.font?.lineHeight ?? 24) / 2 : height / 2
        glyphView.pin
            .top(glyphMidY - glyphSide / 2)
            .start(inset)
            .size(glyphSide)
        accessoryView.pin
            .top((height - 16) / 2)
            .end(inset)
            .size(16)
        if !stacksValue {
            valueLabel.pin
                .top()
                .end(valueEnd)
                .width(valueWidth)
                .height(height)
        }
        spinner.center = accessoryView.center
        guard let attachedView, !attachedView.isHidden else {
            return height
        }
        let attachedHeight = attachedView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        attachedView.frame = CGRect(x: 0, y: height, width: width, height: attachedHeight)
        return height + attachedHeight
    }

    private func updateText() {
        rowTitleLabel.text = title
        rowTitleLabel.textColor = isDimmed ? .tertiaryLabel : isPlaceholder ? .secondaryLabel : .label
        secondLineLabel.text = subtitle
        secondLineLabel.isHidden = subtitle == nil
        secondLineLabel.textColor = isDimmed ? .tertiaryLabel : .secondaryLabel
        valueLabel.text = value
        valueLabel.textColor = isDimmed ? .tertiaryLabel : .secondaryLabel
        glyphView.tintColor = isDimmed ? .tertiaryLabel : .secondaryLabel
        accessoryView.tintColor = .tertiaryLabel
        accessoryView.isHidden = isBusy || isDimmed
        attachedView?.alpha = isDimmed ? 0.4 : 1
        if isDimmed {
            accessibilityTraits.insert(.notEnabled)
        } else {
            accessibilityTraits.remove(.notEnabled)
        }
        accessibilityLabel = title
        accessibilityValue = [subtitle, value, isBusy ? ContributeKitStrings.FormRow.busy : nil].compactMap(\.self)
            .joined(separator: ", ")
        setNeedsLayout()
    }
}
