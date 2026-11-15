public import CoreGraphics

/// Chips and tags in lines, a new line when the next one doesn't fit, each line as tall as its tallest. `x` runs from
/// the leading edge: pin with `start(frame.minX)`.
public enum FlowLayout {
    public static func frames(for sizes: [CGSize], width: CGFloat, spacing: CGFloat, centered: Bool = false) -> [CGRect] {
        var lines = [[CGSize]]()
        var lineWidth: CGFloat = 0
        for size in sizes {
            if let last = lines.last, !last.isEmpty, lineWidth + spacing + size.width <= width {
                lines[lines.count - 1].append(size)
                lineWidth += spacing + size.width
            } else {
                lines.append([size])
                lineWidth = size.width
            }
        }
        var frames = [CGRect]()
        var y: CGFloat = 0
        for line in lines {
            let total = line.reduce(-spacing) { $0 + $1.width + spacing }
            var x = centered ? max((width - total) / 2, 0) : 0
            for size in line {
                frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
                x += size.width + spacing
            }
            y += (line.map(\.height).max() ?? 0) + spacing
        }
        return frames
    }
}
