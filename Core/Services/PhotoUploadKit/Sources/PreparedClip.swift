public import Foundation

/// An encoded MP4 ready to upload: one silent H.264 track, upright, at the size and length it plays.
public struct PreparedClip: Equatable, Sendable {
    /// Owned by whoever holds the value: `ClipPreparer` writes it to a temporary file, the outbox moves it into its own.
    public var file: URL
    public var width: Int
    public var height: Int
    public var durationMs: Int
    public var bytes: Int

    public init(file: URL, width: Int, height: Int, durationMs: Int, bytes: Int) {
        self.file = file
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.bytes = bytes
    }
}
