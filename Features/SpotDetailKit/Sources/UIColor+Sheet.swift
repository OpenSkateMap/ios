import UIKit

extension UIColor {
    static let sheetSecondaryLabel = plain(.secondaryLabel)
    static let sheetTertiaryLabel = plain(.tertiaryLabel)
    static let sheetSecondaryFill = plain(.secondarySystemFill)
    static let sheetTertiaryFill = plain(.tertiarySystemFill)
    static let sheetSeparator = plain(.separator)

    /// A system colour resolved only by appearance, level and contrast. The sheet's glass changes a trait of its own
    /// on every expansion (the public traits stay equal), and the system colours resolved with it drew lighter until
    /// it changed back, about 0.35 s after the sheet settled.
    private static func plain(_ color: UIColor) -> UIColor {
        UIColor { traits in
            color.resolvedColor(with: UITraitCollection { mutable in
                mutable.userInterfaceStyle = traits.userInterfaceStyle
                mutable.userInterfaceLevel = traits.userInterfaceLevel
                mutable.accessibilityContrast = traits.accessibilityContrast
            })
        }
    }
}
