public import CoreGraphics

/// Pieces side by side in a row, all as tall as the tallest, or stacked at full width, each as tall as it measures.
/// Sizes round up to whole pixels, as PinLayout rounds them, so the gaps between pieces stay exact. `x` runs from the
/// leading edge: pin with `start(frame.minX)`.
public enum RowLayout {
    public static func frames<Item>(for items: [Item],
                                    width: CGFloat,
                                    spacing: CGFloat,
                                    stacks: Bool,
                                    displayScale: CGFloat,
                                    height: (Item, _ width: CGFloat) -> CGFloat) -> [CGRect] {
        let scale = max(displayScale, 1)
        let pixels = { (length: CGFloat) in (length * scale).rounded(.up) / scale }
        guard stacks else {
            let share = (width - spacing * CGFloat(items.count - 1)) / CGFloat(items.count)
            let itemWidth = pixels(share)
            let rowHeight = pixels(items.map { height($0, share) }.max() ?? 0)
            return items.indices.map { index in
                CGRect(x: CGFloat(index) * (itemWidth + spacing), y: 0, width: itemWidth, height: rowHeight)
            }
        }
        var y: CGFloat = 0
        return items.map { item in
            let frame = CGRect(x: 0, y: y, width: width, height: pixels(height(item, width)))
            y = frame.maxY + spacing
            return frame
        }
    }
}
