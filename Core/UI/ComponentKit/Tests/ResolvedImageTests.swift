import Testing
import UIKit
@testable import ComponentKit

@MainActor
@Suite(.timeLimit(.minutes(1)))
struct ResolvedImageTests {
    @Test
    func `a dynamic image resolves to the asked appearance and stays there`() throws {
        let light = filled(.white)
        let asset = try #require(light.imageAsset)
        asset.register(filled(.black), with: UITraitCollection(userInterfaceStyle: .dark))

        let dark = light.resolved(with: UITraitCollection(userInterfaceStyle: .dark))

        #expect(try red(of: dark) == 0)
        #expect(try red(of: light.resolved(with: UITraitCollection(userInterfaceStyle: .light))) == 255)
        #expect(dark.imageAsset?.image(with: UITraitCollection(userInterfaceStyle: .light)) !== light)
    }

    private func filled(_ color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
    }

    private func red(of image: UIImage) throws -> UInt8 {
        let cgImage = try #require(image.cgImage)
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try #require(CGContext(
            data: &pixel,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return pixel[0]
    }

}
