public import UIKit

extension UIImage {
    /// The variant for `traits` as a plain image. A dynamic image (a map snapshot carries light and dark) is otherwise
    /// resolved again on every trait change of the view showing it, or by whatever traits are current where it's drawn,
    /// and on a glass sheet that has shown the light variant in dark mode.
    public func resolved(with traits: UITraitCollection) -> UIImage {
        guard let variant = imageAsset?.image(with: traits), let cgImage = variant.cgImage else {
            return self
        }
        return UIImage(cgImage: cgImage, scale: variant.scale, orientation: variant.imageOrientation)
    }
}
