public import FactoryKit

extension Container {
    public var locationManager: Factory<LocationManager> {
        self { .live }.singleton.onPreview { .preview }
    }

    public var geocodingManager: Factory<GeocodingManager> {
        self { .live }.singleton.onPreview { .preview }
    }
}
