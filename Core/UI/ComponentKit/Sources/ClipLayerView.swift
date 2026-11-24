public import AVFoundation
public import UIKit

/// Draws a `LoopingClipPlayer`, transparent until its first frame is ready, so whatever sits behind it (the poster)
/// shows instead of a black frame.
public final class ClipLayerView: UIView {

    // MARK: Overridden Properties

    override public static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    // MARK: Computed Properties

    public var videoGravity: AVLayerVideoGravity {
        get { playerLayer.videoGravity }
        set { playerLayer.videoGravity = newValue }
    }

    /// What it draws now; nil until its first frame shows, while whatever is behind it still does.
    public var currentFrame: UIImage? {
        alpha > 0 ? player?.currentFrame() : nil
    }

    private var playerLayer: AVPlayerLayer {
        // `layerClass` makes this layer an `AVPlayerLayer`.
        // swiftlint:disable:next force_cast
        layer as! AVPlayerLayer
    }

    // MARK: Properties

    public var player: LoopingClipPlayer? {
        didSet {
            if player !== oldValue {
                attach()
            }
        }
    }

    public var revealDuration: TimeInterval

    private var readyObservation: NSKeyValueObservation?

    // MARK: Lifecycle

    public init(revealDuration: TimeInterval) {
        self.revealDuration = revealDuration
        super.init(frame: .zero)
        alpha = 0
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        accessibilityIgnoresInvertColors = true
        playerLayer.videoGravity = .resizeAspectFill
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Functions

    private func attach() {
        readyObservation = nil
        layer.removeAllAnimations()
        alpha = 0
        playerLayer.player = player?.player
        guard let shown = player?.player else {
            return
        }
        readyObservation = playerLayer.observe(\.isReadyForDisplay, options: [.initial, .new]) {
            @Sendable [weak self] _, change in
            guard change.newValue == true else {
                return
            }
            Task { @MainActor in
                self?.reveal(shown)
            }
        }
    }

    private func reveal(_ shown: AVPlayer) {
        guard playerLayer.player === shown, readyObservation != nil else {
            return
        }
        readyObservation = nil
        UIView.animate(withDuration: revealDuration, delay: 0, options: [.curveEaseInOut, .beginFromCurrentState]) {
            self.alpha = 1
        }
    }
}
