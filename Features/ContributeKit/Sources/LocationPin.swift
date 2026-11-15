import UIKit

enum LocationPin {

    // MARK: Static Properties

    static let markerSize = CGSize(width: 30, height: 40)

    static let padding: CGFloat = 5

    static let image = makeImage()

    static var imageSize: CGSize {
        CGSize(width: markerSize.width + padding * 2, height: markerSize.height + padding * 2)
    }

    static var tip: CGPoint {
        CGPoint(x: imageSize.width / 2, y: padding + markerSize.height)
    }

    static var annotationCenterOffset: CGPoint {
        CGPoint(x: 0, y: imageSize.height / 2 - tip.y)
    }

    // MARK: Static Functions

    static func markerPath(in rect: CGRect) -> UIBezierPath {
        let radius = rect.width / 2
        let center = CGPoint(x: rect.midX, y: rect.minY + radius)
        let tip = CGPoint(x: rect.midX, y: rect.maxY)
        let spread = acos(radius / (tip.y - center.y))
        let right = CGFloat.pi / 2 - spread
        let left = CGFloat.pi / 2 + spread
        let path = UIBezierPath()
        path.move(to: tip)
        path.addLine(to: CGPoint(x: center.x + radius * cos(right), y: center.y + radius * sin(right)))
        path.addArc(withCenter: center, radius: radius, startAngle: right, endAngle: left, clockwise: false)
        path.close()
        return path
    }

    private static func makeImage() -> UIImage {
        let marker = CGRect(origin: CGPoint(x: padding, y: padding), size: markerSize)
        let image = UIGraphicsImageRenderer(size: imageSize).image { context in
            let cg = context.cgContext
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: 1.5), blur: 3, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            UIColor.systemRed.setFill()
            markerPath(in: marker).fill()
            cg.restoreGState()
            UIColor.black.withAlphaComponent(0.12).setStroke()
            let outline = markerPath(in: marker.insetBy(dx: 0.25, dy: 0.25))
            outline.lineWidth = 0.5
            outline.stroke()
            let dot: CGFloat = 11
            UIColor.white.setFill()
            UIBezierPath(ovalIn: CGRect(
                x: marker.midX - dot / 2,
                y: marker.minY + markerSize.width / 2 - dot / 2,
                width: dot,
                height: dot,
            )).fill()
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
}
