import ComponentKit
import PinLayout
import UIKit

final class SignInBackdropView: UIView {

    // MARK: Computed Properties

    var hasFootage: Bool {
        footageViews != nil
    }

    // MARK: Properties

    var isPlaying = false {
        didSet {
            if isPlaying != oldValue, let footageViews {
                footageViews.video.isPlaying = isPlaying
                footageViews.grain.isAnimating = isPlaying
            }
        }
    }

    var textTop: CGFloat = 0 {
        didSet {
            if textTop != oldValue {
                setNeedsLayout()
            }
        }
    }

    private let footageViews: (video: LoopingVideoView, grain: FilmGrainView)?
    private let topScrimLayer = CAGradientLayer()
    private let bottomScrimLayer = CAGradientLayer()

    // MARK: Lifecycle

    init(footage: SignInFootage?) {
        footageViews = footage.map { (LoopingVideoView(url: $0.video, poster: $0.poster), FilmGrainView()) }
        super.init(frame: .zero)

        backgroundColor = .black
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true

        topScrimLayer.colors = [0.62, 0.48, 0.26, 0.08, 0].map { UIColor.black.withAlphaComponent($0).cgColor }
        bottomScrimLayer.colors = [0, 0.06, 0.2, 0.42, 0.62, 0.76, 0.84].map {
            UIColor.black.withAlphaComponent($0).cgColor
        }

        if let footageViews {
            addSubview(footageViews.video)
            addSubview(footageViews.grain)
        }
        layer.addSublayer(topScrimLayer)
        layer.addSublayer(bottomScrimLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        if let footageViews {
            footageViews.video.pin
                .all()
            footageViews.grain.pin
                .all()
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        topScrimLayer.frame = CGRect(x: 0, y: 0, width: bounds.width, height: min(230, bounds.height / 3.5))
        let scrimTop = max(0, textTop - 120)
        bottomScrimLayer.frame = CGRect(x: 0, y: scrimTop, width: bounds.width, height: bounds.height - scrimTop)
        CATransaction.commit()
    }
}
