import MapKit

extension MKCoordinateRegion {
    static func lastMap(maxSpan: CLLocationDegrees = 0.05) -> MKCoordinateRegion {
        guard let values = UserDefaults.standard.array(forKey: "map.region") as? [Double], values.count == 4 else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.5072, longitude: -0.1276),
                span: MKCoordinateSpan(latitudeDelta: maxSpan, longitudeDelta: maxSpan),
            )
        }
        return MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: values[0], longitude: values[1]),
            span: MKCoordinateSpan(latitudeDelta: min(values[2], maxSpan), longitudeDelta: min(values[3], maxSpan)),
        )
    }
}
