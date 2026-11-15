import ComponentKit
import FactoryKit
import ImageKit
import SpotModelKit
import UIKit

@MainActor
struct CoverImages {

    // MARK: Static Properties

    static let side: CGFloat = 48

    // MARK: Properties

    @Injected(\.imageLoader) private var loader
    @Injected(\.photoURLBuilder) private var urls

    // MARK: Static Functions

    static func placeholder(thumbhash: String?,
                            symbol: String = "rectangle.stack.fill",
                            fallback: UIColor = .systemOrange) -> UIImage {
        let color = thumbhash.flatMap { ThumbHashRenderer.averageColor(base64: $0) } ?? fallback
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: side, height: side), cornerRadius: 10).fill()
            guard thumbhash == nil, let glyph = UIImage(
                systemName: symbol,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold),
            )?.withTintColor(.white, renderingMode: .alwaysOriginal) else {
                return
            }
            glyph.draw(at: CGPoint(x: (side - glyph.size.width) / 2, y: (side - glyph.size.height) / 2))
        }
    }

    static func tile(for face: CollectionFace, side: CGFloat = side, traits: UITraitCollection) -> UIImage {
        let tones = face.look.color.tones(for: traits)
        return UIImage.tile(
            glyph: UIImage(systemName: face.pictureSymbol),
            fill: .gradient([tones.center, tones.edge]),
            side: side,
            glyphScale: 0.5,
            traitCollection: traits,
        )
    }

    // MARK: Functions

    func cover(key: String?, scale: CGFloat) async -> UIImage? {
        guard let key, let url = urls.url(for: key, size: .pin, scale: scale) else {
            return nil
        }
        guard let image = try? await loader.photo(url, .pin) else {
            return nil
        }
        let size = CGSize(width: Self.side, height: Self.side)
        return UIGraphicsImageRenderer(size: size).image { _ in
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 10).addClip()
            let ratio = max(size.width / image.size.width, size.height / image.size.height)
            let drawn = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            image.draw(in: CGRect(
                x: (size.width - drawn.width) / 2,
                y: (size.height - drawn.height) / 2,
                width: drawn.width,
                height: drawn.height,
            ))
        }
    }
}
