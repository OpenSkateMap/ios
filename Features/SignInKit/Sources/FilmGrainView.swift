import UIKit

// MARK: - FilmGrainView

final class FilmGrainView: UIView {

    // MARK: Static Properties

    private static let tileSide = 128

    private static let framesPerSecond: Double = 12

    private static let tile: UIImage = makeTile()

    private static let offsets: [CGPoint] = {
        var generator = SeededGenerator(seed: 0x6A1D)
        let side = CGFloat(tileSide)
        return (0..<10).map { _ in
            CGPoint(x: .random(in: 0..<side, using: &generator).rounded(), y: .random(in: 0..<side, using: &generator).rounded())
        }
    }()

    private static let animationKey = "grain"

    // MARK: Properties

    var isAnimating = false {
        didSet {
            if isAnimating != oldValue {
                renderAnimation()
            }
        }
    }

    private let grainLayer = CALayer()

    // MARK: Lifecycle

    override init(frame: CGRect) {
        super.init(frame: frame)

        isUserInteractionEnabled = false
        clipsToBounds = true
        grainLayer.backgroundColor = UIColor(patternImage: Self.tile).cgColor
        layer.addSublayer(grainLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Overrides

    override func layoutSubviews() {
        super.layoutSubviews()

        let side = CGFloat(Self.tileSide)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        grainLayer.bounds = CGRect(x: 0, y: 0, width: bounds.width + side, height: bounds.height + side)
        grainLayer.anchorPoint = .zero
        grainLayer.position = CGPoint(x: -side, y: -side)
        CATransaction.commit()
        if grainLayer.animation(forKey: Self.animationKey) == nil {
            renderAnimation()
        }
    }

    // MARK: Static Functions

    private static func makeTile() -> UIImage {
        let side = tileSide
        let maximumAlpha = 0.2
        var generator = SeededGenerator(seed: 0x5EED)
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        for index in 0..<(side * side) {
            let value = Double.random(in: 0..<1, using: &generator)
            let strength = abs(value - 0.5) * 2
            let alpha = UInt8((strength * strength * maximumAlpha * 255).rounded())
            let level = value > 0.5 ? alpha : 0
            pixels[index * 4] = level
            pixels[index * 4 + 1] = level
            pixels[index * 4 + 2] = level
            pixels[index * 4 + 3] = alpha
        }
        let image = pixels.withUnsafeMutableBytes { buffer in
            CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
            )?.makeImage()
        }
        guard let image else {
            return UIImage()
        }
        return UIImage(cgImage: image, scale: 1, orientation: .up)
    }

    // MARK: Functions

    private func renderAnimation() {
        let key = Self.animationKey
        guard isAnimating, !bounds.isEmpty else {
            grainLayer.removeAnimation(forKey: key)
            return
        }
        let side = CGFloat(Self.tileSide)
        let animation = CAKeyframeAnimation(keyPath: "position")
        animation.values = Self.offsets.map { NSValue(cgPoint: CGPoint(x: -side + $0.x, y: -side + $0.y)) }
        animation.calculationMode = .discrete
        animation.duration = Double(Self.offsets.count) / Self.framesPerSecond
        animation.repeatCount = .infinity
        // Kept across the app going to the background and back.
        animation.isRemovedOnCompletion = false
        grainLayer.add(animation, forKey: key)
    }
}

// MARK: - SeededGenerator

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}
