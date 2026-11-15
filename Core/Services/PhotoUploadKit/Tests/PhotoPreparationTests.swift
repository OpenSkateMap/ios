import CoreGraphics
import CustomDump
import Foundation
import ImageIO
import ImageKit
import Testing
import UniformTypeIdentifiers
@testable import PhotoUploadKit

@Suite(.timeLimit(.minutes(1)))
struct PhotoPreparationTests {
    @Test
    func `a sideways photo comes out upright, with no location or device metadata`() async throws {
        // 40×20 pixels stored sideways: EXIF orientation 6 means "rotate 90° clockwise to show".
        let source = try jpeg(width: 40, height: 20, properties: [
            kCGImagePropertyOrientation: 6,
            kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 51.5066, kCGImagePropertyGPSLongitude: 0.1169],
            kCGImagePropertyTIFFDictionary: [kCGImagePropertyTIFFMake: "SecretCamera", kCGImagePropertyTIFFModel: "Model X"],
        ])

        let prepared = try await PhotoPreparation.prepare(source)

        expectNoDifference([prepared.width, prepared.height], [20, 40])
        let properties = try #require(properties(of: prepared.jpeg))
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] == nil)
        #expect(tiff?[kCGImagePropertyTIFFModel] == nil)
        #expect((properties[kCGImagePropertyOrientation] as? Int ?? 1) == 1)
        let hash = try #require(ThumbHash.bytes(fromBase64: prepared.thumbhash))
        #expect(ThumbHash.decode(hash) != nil)
    }

    @Test
    func `a large photo is scaled down to 2048 pixels on its long side`() async throws {
        let prepared = try await PhotoPreparation.prepare(try jpeg(width: 3000, height: 1000, properties: [:]))

        expectNoDifference(prepared.width, 2048)
        #expect((682...683).contains(prepared.height))
    }

    @Test
    func `what isn't an image is refused`() async {
        await #expect(throws: PhotoPreparation.Failure.unreadable) {
            try await PhotoPreparation.prepare(Data("not an image".utf8))
        }
    }

    // MARK: Helpers

    private func jpeg(width: Int, height: Int, properties: [CFString: Any]) throws -> Data {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ))
        context.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        context.setFillColor(red: 0, green: 0, blue: 1, alpha: 1)
        context.fill(CGRect(x: width / 2, y: 0, width: width - width / 2, height: height))
        let image = try #require(context.makeImage())
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return data as Data
    }

    private func properties(of data: Data) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }
}
