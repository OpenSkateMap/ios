public import UIKit

extension UIButton.Configuration {
    public static func primaryCapsule(title: String) -> UIButton.Configuration {
        var configuration = capsule(title: title)
        configuration.baseBackgroundColor = .label
        configuration.baseForegroundColor = .inverseLabel
        return configuration
    }

    public static func secondaryCapsule(title: String) -> UIButton.Configuration {
        var configuration = capsule(title: title)
        configuration.baseBackgroundColor = .tertiarySystemFill
        configuration.baseForegroundColor = .label
        return configuration
    }

    private static func capsule(title: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 15, leading: 24, bottom: 15, trailing: 24)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline, compatibleWith: .current)
            return attributes
        }
        return configuration
    }
}

extension UIButton {
    public func capsuleHeight(fitting width: CGFloat) -> CGFloat {
        max(52, ceil(sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }
}
