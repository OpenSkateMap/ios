import PinLayout
public import UIKit

extension UIView {
    /// Leading and trailing as left and right in the direction PinLayout gives `start` here (`isLTR()`).
    public func physicalInsets(_ directional: NSDirectionalEdgeInsets) -> UIEdgeInsets {
        let isLTR = isLTR()
        return UIEdgeInsets(
            top: directional.top,
            left: isLTR ? directional.leading : directional.trailing,
            bottom: directional.bottom,
            right: isLTR ? directional.trailing : directional.leading,
        )
    }
}
