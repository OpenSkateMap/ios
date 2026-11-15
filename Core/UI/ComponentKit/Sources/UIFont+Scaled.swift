public import UIKit

extension UIFont {
    /// `.current` is the traits UIKit is resolving for (a button's title transformer runs with its own).
    public static func preferredFont(forTextStyle style: TextStyle,
                                     weight: Weight,
                                     compatibleWith traits: UITraitCollection = .current) -> UIFont {
        let defaultSize = UIFontDescriptor
            .preferredFontDescriptor(
                withTextStyle: style,
                compatibleWith: UITraitCollection(preferredContentSizeCategory: .large),
            )
            .pointSize
        return UIFontMetrics(forTextStyle: style).scaledFont(
            for: .systemFont(ofSize: defaultSize, weight: weight),
            compatibleWith: traits,
        )
    }
}
