import CustomDump
import Foundation
import MapKit
import SpotModelKit
import Testing
@testable import SpotsMapKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SpotSearchTests {
    @Test
    func `the LIKE pattern takes the query's own wildcards literally`() {
        expectNoDifference(SpotSearchModel.pattern("50% off_ramp"), "%50\\% off\\_ramp%")
        expectNoDifference(SpotSearchModel.pattern("back\\slash"), "%back\\\\slash%")
    }

    @Test
    func `names starting with the query come first, then the nearest`() {
        let center = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1)
        let spots = [
            spot("far", title: "Old South Bank", latitude: 51.9),
            spot("near", title: "The South Ledges", latitude: 51.5),
            spot("prefix", title: "Southbank Undercroft", latitude: 52.5),
        ]

        let ranked = SpotSearchModel.ranked(spots, query: "south", center: center)

        expectNoDifference(ranked.map(\.id), ["prefix", "near", "far"])
    }

    @Test
    func `recently viewed keeps one entry per spot, newest first, at most twenty`() throws {
        let suite = "SpotSearchTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let recent = RecentSpots(defaults: defaults)

        for index in 0..<25 {
            recent.add("spot-\(index)")
        }
        recent.add("spot-10")

        expectNoDifference(recent.ids.count, 20)
        expectNoDifference(Array(recent.ids.prefix(3)), ["spot-10", "spot-24", "spot-23"])
        expectNoDifference(recent.ids.count(where: { $0 == "spot-10" }), 1)

        recent.clear()
        expectNoDifference(recent.ids, [])
    }

    private func spot(_ id: String, title: String, latitude: Double) -> SpotIndex {
        SpotIndex(
            id: id,
            title: title,
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: latitude,
            longitude: -0.1,
            version: 1,
        )
    }
}
