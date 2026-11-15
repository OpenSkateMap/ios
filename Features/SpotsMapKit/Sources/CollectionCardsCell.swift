import ComponentKit
import PinLayout
import UIKit

// MARK: - CollectionCardsCell

final class CollectionCardsCell: UICollectionViewCell {

    // MARK: Static Properties

    private static let spacing: CGFloat = 12
    private static let inset: CGFloat = 16

    // MARK: Properties

    var onPick: ((String) -> Void)?
    var menu: ((String) -> UIMenu?)?

    private let scrollView = UIScrollView().softEdges()
    private var cards = [(id: String, view: CollectionCardView)]()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        setupViews()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        scrollView.pin
            .all()
        let unbounded = CGSize(width: CGFloat.greatestFiniteMagnitude, height: .greatestFiniteMagnitude)
        scrollView.layoutRow(
            cards.map(\.view),
            spacing: Self.spacing,
            insets: NSDirectionalEdgeInsets(top: 0, leading: Self.inset, bottom: 0, trailing: Self.inset),
        ) { $0.sizeThatFits(unbounded) }
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = cards.map { $0.view.sizeThatFits(.zero).height }.max() ?? 0
        return fitted
    }

    // MARK: Functions

    func show(_ shown: [CollectionCard]) {
        if cards.map(\.id) != shown.map(\.id) {
            for card in cards { card.view.removeFromSuperview() }
            cards = shown.map { card in
                let view = CollectionCardView()
                // A plain UIControl never sends its primary action itself.
                view.addAction(UIAction { [weak self] _ in self?.onPick?(card.id) }, for: .touchUpInside)
                view.addInteraction(UIContextMenuInteraction(delegate: self))
                scrollView.addSubview(view)
                return (card.id, view)
            }
        }
        let scale = traitCollection.displayScale
        for (card, entry) in zip(shown, cards) {
            entry.view.show(card, scale: scale)
        }
        setNeedsLayout()
    }

    private func setupViews() {
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        contentView.addSubview(scrollView)
    }
}

// MARK: UIContextMenuInteractionDelegate

extension CollectionCardsCell: UIContextMenuInteractionDelegate {
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                configurationForMenuAtLocation _: CGPoint) -> UIContextMenuConfiguration? {
        guard let id = cards.first(where: { $0.view === interaction.view })?.id, let menu = menu?(id) else {
            return nil
        }
        return UIContextMenuConfiguration(actionProvider: { _ in menu })
    }
}
