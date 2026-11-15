public import UIKit

extension UIWindow {

    /// The window's edge the device's top (and its sensor housing) faces: top when upright, left or right on its side.
    /// Read from the window's geometry, which a rotation's layout and trait changes already have; the scene's
    /// interface orientation updates later.
    public var deviceTopEdge: UIRectEdge? {
        guard let fixed = windowScene?.screen.fixedCoordinateSpace else {
            return nil
        }
        let top = fixed.convert(CGPoint(x: fixed.bounds.midX, y: 0), to: self)
        switch top {
        case _ where top.x < 1: return .left
        case _ where top.x > bounds.width - 1: return .right
        case _ where top.y < 1: return .top
        case _ where top.y > bounds.height - 1: return .bottom
        default: return nil
        }
    }
}
