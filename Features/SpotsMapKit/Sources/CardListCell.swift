import UIKit

/// A list cell in Discover's card. List cells inset their content and margins by their own horizontal safe area; beside
/// the map the card's place already keeps clear of the sensor housing, and that inset is only the one iOS mirrors onto
/// the other side.
// swiftformat:disable:next preferFinalClasses
class CardListCell: UICollectionViewListCell {

    // MARK: Overridden Properties

    override var safeAreaInsets: UIEdgeInsets {
        let insets = super.safeAreaInsets
        guard traitCollection.placesCardBesideMap else {
            return insets
        }
        return UIEdgeInsets(top: insets.top, left: 0, bottom: insets.bottom, right: 0)
    }

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        // A rotation lays cells out before their size classes change; the new safe area alone doesn't lay them out again.
        registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (cell: CardListCell, _) in
            cell.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)

        let insetsFromSafeArea = !state.traitCollection.placesCardBesideMap
        insetsLayoutMarginsFromSafeArea = insetsFromSafeArea
        contentView.insetsLayoutMarginsFromSafeArea = insetsFromSafeArea
    }
}
