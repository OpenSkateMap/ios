import ComponentKit
import PinLayout
import UIKit

final class FormToggleRowView: UIView {

    // MARK: Properties

    let toggle = UISwitch()

    private let label = Label()

    // MARK: Lifecycle

    init(title: String) {
        super.init(frame: .zero)

        label.text = title
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.isAccessibilityElement = false
        toggle.accessibilityLabel = title
        addSubview(label)
        addSubview(toggle)
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
        let toggleSize = toggle.sizeThatFits(.zero)
        let labelWidth = max(0, width - 16 - toggleSize.width - 12 - 16)
        let labelHeight = label.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height
        let height = max(56, labelHeight + 28)
        label.pin
            .top((height - labelHeight) / 2)
            .start(16)
            .width(labelWidth)
            .height(labelHeight)
        toggle.pin
            .top((height - toggleSize.height) / 2)
            .end(16)
            .size(toggleSize)
        return height
    }
}
