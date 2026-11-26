import CoreLocation
import Foundation
import SpotModelKit
import SQLiteData

/// The public spots around a point that photos would help most: the nearest, those without a photo first.
nonisolated struct NearYouRequest: FetchKeyRequest, Hashable {

    // MARK: Nested Types

    struct Origin: Hashable, Sendable {
        var latitude: Double
        var longitude: Double
        /// Where the person is, rather than where they last looked at the map: only then is a distance theirs.
        var isPersonal: Bool

        /// To about 100 m, so a fix that moves a few metres doesn't reload the list.
        static func rounded(latitude: Double, longitude: Double, isPersonal: Bool) -> Origin {
            Origin(
                latitude: (latitude * 1000).rounded() / 1000,
                longitude: (longitude * 1000).rounded() / 1000,
                isPersonal: isPersonal,
            )
        }
    }

    // MARK: Static Properties

    static let limit = 10
    /// About 11 km north and south; east and west widen with the latitude.
    private static let reach = 0.1

    // MARK: Properties

    let origin: Origin?

    // MARK: Functions

    func fetch(_ db: Database) throws -> NearYou {
        guard let origin else {
            return NearYou()
        }
        let east = Self.reach / max(cos(origin.latitude * .pi / 180), 0.1)
        let box = CoordinateBox(
            south: origin.latitude - Self.reach,
            west: origin.longitude - east,
            north: origin.latitude + Self.reach,
            east: origin.longitude + east,
        )
        let nearest = try SpotIndex
            .nearest(toLatitude: origin.latitude, longitude: origin.longitude, in: box, limit: Self.limit * 3)
            .fetchAll(db)
            .filter { !$0.isPrivate && $0.condition != .demolished }
        let picked = Array((nearest.filter { $0.coverKey == nil } + nearest.filter { $0.coverKey != nil }).prefix(Self.limit))
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let city = try nearest.first?.cityID.flatMap { id in try City.find(id).fetchOne(db) }
        return NearYou(
            spots: picked.map { spot in
                NearYou.Spot(
                    spot: spot,
                    distanceMeters: origin.isPersonal
                        ? Int(here.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude)))
                        : nil,
                )
            },
            cityName: city?.localizedName,
        )
    }
}

// MARK: - NearYou

nonisolated struct NearYou: Equatable, Sendable {
    struct Spot: Identifiable, Equatable, Sendable {
        var id: SpotIndex.ID {
            spot.id
        }

        let spot: SpotIndex
        let distanceMeters: Int?
    }

    var spots = [Spot]()
    /// The city of the nearest spot.
    var cityName: String?
}
