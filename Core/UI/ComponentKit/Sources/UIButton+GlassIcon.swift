public import UIKit

extension UIButton.Configuration {
    public static func glassIcon(_ systemName: String,
                                 textStyle: UIFont.TextStyle? = nil,
                                 scale: UIImage.SymbolScale = .default) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.glass()
        configuration.image = UIImage(systemName: systemName)
        configuration.cornerStyle = .capsule
        if let textStyle {
            configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: textStyle, scale: scale)
        }
        return configuration
    }
}
