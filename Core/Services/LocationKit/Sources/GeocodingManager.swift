public import CoreLocation
import MapKit

// MARK: - GeocodingManager

public struct GeocodingManager: Sendable {
    public var address: @Sendable (_ coordinate: CLLocationCoordinate2D) async -> String?
    public var place: @Sendable (_ coordinate: CLLocationCoordinate2D) async -> PlaceName?

    public init(address: @escaping @Sendable (_ coordinate: CLLocationCoordinate2D) async -> String?,
                place: @escaping @Sendable (_ coordinate: CLLocationCoordinate2D) async -> PlaceName?) {
        self.address = address
        self.place = place
    }
}

// MARK: - PlaceName

public struct PlaceName: Equatable, Sendable {
    public var city: String?
    public var region: String?

    public init(city: String?, region: String?) {
        self.city = city
        self.region = region
    }
}

extension GeocodingManager {
    public static let live = GeocodingManager(
        address: { coordinate in
            await mapItem(at: coordinate)?.addressRepresentations?.fullAddress(includingRegion: false, singleLine: true)
        },
        place: { coordinate in
            guard let names = await mapItem(at: coordinate)?.addressRepresentations,
                  names.cityName != nil || names.regionName != nil else {
                return nil
            }
            return PlaceName(city: names.cityName, region: names.regionName)
        },
    )

    public static let preview = GeocodingManager(
        address: { _ in "Belvedere Road, London SE1 8XX" },
        place: { _ in PlaceName(city: "London", region: "United Kingdom") },
    )

    private static func mapItem(at coordinate: CLLocationCoordinate2D) async -> MKMapItem? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let request = MKReverseGeocodingRequest(location: location) else {
            return nil
        }
        return try? await request.mapItems.first
    }
}
