import CustomDump
import Foundation
import Testing
@testable import SpotDetailKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct PhotoViewerShareTests {
    init() throws {
        try #require(Bundle.module.preferredLocalizations.first == "en", "These read SpotDetailKit's English strings")
    }

    @Test
    func `the text names the spot, then who took the photo or the clip`() {
        expectNoDifference(
            [
                PhotoViewerShare.text(spot: "Venice Ledges", credit: "Ana", isClip: false),
                PhotoViewerShare.text(spot: "Venice Ledges", credit: "Ana", isClip: true),
            ],
            ["Venice Ledges · Photo by Ana", "Venice Ledges · Video by Ana"],
        )
    }

    @Test
    func `without a credit the text is the spot's name`() {
        expectNoDifference(
            [
                PhotoViewerShare.text(spot: "Venice Ledges", credit: nil, isClip: false),
                PhotoViewerShare.text(spot: "Venice Ledges", credit: "", isClip: true),
            ],
            ["Venice Ledges", "Venice Ledges"],
        )
    }

    @Test
    func `a clip's file is named after the spot, without what a path can't hold`() {
        expectNoDifference(
            ["Venice Ledges", "Ledges 1/2: Back", " .hidden ", " . "].map(PhotoViewerShare.fileName(for:)),
            ["Venice Ledges", "Ledges 1-2- Back", "hidden", "OpenSkateMap"],
        )
    }
}
