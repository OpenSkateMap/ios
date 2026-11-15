import Foundation
public import SQLiteData

extension SpotIndex {
    public static let viewportLimit = 2000

    public static func inViewport(_ box: CoordinateBox, matching filter: SpotFilter = SpotFilter()) -> SelectOf<SpotIndex> {
        within(box).matching(filter).order { $0.version.desc() }.limit(viewportLimit)
    }

    /// The spots in `box` nearest to a point, by distance on a flat map scaled for its latitude.
    public static func nearest(toLatitude latitude: Double,
                               longitude: Double,
                               in box: CoordinateBox,
                               limit: Int) -> SelectOf<SpotIndex> {
        let scale = cos(latitude * .pi / 180)
        return within(box).order {
            #sql("""
                (\($0.latitude) - \(latitude)) * (\($0.latitude) - \(latitude)) \
                + (\($0.longitude) - \(longitude)) * \(scale) * (\($0.longitude) - \(longitude)) * \(scale)
                """)
        }
        .limit(limit)
    }

    public static func within(_ box: CoordinateBox) -> Where<SpotIndex> {
        if box.crossesAntimeridian {
            SpotIndex.where {
                $0.latitude.between(box.south, and: box.north) && ($0.longitude.gte(box.west) || $0.longitude.lte(box.east))
            }
        } else {
            SpotIndex.where {
                $0.latitude.between(box.south, and: box.north) && $0.longitude.between(box.west, and: box.east)
            }
        }
    }

    public static func inCity(_ cityID: City.ID, matching filter: SpotFilter = SpotFilter()) -> some Statement<CitySpot> {
        ranked(SpotIndex.where { $0.cityID.eq(cityID) }.matching(filter))
    }

    public static func inArea(_ box: CoordinateBox, matching filter: SpotFilter = SpotFilter()) -> some Statement<CitySpot> {
        ranked(within(box).matching(filter))
    }

    /// Not limited to a city or the viewport: a collection's spots.
    public static func listed(matching filter: SpotFilter) -> some Statement<CitySpot> {
        ranked(SpotIndex.where { _ in true }.matching(filter))
    }

    private static func ranked(_ spots: Where<SpotIndex>) -> some Statement<CitySpot> {
        // Typed step by step: the chain in one expression takes the type checker minutes.
        let scored: Select<Void, SpotIndex, SpotScore?> = spots.leftJoin(SpotScore.all) {
            (spot: SpotIndex.TableColumns, score: SpotScore.TableColumns) in spot.id.eq(score.id)
        }
        let ranked: Select<Void, SpotIndex, SpotScore?> = scored.order {
            (spot: SpotIndex.TableColumns, score: SpotScore?.TableColumns) in
            (score.score.ifnull(0.0).desc(), spot.title.collate(.nocase))
        }
        return ranked.select { (spot: SpotIndex.TableColumns, score: SpotScore?.TableColumns) in
            CitySpot.Columns(spot: spot, score: score)
        }
    }
}

// MARK: - CitySpot

@Selection
public struct CitySpot: Identifiable, Equatable, Sendable {

    // MARK: Computed Properties

    public var id: SpotIndex.ID {
        spot.id
    }

    // MARK: Properties

    public let spot: SpotIndex
    public let score: SpotScore?
}
