import AVFoundation
import Foundation
import Testing
@testable import ComponentKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct LoopingClipPlayerTests {
    private let clip = LoopingClipPlayer(url: URL(string: "https://images.example/clips/clip.mp4")!)

    @Test
    func `a rate set while paused waits for play`() {
        clip.rate = 0.5

        #expect(!clip.isPlaying)
        #expect(clip.player.rate == 0)

        clip.play()

        #expect(clip.isPlaying)
        #expect(clip.player.rate == 0.5)
    }

    @Test
    func `a rate set while playing keeps it playing, and a pause keeps the rate for the next play`() {
        clip.play()

        clip.rate = 0.5
        #expect(clip.isPlaying)
        #expect(clip.player.rate == 0.5)

        clip.pause()
        #expect(!clip.isPlaying)
        #expect(clip.player.rate == 0)

        clip.play()
        #expect(clip.player.rate == 0.5)

        clip.rate = 1
        #expect(clip.player.rate == 1)
    }
}
