import CoreGraphics
public import UIKit

public actor ThumbHashRenderer {

    // MARK: Properties

    private let images = NSCache<NSString, UIImage>()

    // MARK: Lifecycle

    public init(capacity: Int = 500) {
        images.countLimit = capacity
    }

    // MARK: Static Functions

    public nonisolated static func averageColor(base64: String) -> UIColor? {
        guard let bytes = ThumbHash.bytes(fromBase64: base64), let color = ThumbHash.averageColor(of: bytes) else {
            return nil
        }
        return UIColor(red: color.red, green: color.green, blue: color.blue, alpha: color.alpha)
    }

    private static func render(_ pixels: ThumbHash.Pixels) -> UIImage? {
        let bytesPerRow = pixels.width * 4
        guard let provider = CGDataProvider(data: Data(pixels.rgba) as CFData),
              let image = CGImage(
                  width: pixels.width,
                  height: pixels.height,
                  bitsPerComponent: 8,
                  bitsPerPixel: 32,
                  bytesPerRow: bytesPerRow,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                  provider: provider,
                  decode: nil,
                  shouldInterpolate: true,
                  intent: .defaultIntent,
              ) else {
            return nil
        }
        return UIImage(cgImage: image)
    }

    // MARK: Functions

    public func image(base64: String) -> UIImage? {
        if let image = images.object(forKey: base64 as NSString) {
            return image
        }
        guard let bytes = ThumbHash.bytes(fromBase64: base64),
              let pixels = ThumbHash.decode(bytes),
              let image = Self.render(pixels) else {
            return nil
        }
        images.setObject(image, forKey: base64 as NSString)
        return image
    }
}
