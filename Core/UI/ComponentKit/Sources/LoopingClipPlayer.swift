public import AVFoundation
import CoreImage
public import UIKit

/// A muted clip on a loop, drawn by any number of `ClipLayerView`s at once; it goes when the last reference does.
public final class LoopingClipPlayer: NSObject {

    // MARK: Static Properties

    private static let frameContext = CIContext()

    // MARK: Properties

    public let url: URL
    public private(set) var isPlaying = false

    let player = AVQueuePlayer()

    private let looper: AVPlayerLooper
    private var itemObservation: NSKeyValueObservation?

    // MARK: Lifecycle

    public init(url: URL) {
        self.url = url
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        super.init()
        // The looper makes its items after a moment, so each gets its frame output once the player moves to one.
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { @Sendable [weak self] _, _ in
            Task { @MainActor in
                self?.addFrameOutputs()
            }
        }
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

    /// The frame on screen now, to stand in for the clip where a view can't play it (a transition's flying copy).
    public func currentFrame() -> UIImage? {
        guard let item = player.currentItem,
              let output = item.outputs.lazy.compactMap({ $0 as? AVPlayerItemVideoOutput }).first,
              let buffer = output.copyPixelBuffer(forItemTime: item.currentTime(), itemTimeForDisplay: nil) else {
            return nil
        }
        let frame = CIImage(cvPixelBuffer: buffer)
        return Self.frameContext.createCGImage(frame, from: frame.extent).map { UIImage(cgImage: $0) }
    }

    private func addFrameOutputs() {
        for item in looper.loopingPlayerItems where item.outputs.isEmpty {
            item.add(AVPlayerItemVideoOutput(pixelBufferAttributes: nil))
        }
    }

    @objc
    private func sceneWillEnterForeground() {
        if isPlaying {
            player.play()
        }
    }
}
