import Foundation

extension ThumbHash {
    /// A port of the reference implementation's `rgbaToThumbHash`.
    public static func encode(width: Int, height: Int, rgba: [UInt8]) -> [UInt8]? {
        guard width > 0, height > 0, width <= 100, height <= 100, rgba.count == width * height * 4 else {
            return nil
        }
        let count = width * height

        var averageRed = 0.0
        var averageGreen = 0.0
        var averageBlue = 0.0
        var averageAlpha = 0.0
        for index in 0..<count {
            let alpha = Double(rgba[index * 4 + 3]) / 255
            averageRed += alpha / 255 * Double(rgba[index * 4])
            averageGreen += alpha / 255 * Double(rgba[index * 4 + 1])
            averageBlue += alpha / 255 * Double(rgba[index * 4 + 2])
            averageAlpha += alpha
        }
        if averageAlpha > 0 {
            averageRed /= averageAlpha
            averageGreen /= averageAlpha
            averageBlue /= averageAlpha
        }

        let hasAlpha = averageAlpha < Double(count)
        let luminanceLimit = hasAlpha ? 5.0 : 7.0
        let longest = Double(max(width, height))
        let lx = max(1, Int((luminanceLimit * Double(width) / longest).rounded()))
        let ly = max(1, Int((luminanceLimit * Double(height) / longest).rounded()))

        var luminance = [Double](repeating: 0, count: count)
        var yellowBlue = [Double](repeating: 0, count: count)
        var redGreen = [Double](repeating: 0, count: count)
        var alphaChannel = [Double](repeating: 0, count: count)
        for index in 0..<count {
            let alpha = Double(rgba[index * 4 + 3]) / 255
            let red = averageRed * (1 - alpha) + alpha / 255 * Double(rgba[index * 4])
            let green = averageGreen * (1 - alpha) + alpha / 255 * Double(rgba[index * 4 + 1])
            let blue = averageBlue * (1 - alpha) + alpha / 255 * Double(rgba[index * 4 + 2])
            luminance[index] = (red + green + blue) / 3
            yellowBlue[index] = (red + green) / 2 - blue
            redGreen[index] = red - green
            alphaChannel[index] = alpha
        }

        func encodeChannel(_ channel: [Double], nx: Int, ny: Int) -> (dc: Double, ac: [Double], scale: Double) {
            var dc = 0.0
            var ac = [Double]()
            var scale = 0.0
            var fx = [Double](repeating: 0, count: width)
            for cy in 0..<ny {
                var cx = 0
                while cx * ny < nx * (ny - cy) {
                    var f = 0.0
                    for x in 0..<width {
                        fx[x] = cos(Double.pi / Double(width) * Double(cx) * (Double(x) + 0.5))
                    }
                    for y in 0..<height {
                        let fy = cos(Double.pi / Double(height) * Double(cy) * (Double(y) + 0.5))
                        for x in 0..<width {
                            f += channel[x + y * width] * fx[x] * fy
                        }
                    }
                    f /= Double(count)
                    if cx > 0 || cy > 0 {
                        ac.append(f)
                        scale = max(scale, abs(f))
                    } else {
                        dc = f
                    }
                    cx += 1
                }
            }
            if scale > 0 {
                ac = ac.map { 0.5 + 0.5 / scale * $0 }
            }
            return (dc, ac, scale)
        }

        let l = encodeChannel(luminance, nx: max(3, lx), ny: max(3, ly))
        let p = encodeChannel(yellowBlue, nx: 3, ny: 3)
        let q = encodeChannel(redGreen, nx: 3, ny: 3)
        let a = hasAlpha ? encodeChannel(alphaChannel, nx: 5, ny: 5) : nil

        let isLandscape = width > height
        let header24 = Int((63 * l.dc).rounded())
            | Int((31.5 + 31.5 * p.dc).rounded()) << 6
            | Int((31.5 + 31.5 * q.dc).rounded()) << 12
            | Int((31 * l.scale).rounded()) << 18
            | (hasAlpha ? 1 : 0) << 23
        let header16 = (isLandscape ? ly : lx)
            | Int((63 * p.scale).rounded()) << 3
            | Int((63 * q.scale).rounded()) << 9
            | (isLandscape ? 1 : 0) << 15
        var hash: [UInt8] = [
            UInt8(header24 & 255),
            UInt8((header24 >> 8) & 255),
            UInt8(header24 >> 16),
            UInt8(header16 & 255),
            UInt8(header16 >> 8),
        ]
        if let a {
            hash.append(UInt8(Int((15 * a.dc).rounded()) | Int((15 * a.scale).rounded()) << 4))
        }

        let acStart = hasAlpha ? 6 : 5
        var acIndex = 0
        for channel in [l.ac, p.ac, q.ac] + (a.map { [$0.ac] } ?? []) {
            for f in channel {
                let byte = acStart + (acIndex >> 1)
                if byte >= hash.count {
                    hash.append(0)
                }
                hash[byte] |= UInt8(Int((15 * f).rounded())) << ((acIndex & 1) << 2)
                acIndex += 1
            }
        }
        return hash
    }
}
