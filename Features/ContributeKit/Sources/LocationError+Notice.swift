import ComponentKit
import LocationKit
import UIKit

extension LocationError {
    /// Denied needs a way to Settings, so it asks; anything else is a toast.
    @MainActor
    func show(from presenter: UIViewController) {
        switch self {
        case .denied:
            let alert = UIAlertController(
                title: ContributeKitStrings.LocationAlert.Denied.title,
                message: ContributeKitStrings.LocationAlert.Denied.message,
                preferredStyle: .alert,
            )
            alert.addAction(UIAlertAction(title: ContributeKitStrings.Alert.cancel, style: .cancel))
            let settings = UIAlertAction(title: ContributeKitStrings.LocationAlert.Denied.settings, style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            alert.addAction(settings)
            alert.preferredAction = settings
            presenter.present(alert, animated: true)

        case .unavailable:
            ToastView.showFailure(
                ContributeKitStrings.LocationAlert.Unavailable.title,
                subtitle: ContributeKitStrings.LocationAlert.Unavailable.message,
            )
        }
    }
}
