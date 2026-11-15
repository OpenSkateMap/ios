import Foundation

/// ThumbHash placeholders, ported from evanw/thumbhash (MIT, `THIRD_PARTY_NOTICES.md`): https://evanw.github.io/thumbhash/
public enum ThumbHash {

    // MARK: Types

    public struct Color: Equatable, Sendable {
        public var red: Double
        public var green: Double
        public var blue: Double
        public var alpha: Double
    }

    public struct Pixels: Equatable, Sendable {
        public var width: Int
        public var height: Int
        public var rgba: [UInt8]
    }

    // MARK: Static Functions

    public static func averageColor(of hash: [UInt8]) -> Color? {
        guard hash.count >= 5 else {
            return nil
        }
        let header = Int(hash[0]) | Int(hash[1]) << 8 | Int(hash[2]) << 16
        let luminance = Double(header & 63) / 63
        let p = Double((header >> 6) & 63) / 31.5 - 1
        let q = Double((header >> 12) & 63) / 31.5 - 1
        let hasAlpha = header >> 23 != 0
        let alpha = hasAlpha && hash.count > 5 ? Double(hash[5] & 15) / 15 : 1
        let blue = luminance - 2 / 3 * p
        let red = (3 * luminance - blue + q) / 2
        let green = red - q
        return Color(red: clamp(red), green: clamp(green), blue: clamp(blue), alpha: alpha)
    }

    public static func approximateAspectRatio(of hash: [UInt8]) -> Double? {
        guard hash.count >= 5 else {
            return nil
        }
        let hasAlpha = hash[2] & 0x80 != 0
        let isLandscape = hash[4] & 0x80 != 0
        let lx = isLandscape ? (hasAlpha ? 5 : 7) : Int(hash[3] & 7)
        let ly = isLandscape ? Int(hash[3] & 7) : (hasAlpha ? 5 : 7)
        return ly == 0 ? nil : Double(lx) / Double(ly)
    }

    public static func decode(_ hash: [UInt8]) -> Pixels? {
        guard hash.count >= 5, let ratio = approximateAspectRatio(of: hash), ratio > 0 else {
            return nil
        }
        let header24 = Int(hash[0]) | Int(hash[1]) << 8 | Int(hash[2]) << 16
        let header16 = Int(hash[3]) | Int(hash[4]) << 8
        let lDC = Double(header24 & 63) / 63
        let pDC = Double((header24 >> 6) & 63) / 31.5 - 1
        let qDC = Double((header24 >> 12) & 63) / 31.5 - 1
        let lScale = Double((header24 >> 18) & 31) / 31
        let hasAlpha = header24 >> 23 != 0
        let pScale = Double((header16 >> 3) & 63) / 63
        let qScale = Double((header16 >> 9) & 63) / 63
        let isLandscape = header16 >> 15 != 0
        let lx = max(3, isLandscape ? (hasAlpha ? 5 : 7) : header16 & 7)
        let ly = max(3, isLandscape ? header16 & 7 : (hasAlpha ? 5 : 7))
        guard !hasAlpha || hash.count >= 6 else {
            return nil
        }
        let aDC = hasAlpha ? Double(hash[5] & 15) / 15 : 1
        let aScale = hasAlpha ? Double(hash[5] >> 4) / 15 : 0

        let acStart = hasAlpha ? 6 : 5
        var acIndex = 0
        func decodeChannel(_ nx: Int, _ ny: Int, _ scale: Double) -> [Double]? {
            var ac = [Double]()
            for cy in 0..<ny {
                var cx = cy == 0 ? 1 : 0
                while cx * ny < nx * (ny - cy) {
                    let byte = acStart + (acIndex >> 1)
                    guard byte < hash.count else {
                        return nil
                    }
                    let nibble = (Int(hash[byte]) >> ((acIndex & 1) << 2)) & 15
                    ac.append((Double(nibble) / 7.5 - 1) * scale)
                    acIndex += 1
                    cx += 1
                }
            }
            return ac
        }
        // Saturation is boosted by 1.25 to make up for quantization, as the reference decoder does.
        guard let lAC = decodeChannel(lx, ly, lScale),
              let pAC = decodeChannel(3, 3, pScale * 1.25),
              let qAC = decodeChannel(3, 3, qScale * 1.25) else {
            return nil
        }
        let aAC = hasAlpha ? decodeChannel(5, 5, aScale) : []
        guard let aAC else {
            return nil
        }

        let width = Int((ratio > 1 ? 32 : 32 * ratio).rounded())
        let height = Int((ratio > 1 ? 32 / ratio : 32).rounded())
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        let cxCount = max(lx, hasAlpha ? 5 : 3)
        let cyCount = max(ly, hasAlpha ? 5 : 3)
        var fx = [Double](repeating: 0, count: cxCount)
        var fy = [Double](repeating: 0, count: cyCount)
        var i = 0
        for y in 0..<height {
            for x in 0..<width {
                var l = lDC
                var p = pDC
                var q = qDC
                var a = aDC
                for cx in 0..<cxCount {
                    fx[cx] = cos(Double.pi / Double(width) * (Double(x) + 0.5) * Double(cx))
                }
                for cy in 0..<cyCount {
                    fy[cy] = cos(Double.pi / Double(height) * (Double(y) + 0.5) * Double(cy))
                }
                var j = 0
                for cy in 0..<ly {
                    var cx = cy == 0 ? 1 : 0
                    let fy2 = fy[cy] * 2
                    while cx * ly < lx * (ly - cy) {
                        l += lAC[j] * fx[cx] * fy2
                        j += 1
                        cx += 1
                    }
                }
                j = 0
                for cy in 0..<3 {
                    var cx = cy == 0 ? 1 : 0
                    let fy2 = fy[cy] * 2
                    while cx < 3 - cy {
                        let f = fx[cx] * fy2
                        p += pAC[j] * f
                        q += qAC[j] * f
                        j += 1
                        cx += 1
                    }
                }
                if hasAlpha {
                    j = 0
                    for cy in 0..<5 {
                        var cx = cy == 0 ? 1 : 0
                        let fy2 = fy[cy] * 2
                        while cx < 5 - cy {
                            a += aAC[j] * fx[cx] * fy2
                            j += 1
                            cx += 1
                        }
                    }
                }
                let b = l - 2 / 3 * p
                let r = (3 * l - b + q) / 2
                let g = r - q
                rgba[i] = channel(r)
                rgba[i + 1] = channel(g)
                rgba[i + 2] = channel(b)
                rgba[i + 3] = channel(a)
                i += 4
            }
        }
        return Pixels(width: width, height: height, rgba: rgba)
    }

    public static func bytes(fromBase64 string: String) -> [UInt8]? {
        Data(base64Encoded: string).map { [UInt8]($0) }
    }

    private static func clamp(_ value: Double) -> Double {
        max(0, min(1, value))
    }

    /// Truncates like the reference decoder writing into a `Uint8Array`.
    private static func channel(_ value: Double) -> UInt8 {
        UInt8(max(0, 255 * min(1, value)))
    }
}
