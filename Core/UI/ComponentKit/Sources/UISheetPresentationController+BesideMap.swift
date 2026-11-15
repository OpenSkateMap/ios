public import UIKit

extension UISheetPresentationController {
    /// On the leading edge in a wide window, beside the map; full width when narrow.
    public func placeBesideMap() {
        prefersEdgeAttachedInCompactHeight = true
        prefersPageSizing = false
        widthFollowsPreferredContentSizeWhenEdgeAttached = true
        if #available(iOS 27, *) {
            preferredPlacement = .leading
        }
    }
}
