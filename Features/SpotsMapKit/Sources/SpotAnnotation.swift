import MapKit
import SpotModelKit

final class SpotAnnotation: NSObject, MKAnnotation {

    // MARK: Computed Properties

    var title: String? {
        spot.title
    }

    // MARK: Properties

    let id: String
    @objc dynamic var coordinate: CLLocationCoordinate2D
    private(set) var spot: SpotIndex

    // MARK: Lifecycle

    init(_ spot: SpotIndex) {
        id = spot.id
        self.spot = spot
        coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
    }

    // MARK: Functions

    func update(_ spot: SpotIndex) {
        self.spot = spot
        let coordinate = CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
        if coordinate.latitude != self.coordinate.latitude || coordinate.longitude != self.coordinate.longitude {
            self.coordinate = coordinate
        }
    }
}
