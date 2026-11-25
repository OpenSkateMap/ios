import CustomDump
import Foundation
import Testing
@testable import ComponentKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ClipBadgeTests {
    init() throws {
        try #require(Bundle.module.preferredLocalizations.first == "en", "These read ComponentKit's English strings")
    }

    @Test
    func `a clip's length reads as minutes and seconds, rounded to the nearest second`() {
        expectNoDifference(
            [3000, 12400, 12500, 15999, 16000].map(ClipBadgeView.lengthText(milliseconds:)),
            ["0:03", "0:12", "0:13", "0:16", "0:16"],
        )
    }

    @Test
    func `VoiceOver hears that it's a video and how long it runs, in words`() {
        expectNoDifference(ClipBadgeView.accessibilityText(milliseconds: 12400), "Video, 12 seconds")
    }
}
