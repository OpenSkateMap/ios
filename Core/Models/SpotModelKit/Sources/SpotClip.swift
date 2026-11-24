/// A short silent clip that plays in place of a photo, the photo being its poster.
public struct SpotClip: Codable, Equatable, Hashable, Sendable {
    public var key: String
    public var width: Int
    public var height: Int
    public var durationMs: Int

    public init(key: String, width: Int, height: Int, durationMs: Int) {
        self.key = key
        self.width = width
        self.height = height
        self.durationMs = durationMs
    }
}
