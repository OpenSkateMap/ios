public import UIKit

extension UIScrollView {
    /// iOS 27 made the hard edge style the default under bars, so every scroll view opts back in (lint `soft_scroll_edges`).
    @discardableResult
    public func softEdges() -> Self {
        for effect in [topEdgeEffect, bottomEdgeEffect, leftEdgeEffect, rightEdgeEffect] {
            effect.style = .soft
        }
        return self
    }
}
