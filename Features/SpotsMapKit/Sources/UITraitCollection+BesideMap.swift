import UIKit

extension UITraitCollection {

    var placesCardBesideMap: Bool {
        horizontalSizeClass == .regular || verticalSizeClass == .compact
    }
}
