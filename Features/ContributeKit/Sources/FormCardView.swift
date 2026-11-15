import PinLayout
import UIKit

final class FormCardView: UIView {

    // MARK: Properties

    private let rows: [UIView]
    private let separators: [UIView]

    // MARK: Lifecycle

    init(rows: [UIView]) {
        self.rows = rows
        separators = rows.dropFirst().map { _ in
            let line = UIView()
            line.backgroundColor = .separator
            line.isUserInteractionEnabled = false
            return line
        }
        super.init(frame: .zero)
        backgroundColor = .tertiarySystemFill
        layer.cornerRadius = 24
        layer.cornerCurve = .continuous
        clipsToBounds = true
        for view in rows + separators {
            addSubview(view)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout(width: bounds.width)
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: layout(width: size.width))
    }

    // MARK: Functions

    @discardableResult
    private func layout(width: CGFloat) -> CGFloat {
        var y: CGFloat = 0
        var previousVisible = false
        for (index, row) in rows.enumerated() {
            let separator = index > 0 ? separators[index - 1] : nil
            guard !row.isHidden else {
                separator?.isHidden = true
                continue
            }
            let hairline = 1 / max(traitCollection.displayScale, 1)
            separator?.isHidden = !previousVisible
            if previousVisible, let separator {
                separator.pin
                    .top(y)
                    .start(52)
                    .width(width - 52)
                    .height(hairline)
            }
            let height = row.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
            row.pin
                .top(y)
                .start()
                .width(width)
                .height(height)
            y += height
            previousVisible = true
        }
        return y
    }
}
