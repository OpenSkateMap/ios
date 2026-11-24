import Foundation

/// The creation and modification times in an MP4's movie, track and media headers: `AVAssetWriter` sets them to
/// when it wrote the file, and `AVAsset.creationDate` reads them back.
enum MP4BoxTimes {

    // MARK: Static Properties

    private static let containers: Set = ["moov", "trak", "mdia"]
    private static let headers: Set = ["mvhd", "tkhd", "mdhd"]

    // MARK: Static Functions

    /// Zeroes them in place; no box changes size, so every offset in the file stays valid.
    static func clear(in file: URL) throws {
        var data = try Data(contentsOf: file)
        clear(&data, in: 0..<data.count)
        try data.write(to: file, options: .atomic)
    }

    private static func clear(_ data: inout Data, in range: Range<Int>) {
        var offset = range.lowerBound
        while offset + 8 <= range.upperBound {
            let size32 = Int(number(data, at: offset, width: 4))
            let size =
                switch size32 {
                case 0: range.upperBound - offset
                case 1 where offset + 16 <= range.upperBound: Int(number(data, at: offset + 8, width: 8))
                default: size32
                }
            let end = offset + size
            guard size >= 8, end <= range.upperBound else {
                return
            }
            let type = String(decoding: data[offset + 4..<offset + 8], as: UTF8.self)
            if containers.contains(type) {
                clear(&data, in: offset + 8..<end)
            } else if headers.contains(type), offset + 9 <= end {
                // A full box: after its version and flags, version 1 holds 64-bit times and version 0 32-bit ones.
                let times = offset + 12..<offset + 12 + (data[offset + 8] == 1 ? 16 : 8)
                if times.upperBound <= end {
                    data.replaceSubrange(times, with: repeatElement(0, count: times.count))
                }
            }
            offset = end
        }
    }

    private static func number(_ data: Data, at offset: Int, width: Int) -> UInt64 {
        data[offset..<offset + width].reduce(0) { $0 << 8 | UInt64($1) }
    }
}
