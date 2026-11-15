import PinLayout
public import UIKit

extension UIView {
    /// From here on PinLayout's start and end, and `layoutRow`, follow each view's own layout direction instead of
    /// PinLayout's default, left to right everywhere. Call it once, before anything lays out.
    public static func followLayoutDirection() {
        Pin.layoutDirection(.auto)
    }
}
