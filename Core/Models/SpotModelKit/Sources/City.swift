import Foundation
public import SQLiteData

// MARK: - City

@Table("city")
public struct City: Identifiable, Equatable, Sendable {
    public let id: String
    public var slug: String
    /// English, and what a language without its own name shows.
    public var name: String
    /// The name in each app language the server knows it in, keyed like `zh-Hans` and `ru`.
    @Column(as: [String: String].JSONRepresentation.self)
    public var names: [String: String]
    public var countryCode: String
    public var minLatitude: Double
    public var minLongitude: Double
    public var maxLatitude: Double
    public var maxLongitude: Double

    public init(id: String,
                slug: String,
                name: String,
                names: [String: String] = [:],
                countryCode: String,
                minLatitude: Double,
                minLongitude: Double,
                maxLatitude: Double,
                maxLongitude: Double) {
        self.id = id
        self.slug = slug
        self.name = name
        self.names = names
        self.countryCode = countryCode
        self.minLatitude = minLatitude
        self.minLongitude = minLongitude
        self.maxLatitude = maxLatitude
        self.maxLongitude = maxLongitude
    }
}

extension City {
    /// The name every screen shows: in the first of the person's languages the city has a name in.
    public var localizedName: String {
        localizedName(preferring: Locale.preferredLanguages)
    }

    public func localizedName(preferring languages: [String]) -> String {
        languages.lazy.compactMap { names[Self.nameKey(for: $0)] }.first ?? name
    }

    /// `zh-HK` is `zh-Hant` and `zh-SG` is `zh-Hans`: Chinese goes by script, every other language by its code.
    static func nameKey(for identifier: String) -> String {
        let language = Locale.Language(identifier: Locale.Language(identifier: identifier).maximalIdentifier)
        let code = language.languageCode?.identifier ?? identifier
        guard code == "zh", let script = language.script?.identifier else {
            return code
        }
        return "zh-\(script)"
    }
}
