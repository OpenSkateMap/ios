import MapKit
import SpotModelKit
import UIKit

enum DirectionsApp: CaseIterable {
    case appleMaps
    case googleMaps
    case yandexMaps

    // MARK: Computed Properties

    var title: String {
        switch self {
        case .appleMaps: "Apple Maps"
        case .googleMaps: "Google Maps"
        case .yandexMaps: "Yandex Maps"
        }
    }

    // MARK: Functions

    func open(to spot: SpotIndex, in scene: UIWindowScene?) {
        let destination = String(format: "%.6f,%.6f", spot.latitude, spot.longitude)
        let link: String
        switch self {
        case .appleMaps:
            let item = MKMapItem(location: CLLocation(latitude: spot.latitude, longitude: spot.longitude), address: nil)
            item.name = spot.title
            item.openInMaps(
                launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault],
                from: scene,
            )
            return

        case .googleMaps:
            link = "https://www.google.com/maps/dir/?api=1&destination=\(destination)"

        case .yandexMaps:
            link = "https://yandex.com/maps/?rtext=~\(destination)&rtt=auto"
        }
        if let url = URL(string: link) {
            scene?.open(url, options: nil)
        }
    }
}
