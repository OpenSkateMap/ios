public import Foundation

public struct PreparedPhoto: Equatable, Sendable {
    public var jpeg: Data
    public var width: Int
    public var height: Int
    public var thumbhash: String

    public init(jpeg: Data, width: Int, height: Int, thumbhash: String) {
        self.jpeg = jpeg
        self.width = width
        self.height = height
        self.thumbhash = thumbhash
    }
}
