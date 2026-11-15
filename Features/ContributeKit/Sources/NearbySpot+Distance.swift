import Foundation
import SpotModelKit

extension NearbySpot {
    var distanceText: String {
        Measurement(value: Double(distanceMeters), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
