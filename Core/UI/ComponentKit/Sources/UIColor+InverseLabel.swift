public import UIKit

extension UIColor {
    /// Not `.systemBackground`: on a glass sheet at a partial detent it resolves translucent and the content goes gray.
    public static let inverseLabel = UIColor { $0.userInterfaceStyle == .dark ? .black : .white }
}
