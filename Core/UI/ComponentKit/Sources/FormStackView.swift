import PinLayout
public import UIKit

public final class FormStackView: UIView {

    // MARK: Types

    struct Row {
        let view: UIView
        let height: CGFloat?
        let spacingBefore: CGFloat
    }

    // MARK: Properties

    private var rows = [Row]()

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        layoutRows(width: bounds.width)
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layoutRows(width: size.width))
    }

    // MARK: Functions

    public func add(_ view: UIView, height: CGFloat? = nil, spacingBefore: CGFloat = 12) {
        rows.append(Row(view: view, height: height, spacingBefore: spacingBefore))
        addSubview(view)
        setNeedsLayout()
    }

    @discardableResult
    private func layoutRows(width: CGFloat) -> CGFloat {
        var y: CGFloat = 0
        var first = true
        for row in rows where !row.view.isHidden {
            y += first ? 0 : row.spacingBefore
            first = false
            let height = row.height ?? row.view.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            row.view.pin
                .top(y)
                .start()
                .width(width)
                .height(height)
            y += height
        }
        return y
    }
}
