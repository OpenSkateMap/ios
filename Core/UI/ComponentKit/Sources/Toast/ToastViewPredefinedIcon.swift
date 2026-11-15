import UIKit

public enum ToastViewPredefinedIcon: Sendable {
    case success
    case failure

    // MARK: Computed Properties

    @MainActor
    var icon: UIImage {
        let (name, color): (String, UIColor) =
            switch self {
            case .success: ("checkmark.square.fill", .systemGreen)
            case .failure: ("exclamationmark.triangle.fill", .systemRed)
            }
        return UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(hierarchicalColor: color)) ?? UIImage()
    }
}
