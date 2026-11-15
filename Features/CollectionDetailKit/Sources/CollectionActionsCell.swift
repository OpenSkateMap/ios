import ComponentKit
import PinLayout
import UIKit

final class CollectionActionsCell: UICollectionViewCell {

    // MARK: Static Properties

    private static let inset: CGFloat = 20
    private static let spacing: CGFloat = 16
    private static let minimumHeight: CGFloat = 44

    // MARK: Properties

    var onShowOnMap: (() -> Void)?
    var onShare: (() -> Void)?

    var isShowOnMapEnabled = true {
        didSet { showOnMap.isEnabled = isShowOnMapEnabled }
    }

    private let showOnMap = UIButton(configuration: action(CollectionDetailKitStrings.Collection.showOnMap, symbol: "map.fill"))
    private let share = UIButton(configuration: action(
        CollectionDetailKitStrings.Collection.share,
        symbol: "square.and.arrow.up",
    ))

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

        for (button, frame) in zip([showOnMap, share], buttonFrames(width: contentView.bounds.width)) {
            button.pin
                .top(frame.minY)
                .start(safeAreaInsets)
                .size(frame.size)
                .marginStart(Self.inset + frame.minX)
        }
    }

    override func preferredLayoutAttributesFitting(_ attributes: UICollectionViewLayoutAttributes)
        -> UICollectionViewLayoutAttributes {
        let fitted = attributes.copy() as? UICollectionViewLayoutAttributes ?? attributes
        fitted.size.height = buttonFrames(width: attributes.size.width).map(\.maxY).max() ?? 0
        return fitted
    }

    // MARK: Static Functions

    private static func action(_ title: String, symbol: String) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.gray()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(textStyle: .subheadline, scale: .medium)
        configuration.imagePadding = 6
        configuration.cornerStyle = .capsule
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 11, leading: 12, bottom: 11, trailing: 12)
        configuration.titleLineBreakMode = .byTruncatingTail
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        return configuration
    }

    // MARK: Functions

    private func buttonFrames(width: CGFloat) -> [CGRect] {
        let row = width - safeAreaInsets.left - safeAreaInsets.right - Self.inset * 2
        return RowLayout.frames(
            for: [showOnMap, share],
            width: row,
            spacing: Self.spacing,
            stacks: traitCollection.preferredContentSizeCategory.isAccessibilityCategory,
            displayScale: traitCollection.displayScale,
        ) { button, width in
            max(Self.minimumHeight, ceil(button.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
        }
    }

    private func setupViews() {
        showOnMap.addAction(UIAction { [weak self] _ in self?.onShowOnMap?() }, for: .primaryActionTriggered)
        share.addAction(UIAction { [weak self] _ in self?.onShare?() }, for: .primaryActionTriggered)
        contentView.addSubview(showOnMap)
        contentView.addSubview(share)
    }
}
