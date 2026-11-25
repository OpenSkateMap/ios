public import AVFoundation
import CoreImage
public import UIKit

// MARK: - LoopingClipPlayer

/// A clip on a loop, muted unless asked otherwise, drawn by any number of `ClipLayerView`s at once; it goes when the last
/// reference does.
public final class LoopingClipPlayer: NSObject {

    // MARK: Static Properties

    private static let frameContext = CIContext()

    // MARK: Computed Properties

    public var isMuted: Bool {
        get { player.isMuted }
        set { player.isMuted = newValue }
    }

    // MARK: Properties

    public let url: URL
    public private(set) var isPlaying = false

    let player = AVQueuePlayer()

    private let asset: AVURLAsset
    private let looper: AVPlayerLooper
    private var itemObservation: NSKeyValueObservation?

    // MARK: Lifecycle

    public init(url: URL) {
        self.url = url
        asset = AVURLAsset(url: url)
        ClipSound.prepare()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))
        super.init()
        // The looper makes its items after a moment, so each gets its frame output once the player moves to one.
        itemObservation = player.observe(\.currentItem, options: [.initial, .new]) { @Sendable [weak self] _, _ in
            Task { @MainActor in
                self?.addFrameOutputs()
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(resumeIfPlaying),
            name: UIScene.willEnterForegroundNotification,
            object: nil,
        )
        NotificationCenter.default.addObserver(self, selector: #selector(resumeIfPlaying), name: ClipSound.didSettle, object: nil)
    }

    isolated deinit {
        ClipSound.playerStopped(ObjectIdentifier(self))
    }

    // MARK: Functions

    /// Whether the clip carries sound at all; a clip whose tracks can't be read counts as silent.
    public func hasSound() async -> Bool {
        let tracks = try? await asset.loadTracks(withMediaType: .audio)
        return !(tracks ?? []).isEmpty
    }

    public func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
    }

    /// Hears where the clip is, in seconds, about every `interval`, for as long as the observation is kept.
    public func observePosition(every interval: Double,
                                _ handler: @escaping @MainActor @Sendable (Double) -> Void) -> ClipPositionObservation {
        let token = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: interval, preferredTimescale: 600),
            queue: .main,
        ) { time in
            MainActor.assumeIsolated {
                handler(time.seconds)
            }
        }
        return ClipPositionObservation(player: player, token: token)
    }

    public func play() {
        isPlaying = true
        ClipSound.playerStarted(ObjectIdentifier(self))
        player.play()
    }

    public func pause() {
        isPlaying = false
        ClipSound.playerStopped(ObjectIdentifier(self))
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
    private func resumeIfPlaying() {
        if isPlaying {
            play()
        }
    }
}

// MARK: - ClipPositionObservation

public final class ClipPositionObservation {

    // MARK: Properties

    private let player: AVPlayer
    private let token: Any

    // MARK: Lifecycle

    init(player: AVPlayer, token: Any) {
        self.player = player
        self.token = token
    }

    isolated deinit {
        player.removeTimeObserver(token)
    }
}
