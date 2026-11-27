import CoreLocation
import Foundation
import SpotModelKit
import SQLiteData

// MARK: - NearYouRequest

/// The public spots around a point that photos would help most: the nearest, those without a photo first, leaving out
/// spots the person already has an edit on its way or waiting for.
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

    static let limit = 20

    /// About 55 km north and south, a city and its surroundings; east and west widen with the latitude.
    private static let reach = 0.5

    // MARK: Properties

    let origin: Origin?

    /// Unsent edits, and sent ones a curator hasn't decided: a pending submission with a spot is an edit.
    private static func spotsWithYourEdits(_ db: Database) throws -> Set<SpotIndex.ID> {
        let unsent = try SubmissionDraft.where { $0.editsSpotID.isNot(nil) }.select(\.editsSpotID).fetchAll(db)
        let waiting = try MySubmission
            .where { $0.status.eq(SubmissionStatus.pending) && $0.spotID.isNot(nil) }
            .select(\.spotID)
            .fetchAll(db)
        return Set((unsent + waiting).compactMap(\.self))
    }

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
        let edited = try Self.spotsWithYourEdits(db)
        let nearest = try SpotIndex
            .nearest(toLatitude: origin.latitude, longitude: origin.longitude, in: box, limit: Self.limit * 3)
            .fetchAll(db)
            .filter { !$0.isPrivate && $0.condition != .demolished }
        let open = nearest.filter { !edited.contains($0.id) }
        let picked = Array((open.filter { $0.coverKey == nil } + open.filter { $0.coverKey != nil }).prefix(Self.limit))
        let here = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let city = try nearest.first?.cityID.flatMap { id in try City.find(id).fetchOne(db) }
        return NearYou(
            spots: picked.map { spot in
                NearYou.Spot(
                    spot: spot,
                    distanceMeters: origin.isPersonal
                        ? Int(here.distance(from: CLLocation(latitude: spot.latitude, longitude: spot.longitude)))
                        : nil,
                    ask: NearYou.Ask(spot),
                )
            },
            cityName: city?.localizedName,
            hasOrigin: true,
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
        let ask: Ask?
    }

    /// The one true thing a card says about what the spot is missing, the most useful first.
    enum Ask: Equatable, Sendable {
        case noPhoto
        case noObstacles

        init?(_ spot: SpotIndex) {
            if spot.coverKey == nil {
                self = .noPhoto
            } else if spot.obstacles.isEmpty {
                self = .noObstacles
            } else {
                return nil
            }
        }
    }

    var spots = [Spot]()
    /// The city of the nearest spot.
    var cityName: String?
    /// Whether there was anywhere to look around: without it there's no "around here" to say anything about.
    var hasOrigin = false
}
