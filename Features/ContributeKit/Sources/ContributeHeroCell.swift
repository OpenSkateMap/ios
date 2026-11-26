import PinLayout
import UIKit

final class ContributeHeroCell: UICollectionViewCell {

    // MARK: Static Properties

    /// On top of the cell's margins, so the card lines up with the section headers and the other cards.
    private static let extraMargin: CGFloat = 8

    // MARK: Properties

    let hero = ContributeHeroView()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        contentView.addSubview(hero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        hero.pin
            .top(8)
            .horizontally(contentView.layoutMargins)
            .marginHorizontal(Self.extraMargin)
            .sizeToFit(.width)
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        let width = attributes.size.width - contentView.layoutMargins.left - contentView.layoutMargins.right - Self.extraMargin * 2
        fitted.size.height = hero.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height + 8
        return fitted
    }
}
