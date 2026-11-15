import ComponentKit
import UIKit

/// Shadows are baked in, never live layer shadows, so a map of pins costs the render server nothing.
enum PinArt {

    // MARK: Types

    private struct Key: Hashable {
        let selected: Bool
        let scale: CGFloat
    }

    // MARK: Static Properties

    static let side: CGFloat = 44
    static let cornerRadius: CGFloat = 12
    static let border: CGFloat = 2
    static let shadowInset: CGFloat = 8

    private static var frames = [Key: UIImage]()

    // MARK: Static Functions

    static func titleLabel() -> Label {
        let label = Label()
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 2
        return label
    }

    static func title(_ text: String, traits: UITraitCollection) -> NSAttributedString {
        let halo = NSShadow()
        halo.shadowColor = UIColor.systemBackground.resolvedColor(with: traits)
        halo.shadowBlurRadius = 3
        halo.shadowOffset = .zero
        return NSAttributedString(string: text, attributes: [.shadow: halo])
    }

    static func frame(selected: Bool, scale: CGFloat) -> UIImage {
        let key = Key(selected: selected, scale: scale)
        if let image = frames[key] {
            return image
        }
        let canvas = CGSize(width: side + shadowInset * 2, height: side + shadowInset * 2)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: canvas, format: format).image { context in
            let card = CGRect(x: shadowInset, y: shadowInset, width: side, height: side)
            let path = UIBezierPath(roundedRect: card, cornerRadius: cornerRadius)
            context.cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 6,
                color: UIColor.black.withAlphaComponent(0.3).cgColor,
            )
            (selected ? UIColor.tintColor : UIColor.white).setFill()
            path.fill()
        }
        frames[key] = image
        return image
    }
}
