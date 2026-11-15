import UIKit

final class CenterPinView: UIView {

    // MARK: Static Properties

    private static let lift: CGFloat = 14

    // MARK: Properties

    private let pinView = UIImageView(image: LocationPin.image)
    private let groundView = UIView()
    private var isLifted = false

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        isAccessibilityElement = false
        groundView.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        groundView.alpha = 0
        addSubview(groundView)
        addSubview(pinView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        pinView.bounds = CGRect(origin: .zero, size: LocationPin.imageSize)
        pinView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        let tip = LocationPin.tip
        groundView.frame = CGRect(x: tip.x - 5, y: tip.y - 2, width: 10, height: 4)
        groundView.layer.cornerRadius = 2
    }

    override func sizeThatFits(_: CGSize) -> CGSize {
        LocationPin.imageSize
    }

    // MARK: Functions

    func placeTip(at point: CGPoint) {
        let size = LocationPin.imageSize
        frame = CGRect(x: point.x - LocationPin.tip.x, y: point.y - LocationPin.tip.y, width: size.width, height: size.height)
    }

    func setLifted(_ lifted: Bool) {
        guard lifted != isLifted, !UIAccessibility.isReduceMotionEnabled else {
            return
        }
        isLifted = lifted
        if lifted {
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .beginFromCurrentState]) {
                self.pinView.transform = CGAffineTransform(translationX: 0, y: -Self.lift)
                self.groundView.alpha = 1
            }
        } else {
            UIView.animate(
                withDuration: 0.4,
                delay: 0,
                usingSpringWithDamping: 0.55,
                initialSpringVelocity: 0.6,
                options: [.beginFromCurrentState],
            ) {
                self.pinView.transform = .identity
                self.groundView.alpha = 0
            }
        }
    }
}
