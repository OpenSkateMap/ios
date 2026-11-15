import UIKit

/// New Spot's photos: the first is the cover, centred on top; the rest follow in centred rows of five, small.
final class NewSpotPhotosLayout: UICollectionViewLayout {

    // MARK: Static Properties

    static let thumbnailSide: CGFloat = 64

    private static let spacing: CGFloat = 10
    private static let gapBelowCover: CGFloat = 14
    private static let perRow = 5

    // MARK: Overridden Properties

    override var collectionViewContentSize: CGSize {
        CGSize(width: width, height: Self.height(for: count, width: width))
    }

    // MARK: Properties

    private var frames = [CGRect]()
    private var width: CGFloat = 0
    private var count = 0

    // MARK: Overrides

    override func prepare() {
        super.prepare()

        width = collectionView?.bounds.width ?? 0
        count = collectionView.map { $0.numberOfSections > 0 ? $0.numberOfItems(inSection: 0) : 0 } ?? 0
        frames = Self.frames(for: count, width: width).map(mirroredForLayoutDirection)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        frames.indices
            .filter { frames[$0].intersects(rect) }
            .compactMap { layoutAttributesForItem(at: IndexPath(item: $0, section: 0)) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        guard indexPath.section == 0, frames.indices.contains(indexPath.item) else {
            return nil
        }
        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = frames[indexPath.item]
        return attributes
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != width
    }

    // MARK: Static Functions

    static func coverSide(width: CGFloat) -> CGFloat {
        min(width * 0.62, 280)
    }

    static func height(for count: Int, width: CGFloat) -> CGFloat {
        guard count > 0 else {
            return 0
        }
        let rows = CGFloat((count - 1 + perRow - 1) / perRow)
        let grid = rows > 0 ? gapBelowCover + rows * thumbnailSide + (rows - 1) * spacing : 0
        return coverSide(width: width) + grid
    }

    static func frames(for count: Int, width: CGFloat) -> [CGRect] {
        guard count > 0 else {
            return []
        }
        let side = coverSide(width: width)
        var frames = [CGRect(x: (width - side) / 2, y: 0, width: side, height: side)]
        for index in 1..<count {
            let row = (index - 1) / perRow
            let column = (index - 1) % perRow
            let inRow = min(perRow, count - 1 - row * perRow)
            let rowWidth = CGFloat(inRow) * thumbnailSide + CGFloat(inRow - 1) * spacing
            frames.append(CGRect(
                x: (width - rowWidth) / 2 + CGFloat(column) * (thumbnailSide + spacing),
                y: side + gapBelowCover + CGFloat(row) * (thumbnailSide + spacing),
                width: thumbnailSide,
                height: thumbnailSide,
            ))
        }
        return frames
    }

    // MARK: Functions

    /// Right to left the photos run from the right. Mirrored here, not with `flipsHorizontallyInOppositeLayoutDirection`:
    /// the reorder's lifted copy is a plain subview of the collection view, placed by these frames.
    private func mirroredForLayoutDirection(_ frame: CGRect) -> CGRect {
        guard collectionView?.effectiveUserInterfaceLayoutDirection == .rightToLeft else {
            return frame
        }
        return CGRect(x: width - frame.maxX, y: frame.minY, width: frame.width, height: frame.height)
    }
}
