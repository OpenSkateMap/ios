import ComponentKit
import PinLayout
import UIKit

final class ActionTilesView: UIView {

    // MARK: Static Properties

    private static let spacing: CGFloat = 8

    // MARK: Computed Properties

    private var tiles: [UIButton] {
        [directions, share, more]
    }

    private var stacks: Bool {
        Self.stacks(in: traitCollection)
    }

    // MARK: Properties

    let directions = UIButton(configuration: tile(
        title: SpotDetailKitStrings.Spot.Actions.directions,
        symbol: "arrow.trianglehead.turn.up.right.diamond.fill",
        primary: true,
    ))
    let share = UIButton(configuration: tile(
        title: SpotDetailKitStrings.Spot.Actions.share,
        symbol: "square.and.arrow.up",
        primary: false,
    ))
    let more = UIButton(configuration: tile(title: SpotDetailKitStrings.Spot.Actions.more, symbol: "ellipsis", primary: false))

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        for tile in tiles {
            tile.configurationUpdateHandler = { [weak self] in self?.update($0) }
            addSubview(tile)
        }
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        for (tile, frame) in zip(tiles, tileFrames(width: bounds.width)) {
            tile.pin
                .top(frame.minY)
                .start(frame.minX)
                .size(frame.size)
        }
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        CGSize(width: size.width, height: tileFrames(width: size.width).map(\.maxY).max() ?? 0)
    }

    // MARK: Static Functions

    /// HIG Typography: fewer columns at accessibility sizes, so the tiles become rows.
    private static func stacks(in traits: UITraitCollection) -> Bool {
        traits.preferredContentSizeCategory.isAccessibilityCategory
    }

    private static func tile(title: String, symbol: String, primary: Bool) -> UIButton.Configuration {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        configuration.image = UIImage(systemName: symbol)
        configuration.cornerStyle = .large
        configuration.baseBackgroundColor = primary ? .label : .tertiarySystemFill
        configuration.baseForegroundColor = primary ? .inverseLabel : .label
        return configuration
    }

    // MARK: Functions

    private func tileFrames(width: CGFloat) -> [CGRect] {
        let rowHeight = UIFontMetrics(forTextStyle: .footnote).scaledValue(for: 64, compatibleWith: traitCollection)
        return RowLayout.frames(
            for: tiles,
            width: width,
            spacing: Self.spacing,
            stacks: stacks,
            displayScale: traitCollection.displayScale,
        ) { tile, width in
            stacks ? tile.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height : rowHeight
        }
    }

    /// Reads the tile's own traits, which UIKit tracks for its update handler.
    private func update(_ tile: UIButton) {
        let stacks = Self.stacks(in: tile.traitCollection)
        var configuration = tile.configuration
        configuration?.imagePlacement = stacks ? .leading : .top
        configuration?.imagePadding = stacks ? 12 : 6
        configuration?.contentInsets = stacks
            ? NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
            : UIButton.Configuration.filled().contentInsets
        let font = UIFont.preferredFont(forTextStyle: .footnote, weight: .semibold)
        configuration?.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
            var attributes = $0
            attributes.font = font
            return attributes
        }
        tile.configuration = configuration
        tile.contentHorizontalAlignment = stacks ? .leading : .center
    }
}
