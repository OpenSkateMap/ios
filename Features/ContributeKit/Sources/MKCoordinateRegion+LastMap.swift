import MapKit

extension MKCoordinateRegion {
    /// The Map tab's last camera, as SpotsMapKit stores it; nil before the map has moved.
    static var storedLastMap: MKCoordinateRegion? {
        guard let values = UserDefaults.standard.array(forKey: "map.region") as? [Double], values.count == 4 else {
            return nil
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: values[0], longitude: values[1]),
            span: MKCoordinateSpan(latitudeDelta: values[2], longitudeDelta: values[3]),
        )
    }

    static func lastMap(maxSpan: CLLocationDegrees = 0.05) -> MKCoordinateRegion {
        guard let stored = storedLastMap else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276),
                span: MKCoordinateSpan(latitudeDelta: maxSpan, longitudeDelta: maxSpan),
            )
        }
        return MKCoordinateRegion(
            center: stored.center,
            span: MKCoordinateSpan(
                latitudeDelta: min(stored.span.latitudeDelta, maxSpan),
                longitudeDelta: min(stored.span.longitudeDelta, maxSpan),
            ),
        )
    }
}
