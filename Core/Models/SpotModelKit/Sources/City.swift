public import SQLiteData

@Table("city")
public struct City: Identifiable, Equatable, Sendable {
    public let id: String
    public var slug: String
    public var name: String
    public var countryCode: String
    public var minLatitude: Double
    public var minLongitude: Double
    public var maxLatitude: Double
    public var maxLongitude: Double

    public init(id: String,
                slug: String,
                name: String,
                countryCode: String,
                minLatitude: Double,
                minLongitude: Double,
                maxLatitude: Double,
                maxLongitude: Double) {
        self.id = id
        self.slug = slug
        self.name = name
        self.countryCode = countryCode
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }
}
