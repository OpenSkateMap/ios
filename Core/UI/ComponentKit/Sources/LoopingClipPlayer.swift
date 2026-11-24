public import AVFoundation
import UIKit

/// A muted clip on a loop, drawn by any number of `ClipLayerView`s at once; it goes when the last reference does.
public final class LoopingClipPlayer: NSObject {

    // MARK: Properties

    public let url: URL
    public private(set) var isPlaying = false

    let player = AVQueuePlayer()

    private let looper: AVPlayerLooper

    // MARK: Lifecycle

    public init(url: URL) {
        self.url = url
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil,
        )
    }

    // MARK: Functions

    public func play() {
        isPlaying = true
        player.play()
    }

    public func pause() {
        isPlaying = false
        player.pause()
    }

    @objc
    private func sceneWillEnterForeground() {
        if isPlaying {
            player.play()
        }
    }
}
