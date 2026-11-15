import Foundation
import MapKit

struct MapCamera: Equatable {

    // MARK: Nested Types

    enum Target {
        case region(MKCoordinateRegion)
        case planet(longitude: CLLocationDegrees)
    }

    enum Move {
        case jump
        case travel
    }

    // MARK: Properties

    let id = UUID()
    let target: Target
    let move: Move

    // MARK: Lifecycle

    init(region: MKCoordinateRegion, move: Move) {
        target = .region(region)
        self.move = move
    }

    init(planetAt longitude: CLLocationDegrees) {
        target = .planet(longitude: longitude)
        move = .jump
    }

    // MARK: Static Functions

    static func ==(lhs: MapCamera, rhs: MapCamera) -> Bool {
        lhs.id == rhs.id
    }
}
