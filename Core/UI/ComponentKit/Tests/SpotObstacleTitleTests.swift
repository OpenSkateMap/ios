import CustomDump
import Foundation
import SpotModelKit
import Testing
@testable import ComponentKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct SpotObstacleTitleTests {
    init() throws {
        try #require(Bundle.module.preferredLocalizations.first == "en", "These read ComponentKit's English strings")
    }

    @Test
    func `in English a common obstacle reads as stored in a list and capitalized on a chip`() {
        let stored = SpotObstacle.common

        expectNoDifference(stored.map(SpotObstacle.name(of:)), stored)
        expectNoDifference(stored.map(SpotObstacle.title(of:)), stored.map(\.capitalized))
    }

    @Test
    func `a common obstacle stored in another case still gets its name`() {
        expectNoDifference(SpotObstacle.title(of: "MANUAL PADS"), "Manual Pads")
        expectNoDifference(SpotObstacle.name(of: "Ledges"), "ledges")
    }

    @Test
    func `in English a spelling variant of a common obstacle stays as stored`() {
        expectNoDifference(SpotObstacle.title(of: "gap"), "Gap")
        expectNoDifference(SpotObstacle.name(of: "bowls"), "bowls")
    }

    @Test
    func `an obstacle someone typed stays as typed, capitalized only on a chip`() {
        expectNoDifference(SpotObstacle.name(of: "pole jam"), "pole jam")
        expectNoDifference(SpotObstacle.title(of: "pole jam"), "Pole Jam")
    }
}
