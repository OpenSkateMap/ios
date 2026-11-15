import ComponentKit
import PinLayout
import UIKit

final class NamePillView: UIView {

    // MARK: Static Properties

    private static let minimumHeight: CGFloat = 56

    // MARK: Properties

    let field = UITextField()

    var isEnabled = true {
        didSet {
            field.isEnabled = isEnabled
            field.textColor = isEnabled ? .label : .tertiaryLabel
        }
    }

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .tertiarySystemFill
        layer.cornerCurve = .continuous
        field.font = .preferredFont(forTextStyle: .title2, weight: .semibold)
        field.adjustsFontForContentSizeCategory = true
        addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.cornerRadius = bounds.height / 2
        field.pin
            .vertically(4)
            .horizontally(22)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let lineHeight = field.font?.lineHeight ?? 26
        return CGSize(width: size.width, height: max(Self.minimumHeight, ceil(lineHeight) + 24))
    }
}
