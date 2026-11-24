public import UIKit

public final class LoopingVideoView: UIView {

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
    private let clipView = ClipLayerView(revealDuration: 0.6)

    // MARK: Lifecycle

    public init(url: URL?, poster: UIImage?) {
        self.url = url
        posterView = UIImageView(image: poster)
        super.init(frame: .zero)
        accessibilityElementsHidden = true
        posterView.contentMode = .scaleAspectFill
        posterView.clipsToBounds = true
        addSubview(posterView)
        addSubview(clipView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Overrides

    override public func layoutSubviews() {
        super.layoutSubviews()

        posterView.frame = bounds
        clipView.frame = bounds
    }

    // MARK: Functions

    private func renderPlayback() {
        if isPlaying {
            if clipView.player == nil, let url {
                clipView.player = LoopingClipPlayer(url: url)
            }
            clipView.player?.play()
        } else {
            clipView.player?.pause()
        }
    }
}
