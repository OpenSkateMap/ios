import CoreGraphics
import Foundation
import ImageIO
import ImageKit
import UniformTypeIdentifiers

enum PhotoPreparation {

    // MARK: Types

    enum Failure: Error, Equatable {
        case unreadable
        case encoding
    }

    // MARK: Static Properties

    /// Plenty for a full-screen photo on any iPhone; about 1 MB as a JPEG.
    static let maxPixelSize = 2048
    static let quality = 0.82

    // MARK: Static Functions

    @concurrent
    static func prepare(_ data: Data, maxPixelSize: Int = PhotoPreparation.maxPixelSize) async throws -> PreparedPhoto {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw Failure.unreadable
        }
        // A thumbnail "with transform" applies the EXIF orientation to the pixels: the result is upright.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadable
        }
        let jpeg = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(jpeg, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw Failure.encoding
        }
        // Only a quality setting: no source properties (location, device, time) are passed on.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(destination), let thumbhash = thumbHash(of: image) else {
            throw Failure.encoding
        }
        return PreparedPhoto(jpeg: jpeg as Data, width: image.width, height: image.height, thumbhash: thumbhash)
    }

    static func thumbHash(of image: CGImage) -> String? {
        let scale = min(1, 100 / Double(max(image.width, image.height)))
        let width = max(1, Int((Double(image.width) * scale).rounded()))
        let height = max(1, Int((Double(image.height) * scale).rounded()))
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: width * 4,
                  space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
              ),
              let pixels = context.data else {
            return nil
        }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let rgba = Array(UnsafeBufferPointer(start: pixels.assumingMemoryBound(to: UInt8.self), count: width * height * 4))
        return ThumbHash.encode(width: width, height: height, rgba: rgba).map { Data($0).base64EncodedString() }
    }
}
