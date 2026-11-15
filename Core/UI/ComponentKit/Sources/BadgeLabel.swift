public import UIKit

public final class BadgeLabel: Label {

    // MARK: Properties

    private let insets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)

    // MARK: Overrides

    override public func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: insets))
    }

    override public func sizeThatFits(_ size: CGSize) -> CGSize {
        let fitted = super.sizeThatFits(CGSize(width: size.width - insets.left - insets.right, height: size.height))
        return CGSize(width: fitted.width + insets.left + insets.right, height: fitted.height + insets.top + insets.bottom)
    }

    override public func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
    }
}
