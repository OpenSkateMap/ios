public import UIKit

extension UIImage {

    // MARK: Types

    public enum TileFill {
        case color(UIColor)
        case gradient([UIColor])
    }

    // MARK: Static Functions

    /// `side` defaults to 29 pt, iOS's settings-icon size, scaled with the text size as those are.
    public static func tile(glyph: UIImage?,
                            fill: TileFill,
                            side: CGFloat? = nil,
                            glyphScale: CGFloat = 0.6,
                            tintsGlyph: Bool = true,
                            traitCollection: UITraitCollection = .current) -> UIImage {
        let side = side ?? defaultSide(for: traitCollection)
        let format = UIGraphicsImageRendererFormat(for: traitCollection)
        let bounds = CGRect(x: 0, y: 0, width: side, height: side)
        let image = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            let shape = UIBezierPath(roundedRect: bounds, cornerRadius: side * 0.2237)
            context.cgContext.saveGState()
            shape.addClip()
            let colors: [UIColor]
            let start: CGPoint
            let end: CGPoint
            switch fill {
            case .color(let color):
                let base = color.resolvedColor(with: traitCollection)
                colors = [base.mixed(with: .white, amount: 0.12), base.mixed(with: .black, amount: 0.06)]
                start = CGPoint(x: bounds.midX, y: bounds.minY)
                end = CGPoint(x: bounds.midX, y: bounds.maxY)

            case .gradient(let stops):
                colors = stops.map { $0.resolvedColor(with: traitCollection) }
                start = CGPoint(x: bounds.minX, y: bounds.maxY)
                end = CGPoint(x: bounds.maxX, y: bounds.minY)
            }
            if let gradient = CGGradient(colorsSpace: nil, colors: colors.map(\.cgColor) as CFArray, locations: nil) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: start,
                    end: end,
                    options: [.drawsBeforeStartLocation, .drawsAfterEndLocation],
                )
            }
            shape.lineWidth = 2 / format.scale
            UIColor.white.withAlphaComponent(0.14).setStroke()
            shape.stroke()
            context.cgContext.restoreGState()
            guard let glyph, glyph.size.width > 0, glyph.size.height > 0 else {
                return
            }
            let drawn = tintsGlyph ? glyph.withTintColor(.white, renderingMode: .alwaysOriginal) : glyph
            let box = side * glyphScale
            let fit = min(box / drawn.size.width, box / drawn.size.height)
            let scale = glyph.isSymbolImage ? min(fit, 1) : fit
            let size = CGSize(width: drawn.size.width * scale, height: drawn.size.height * scale)
            drawn.draw(in: CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height,
            ))
        }
        return image.withRenderingMode(.alwaysOriginal)
    }

    public static func symbolTile(systemName: String,
                                  color: UIColor,
                                  side: CGFloat? = nil,
                                  traitCollection: UITraitCollection = .current) -> UIImage {
        let side = side ?? defaultSide(for: traitCollection)
        let symbol = UIImage(
            systemName: systemName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: side * 0.55, weight: .semibold),
        )
        return tile(glyph: symbol, fill: .color(color), side: side, traitCollection: traitCollection)
    }

    private static func defaultSide(for traitCollection: UITraitCollection) -> CGFloat {
        UIFontMetrics(forTextStyle: .body).scaledValue(for: 29, compatibleWith: traitCollection).rounded()
    }
}
