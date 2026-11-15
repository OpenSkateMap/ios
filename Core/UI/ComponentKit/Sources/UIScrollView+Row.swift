// The assertion reads `Pin.layoutDirection`, a static var from before Swift concurrency.
@preconcurrency import PinLayout
public import UIKit

extension UIScrollView {
    /// `content` as a horizontally scrolling row from the leading edge, each view at `size(view)`, `spacing` apart
    /// inside `insets`, and `contentSize` to match. The views go in from the left; right to left the scroll view
    /// flips and each view flips back, so offsets, paging and snapping keep their left-to-right math. (UICollectionView
    /// flips its layout's coordinates instead, without a transform.)
    public func layoutRow(_ content: [UIView],
                          spacing: CGFloat,
                          insets: NSDirectionalEdgeInsets = .zero,
                          size: (UIView) -> CGSize) {
        assert(Pin.layoutDirection == .auto, "The row flips by each view's direction: call UIView.followLayoutDirection()")
        let sizes = content.map(size)
        let flip = isLTR() ? CGAffineTransform.identity : CGAffineTransform(scaleX: -1, y: 1)
        transform = flip
        var x = insets.leading
        // swiftlint:disable pinlayout_left_right - the row runs from the left of the scroll view, which flips as a whole
        for (view, size) in zip(content, sizes) {
            view.transform = flip
            view.pin
                .top(insets.top)
                .left(x)
                .size(size)
            x += size.width + spacing
        }
        // swiftlint:enable pinlayout_left_right
        let width = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(sizes.count - 1, 0))
        let height = sizes.map(\.height).max() ?? 0
        contentSize = CGSize(
            width: insets.leading + width + insets.trailing,
            height: insets.top + height + insets.bottom,
        )
    }
}
