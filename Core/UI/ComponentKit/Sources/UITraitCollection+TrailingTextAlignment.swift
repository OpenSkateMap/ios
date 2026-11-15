public import UIKit

extension UITraitCollection {
    /// Text against the trailing edge, which `NSTextAlignment` has no case for.
    public var trailingTextAlignment: NSTextAlignment {
        layoutDirection == .rightToLeft ? .left : .right
    }
}
