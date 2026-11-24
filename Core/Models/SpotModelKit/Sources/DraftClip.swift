/// A clip waiting in the outbox with its photo: the file it was moved into, and whether the server has it yet.
public struct DraftClip: Codable, Equatable, Sendable {
    /// Also the server's clip id, minted when the draft is saved, so a retried upload lands on the same clip.
    public var id: String
    public var fileName: String
    public var width: Int
    public var height: Int
    public var durationMs: Int
    public var bytes: Int
    public var isUploaded: Bool

    public init(id: String,
                fileName: String,
                width: Int,
                height: Int,
                durationMs: Int,
                bytes: Int,
                isUploaded: Bool = false) {
        self.id = id
        self.fileName = fileName
        self.width = width
        self.height = height
        self.durationMs = durationMs
        self.bytes = bytes
        self.isUploaded = isUploaded
    }
}
