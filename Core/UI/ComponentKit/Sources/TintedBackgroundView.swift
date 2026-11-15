public import UIKit

public final class TintedBackgroundView: UIView {

    // MARK: Overridden Properties

    override public static var layerClass: AnyClass {
        CAGradientLayer.self
    }

    // MARK: Properties

    public var tint: UIColor? {
        didSet {
            setNeedsUpdateProperties()
        }
    }

    // MARK: Lifecycle

    override public init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
    }

    override public func updateProperties() {
        super.updateProperties()

        guard let gradient = layer as? CAGradientLayer else {
            return
        }
        let base = UIColor.systemBackground.resolvedColor(with: traitCollection)
        guard let tint = tint?.resolvedColor(with: traitCollection) else {
            gradient.colors = [base.cgColor, base.cgColor]
            return
        }
        gradient.colors = [
            base.mixed(with: tint, amount: 0.5).cgColor,
            base.mixed(with: tint, amount: 0.22).cgColor,
        ]
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

}
