public import AVFoundation
import CoreImage
public import ImageKit
public import UIKit

// MARK: - LoopingClipPlayer

/// A clip on a loop, muted unless asked otherwise, drawn by any number of `ClipLayerView`s at once; it goes when the last
/// reference does. Given a cache, it plays the clip's file when the cache has it, and otherwise streams the clip while
/// the cache downloads it for next time.
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
    /// How fast the clip plays while it plays, 1 being as recorded; every loop keeps it, and a paused clip starts at it.
    public var rate: Float = 1 {
        didSet {
            player.defaultRate = rate
            if isPlaying {
                player.rate = rate
            }
        }
    }

    let player = AVQueuePlayer()

    private let cache: ClipCache?
    /// Decided once, so a playing clip's asset never changes under it.
    private let asset: Task<AVURLAsset, Never>
    private var looper: AVPlayerLooper?
    private var itemObservation: NSKeyValueObservation?

    // MARK: Lifecycle

    public init(url: URL, cache: ClipCache? = nil) {
        self.url = url
        self.cache = cache
        asset = Task { await AVURLAsset(url: cache?.beginPlaying(url) ?? url) }
        ClipSound.prepare()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        super.init()
        Task { [weak self, asset] in
            let asset = await asset.value
            self?.loop(asset)
        }
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
        if let cache {
            Task { [asset, url] in
                // After the asset, so the cache hears the play begin before it ends.
                _ = await asset.value
                await cache.endPlaying(url)
            }
        }
    }

    // MARK: Functions

    /// Whether the clip carries sound at all; a clip whose tracks can't be read counts as silent.
    public func hasSound() async -> Bool {
        let tracks = try? await asset.value.loadTracks(withMediaType: .audio)
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

    private func loop(_ asset: AVURLAsset) {
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(asset: asset))
        if isPlaying {
            player.play()
        }
    }

    private func addFrameOutputs() {
        for item in looper?.loopingPlayerItems ?? [] where item.outputs.isEmpty {
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
