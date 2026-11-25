import SpotModelKit

/// What Discover lists: one of our cities, or, outside them all, the spots in view under the place's name.
enum DiscoverPlace: Equatable {
    case city(City)
    case area(name: String, box: CoordinateBox)

    // MARK: Computed Properties

    var name: String {
        switch self {
        case .city(let city):
            city.localizedName

        case .area(let name, _):
            name
        }
    }
}
