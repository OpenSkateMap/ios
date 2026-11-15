public import UIKit

extension UITextField {
    /// Handles, usernames and links read left to right in any language.
    public func runsLeftToRight() {
        semanticContentAttribute = .forceLeftToRight
        // swiftlint:disable:next pinlayout_left_right - `.natural` aligns an empty field's placeholder by the app's language
        textAlignment = .left
    }
}
