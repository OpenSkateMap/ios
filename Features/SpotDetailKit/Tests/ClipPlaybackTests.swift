import ComponentKit
import CustomDump
import Foundation
import SpotModelKit
import Testing
@testable import SpotDetailKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ClipPlaybackTests {
    private let playback = ClipPlayback()
    private let first = URL(string: "https://images.example/clips/first.mp4")!
    private let second = URL(string: "https://images.example/clips/second.mp4")!

    @Test
    func `the same clip in two views is one player`() {
        let card = ClipLayerView(revealDuration: 0)
        let viewer = ClipLayerView(revealDuration: 0)

        playback.show(first, in: card)
        playback.show(first, in: viewer)

        #expect(card.player != nil)
        #expect(card.player === viewer.player)
        #expect(card.player?.isPlaying == true)
    }

    @Test
    func `another clip replaces the player and takes it from every view`() {
        let card = ClipLayerView(revealDuration: 0)
        let viewer = ClipLayerView(revealDuration: 0)
        playback.show(first, in: card)

        playback.show(second, in: viewer)

        #expect(card.player == nil)
        expectNoDifference(viewer.player?.url, second)
    }

    @Test
    func `the player goes once the last view lets go`() {
        let card = ClipLayerView(revealDuration: 0)
        let viewer = ClipLayerView(revealDuration: 0)
        playback.show(first, in: card)
        playback.show(first, in: viewer)
        weak let player = card.player

        playback.release(viewer)
        #expect(player != nil)
        #expect(card.player === player)

        playback.release(card)
        #expect(player == nil)
    }

    @Test
    func `the cover page carries its photo's clip`() {
        let clip = SpotClip(key: "clips/cover.mp4", width: 1280, height: 720, durationMs: 8000)
        let spot = SpotIndex(
            id: "s",
            title: "Spot",
            kind: .street,
            condition: .skateable,
            cityID: nil,
            latitude: 1,
            longitude: 1,
            version: 1,
            coverKey: "photos/cover.jpg",
            coverThumbhash: "AAAA",
        )
        let photos = [
            SpotPhoto(
                id: "c",
                spotID: "s",
                key: "photos/cover.jpg",
                width: 4,
                height: 3,
                thumbhash: "AAAA",
                credit: nil,
                position: 0,
                clip: clip,
            ),
            SpotPhoto(
                id: "o",
                spotID: "s",
                key: "photos/other.jpg",
                width: 4,
                height: 3,
                thumbhash: "AAAA",
                credit: nil,
                position: 1,
            ),
        ]

        expectNoDifference(GalleryPhoto.pages(of: spot, photos: photos).map(\.clip), [clip, nil])
    }
}
