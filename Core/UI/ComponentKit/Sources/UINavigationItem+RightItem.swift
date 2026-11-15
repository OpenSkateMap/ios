public import UIKit

extension UINavigationItem {
    /// Only on a change: setting the same item again re-lays the bar out.
    public func showRightItem(_ item: UIBarButtonItem?) {
        if rightBarButtonItem !== item {
            rightBarButtonItem = item
        }
    }
}
