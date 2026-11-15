import CustomDump
import Testing
@testable import SpotModelKit

@Suite(.timeLimit(.minutes(1)))
struct SpotObstacleTests {
    @Test
    func `a spot's own spelling stands in for its common chip, and others follow`() {
        let choices = SpotObstacle.choices(including: ["gap", "Ledges", "bowls", "pole jam"])

        expectNoDifference(choices.filter { !SpotObstacle.common.contains($0) }, ["Ledges", "gap", "bowls", "pole jam"])
        expectNoDifference(choices.count, SpotObstacle.common.count + 1)
    }

    @Test
    func `a stored obstacle is its common one whatever its case or plural "s"`() {
        expectNoDifference(SpotObstacle.Common(stored: "Gap"), .gaps)
        expectNoDifference(SpotObstacle.Common(stored: "bowls"), .bowl)
        expectNoDifference(SpotObstacle.Common(stored: "MANUAL PADS"), .manualPads)
        expectNoDifference(SpotObstacle.Common(stored: "pole jam"), nil)
    }
}
