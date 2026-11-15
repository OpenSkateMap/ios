import ComponentKit
import UIKit

final class InsetLabel: Label {

    // MARK: Properties

    var insets = NSDirectionalEdgeInsets(top: 2, leading: 7, bottom: 2, trailing: 7) {
        didSet {
            setNeedsDisplay()
        }
    }

    // MARK: Overrides

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: physicalInsets(insets)))
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let horizontal = insets.leading + insets.trailing
        let fitted = super.sizeThatFits(CGSize(width: max(size.width - horizontal, 0), height: size.height))
        return CGSize(width: fitted.width + horizontal, height: fitted.height + insets.top + insets.bottom)
    }
}
