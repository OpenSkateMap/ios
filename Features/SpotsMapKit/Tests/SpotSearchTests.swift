import CustomDump
import Foundation
import Testing
@testable import SpotsMapKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SpotSearchTests {
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
}
