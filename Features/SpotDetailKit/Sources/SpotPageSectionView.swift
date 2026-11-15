import ComponentKit
import PinLayout
import UIKit

final class SpotPageSectionView: UIView {

    // MARK: Properties

    private let stack = FormStackView()
    private let rows: [UIView]

    // MARK: Lifecycle

    init(title: String, accessory: UIView? = nil, rows: [(view: UIView, height: CGFloat?)]) {
        self.rows = rows.map(\.view)
        super.init(frame: .zero)
        stack.add(SectionHeaderView(title: title, accessory: accessory))
        for (index, row) in rows.enumerated() {
            stack.add(row.view, height: row.height, spacingBefore: index == 0 ? 10 : 12)
        }
        addSubview(stack)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        stack.pin
            .all()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        stack.sizeThatFits(size)
    }

    // MARK: Functions

    func updateVisibility() {
        isHidden = rows.allSatisfy(\.isHidden)
        stack.setNeedsLayout()
    }
}
