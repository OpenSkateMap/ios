import ComponentKit
import PinLayout
import UIKit

final class FieldRowView: UIView {

    // MARK: Static Properties

    private static let inset: CGFloat = 14
    private static let iconSide: CGFloat = 24

    // MARK: Computed Properties

    private var stacksTitle: Bool {
        !titleLabel.isHidden && traitCollection.preferredContentSizeCategory.isAccessibilityCategory
    }

    private var fieldHeight: CGFloat {
        max(52, (textField.font?.lineHeight ?? 20) + 28)
    }

    private var textStart: CGFloat {
        iconView.isHidden ? Self.inset : Self.inset + Self.iconSide + 10
    }

    // MARK: Properties

    let textField = UITextField()

    private let iconView = UIImageView()
    private let titleLabel = Label()
    private let input = UIView()
    private let prefixLabel = Label()

    // MARK: Lifecycle

    /// `handle` is the prefix of a handle, username or link, which reads left to right in every language.
    init(title: String?, icon: UIImage? = nil, placeholder: String = "", handle: String? = nil) {
        super.init(frame: .zero)

        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 14
        layer.cornerCurve = .continuous
        iconView.image = icon
        iconView.tintColor = .label
        iconView.contentMode = .center
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(textStyle: .body)
        iconView.isHidden = icon == nil
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body, weight: .medium)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.linesAtAccessibilitySizes = 0
        titleLabel.isHidden = title == nil
        prefixLabel.text = handle
        prefixLabel.font = .preferredFont(forTextStyle: .body)
        prefixLabel.adjustsFontForContentSizeCategory = true
        prefixLabel.textColor = .secondaryLabel
        prefixLabel.isHidden = handle?.isEmpty ?? true
        prefixLabel.isAccessibilityElement = false
        textField.font = .preferredFont(forTextStyle: .body)
        textField.adjustsFontForContentSizeCategory = true
        textField.placeholder = placeholder
        textField.clearButtonMode = .whileEditing
        textField.accessibilityLabel = title
        if handle != nil {
            textField.runsLeftToRight()
        }
        input.addSubview(prefixLabel)
        input.addSubview(textField)
        for view in [iconView, titleLabel, input] {
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
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        guard stacksTitle else {
            layoutInline(width: width)
            return fieldHeight
        }
        iconView.pin
            .top(12 + ((titleLabel.font?.lineHeight ?? 24) - Self.iconSide) / 2)
            .start(Self.inset)
            .size(Self.iconSide)
        titleLabel.pin
            .top(12)
            .start(textStart)
            .width(width - textStart - Self.inset)
            .sizeToFit(.width)
        let fieldTop = titleLabel.frame.maxY
        let inputHeight = fieldHeight - 14
        input.pin
            .top(fieldTop)
            .start(Self.inset)
            .width(width - 24)
            .height(inputHeight)
        layoutInput()
        return fieldTop + inputHeight
    }

    private func layoutInline(width: CGFloat) {
        if !iconView.isHidden {
            iconView.pin
                .vCenter()
                .start(Self.inset)
                .size(Self.iconSide)
        }
        var start = textStart
        if !titleLabel.isHidden {
            titleLabel.pin
                .vCenter()
                .start(start)
                .width(min(110, width * 0.3))
                .sizeToFit(.width)
            start += min(110, width * 0.3) + 8
        }
        input.pin
            .vertically()
            .start(start)
            .end(10)
        layoutInput()
    }

    private func layoutInput() {
        guard !prefixLabel.isHidden else {
            textField.pin
                .all()
            return
        }
        // swiftlint:disable pinlayout_left_right - a handle starts with its prefix ("@") and reads left to right
        prefixLabel.pin
            .vCenter()
            .left()
            .sizeToFit()
        textField.pin
            .vertically()
            .left(to: prefixLabel.edge.right)
            .right()
            .marginLeft(1)
        // swiftlint:enable pinlayout_left_right
    }
}
