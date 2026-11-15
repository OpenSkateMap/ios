public import UIKit

public enum ToastViewEvent: Equatable {
    case hidden
    case icon(icon: UIImage, title: String, subtitle: String? = nil)
    case loading(title: String, subtitle: String? = nil)

    // MARK: Static Functions

    @MainActor
    public static func icon(predefinedIcon: ToastViewPredefinedIcon, title: String, subtitle: String? = nil) -> Self {
        .icon(icon: predefinedIcon.icon, title: title, subtitle: subtitle)
    }
}
