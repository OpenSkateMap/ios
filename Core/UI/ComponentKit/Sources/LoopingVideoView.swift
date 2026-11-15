public import AVFoundation
public import UIKit

public final class LoopingVideoView: UIView {

    // MARK: Types

    private final class PlayerView: UIView {

        // MARK: Overridden Properties

        override static var layerClass: AnyClass {
            AVPlayerLayer.self
        }

        // MARK: Computed Properties

        var playerLayer: AVPlayerLayer {
            // `layerClass` makes this layer an `AVPlayerLayer`.
            // swiftlint:disable:next force_cast
            layer as! AVPlayerLayer
        }
    }

    // MARK: Properties

    public var isPlaying = false {
        didSet {
            if isPlaying != oldValue {
                renderPlayback()
            }
        }
    }

    private let url: URL?
    private let posterView: UIImageView
    private let playerView = PlayerView()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var readyObservation: NSKeyValueObservation?

    // MARK: Lifecycle

    public init(url: URL?, poster: UIImage?) {
        self.url = url
        posterView = UIImageView(image: poster)
        super.init(frame: .zero)
        accessibilityElementsHidden = true
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        playerView.playerLayer.videoGravity = .resizeAspectFill
        playerView.alpha = 0
        addSubview(posterView)
        addSubview(playerView)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(sceneWillEnterForeground),
            name: UIScene.willEnterForegroundNotification,
            object: nil,
        )
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        posterView.frame = bounds
        playerView.frame = bounds
    }

    // MARK: Functions

    private func renderPlayback() {
        if isPlaying {
            (player ?? makePlayer())?.play()
        } else {
            player?.pause()
        }
    }

    private func makePlayer() -> AVQueuePlayer? {
        guard let url else {
            return nil
        }
        let player = AVQueuePlayer()
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        playerView.playerLayer.player = player
        readyObservation = playerView.playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) {
            @Sendable [weak self] _, change in
            guard change.newValue == true else {
                return
            }
            Task { @MainActor in
                self?.revealPlayer()
            }
        }
        self.player = player
        return player
    }

    private func revealPlayer() {
        readyObservation = nil
        UIView.animate(withDuration: 0.6, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.playerView.alpha = 1
        }
    }

    @objc
    private func sceneWillEnterForeground() {
        if isPlaying {
            player?.play()
        }
    }
}
