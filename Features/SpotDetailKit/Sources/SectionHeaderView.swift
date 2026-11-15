import ComponentKit
import PinLayout
import UIKit

final class SectionHeaderView: UIView {

    // MARK: Properties

    private let label = Label()
    private let hairline = UIView()
    private let accessory: UIView?

    // MARK: Lifecycle

    init(title: String, accessory: UIView? = nil) {
        self.accessory = accessory
        super.init(frame: .zero)
        label.text = title
        label.font = .preferredFont(forTextStyle: .subheadline, weight: .semibold)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = .sheetSecondaryLabel
        label.accessibilityTraits = .header
        hairline.backgroundColor = .sheetSeparator
        addSubview(label)
        addSubview(hairline)
        if let accessory {
            addSubview(accessory)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        if let accessory {
            accessory.pin
                .end()
                .sizeToFit()
            label.pin
                .top()
                .start()
                .before(of: accessory)
                .marginEnd(12)
                .sizeToFit(.width)
            accessory.pin
                .vCenter(to: label.edge.vCenter)
        } else {
            label.pin
                .top()
                .horizontally()
                .sizeToFit(.width)
        }
        hairline.pin
            .below(of: label)
            .horizontally()
            .height(1 / traitCollection.displayScale)
            .marginTop(8)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let labelHeight = label.sizeThatFits(CGSize(width: size.width, height: .greatestFiniteMagnitude)).height
        let accessoryHeight = accessory?.sizeThatFits(size).height ?? 0
        return CGSize(width: size.width, height: ceil(max(labelHeight, accessoryHeight - 8)) + 9)
    }
}
