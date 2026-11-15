import CustomDump
import Foundation
import Testing
@testable import ImageKit

/// Expected values come from the reference implementation (`thumbhash` 0.1.1 on npm) for the same hashes.
@Suite(.timeLimit(.minutes(1)))
struct ThumbHashTests {
    private struct Vector {
        let base64: String
        let width: Int
        let height: Int
        let average: ThumbHash.Color
        let first: [UInt8]
        let middle: [UInt8]
        let last: [UInt8]
    }

    private let vectors = [
        Vector(
            base64: "IqkNVZpyd3eAeIh4iJiHh3OPB6eI",
            width: 32,
            height: 23,
            average: .init(red: 0.5, green: 0.6746031746031746, blue: 0.4444444444444445, alpha: 1),
            first: [26, 150, 18, 255],
            middle: [134, 172, 100, 255],
            last: [226, 174, 210, 255],
        ),
        Vector(
            base64: "IqkNVBpyB4eHiIl4aIhyjweniA==",
            width: 18,
            height: 32,
            average: .init(red: 0.5, green: 0.6746031746031746, blue: 0.4444444444444445, alpha: 1),
            first: [22, 145, 27, 255],
            middle: [142, 177, 108, 255],
            last: [242, 191, 214, 255],
        ),
        Vector(
            base64: "4YiJPRQrcndgd4iYeHOfB7Z4j4h4iIeIhw==",
            width: 32,
            height: 32,
            average: .init(
                red: 0.44179894179894186,
                green: 0.67989417989418,
                blue: 0.44973544973544977,
                alpha: 0.7333333333333333,
            ),
            first: [25, 160, 31, 255],
            middle: [131, 162, 110, 198],
            last: [165, 192, 174, 105],
        ),
    ]

    @Test
    func `decoding matches the reference implementation`() throws {
        for vector in vectors {
            let bytes = try #require(ThumbHash.bytes(fromBase64: vector.base64))
            let pixels = try #require(ThumbHash.decode(bytes))
            let pixel = { (x: Int, y: Int) in Array(pixels.rgba[(y * pixels.width + x) * 4..<(y * pixels.width + x) * 4 + 4]) }

            expectNoDifference([pixels.width, pixels.height], [vector.width, vector.height])
            expectNoDifference(pixel(0, 0), vector.first)
            expectNoDifference(pixel(pixels.width / 2, pixels.height / 2), vector.middle)
            expectNoDifference(pixel(pixels.width - 1, pixels.height - 1), vector.last)
            expectNoDifference(ThumbHash.averageColor(of: bytes), vector.average)
        }
    }

    @Test
    func `bytes that aren't a ThumbHash decode to nothing`() {
        #expect(ThumbHash.decode([1, 2, 3]) == nil)
        #expect(ThumbHash.decode([0x22, 0xA9, 0x0D, 0x55, 0x9A]) == nil)
        #expect(ThumbHash.bytes(fromBase64: "not base64!") == nil)
    }

    @Test
    func `encoding matches the reference implementation, with and without alpha`() {
        func pixels(width: Int, height: Int, alpha: Bool) -> [UInt8] {
            var rgba = [UInt8]()
            for y in 0..<height {
                for x in 0..<width {
                    rgba += [
                        UInt8(x * 255 / (width - 1)),
                        UInt8(y * 255 / (height - 1)),
                        UInt8(((x + y) * 20) & 255),
                        alpha ? UInt8(((x + y) * 40) & 255) : 255,
                    ]
                }
            }
            return rgba
        }

        expectNoDifference(
            ThumbHash.encode(width: 8, height: 6, rgba: pixels(width: 8, height: 6, alpha: false)),
            [31, 248, 17, 21, 158, 128, 135, 135, 112, 120, 120, 119, 136, 120, 135, 135, 139, 128, 7, 248, 135],
        )
        expectNoDifference(
            ThumbHash.encode(width: 4, height: 4, rgba: pixels(width: 4, height: 4, alpha: true)),
            [
                161,
                10,
                134,
                13,
                16,
                39,
                176,
                119,
                208,
                136,
                139,
                119,
                120,
                176,
                208,
                11,
                250,
                88,
                112,
                119,
                128,
                136,
                135,
                119,
                120
            ],
        )
        #expect(ThumbHash.encode(width: 101, height: 1, rgba: [UInt8](repeating: 0, count: 404)) == nil)
    }
}
