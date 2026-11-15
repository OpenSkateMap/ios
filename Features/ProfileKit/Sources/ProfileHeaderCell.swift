import AccountKit
import PeopleKit
import PinLayout
import UIKit

final class ProfileHeaderCell: UICollectionViewListCell {

    // MARK: Properties

    var onOpenURL: ((URL) -> Void)? {
        didSet { header.onOpenURL = onOpenURL }
    }

    private let header = ProfileHeaderView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundConfiguration = .clear()
        header.showsHandles = false
        header.tileColor = .secondarySystemGroupedBackground
        contentView.addSubview(header)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        layout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        contentView.frame.size.width = size.width
        layout()
        return CGSize(width: size.width, height: header.frame.maxY)
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = sizeThatFits(CGSize(width: attributes.size.width, height: .greatestFiniteMagnitude)).height
        return fitted
    }

    // MARK: Functions

    func show(_ profile: PublicProfile) {
        header.show(profile)
        setNeedsLayout()
    }

    func showPlaceholder(for account: Account?) {
        header.showPlaceholder(name: account?.name, badge: account?.roleBadge)
        setNeedsLayout()
    }

    private func layout() {
        header.pin
            .top()
            .horizontally()
            .sizeToFit(.width)
    }
}
