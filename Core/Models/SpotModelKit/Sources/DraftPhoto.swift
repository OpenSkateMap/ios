public import SQLiteData

@Table("draft_photo")
public struct DraftPhoto: Identifiable, Equatable, Sendable {
    /// The photo's file and its clip's, if it has one.
    public var fileNames: [String] {
        [fileName] + (clip.map { [$0.fileName] } ?? [])
    }

    /// Both the photo and its clip, if it has one, are on the server.
    public var isFullyUploaded: Bool {
        isUploaded && clip?.isUploaded != false
    }

    /// Also the server's photo id, so a retried upload lands on the same photo.
    public let id: String
    public var draftID: String
    public var position: Int
    public var fileName: String
    public var width: Int
    public var height: Int
    public var thumbhash: String
    public var credit: String?
    public var sourceURL: String?
    public var isUploaded: Bool
    @Column(as: DraftClip.JSONRepresentation?.self)
    public var clip: DraftClip?

    public init(id: String,
                draftID: String,
                position: Int,
                fileName: String,
                width: Int,
                height: Int,
                thumbhash: String,
                credit: String?,
                sourceURL: String?,
                isUploaded: Bool = false,
                clip: DraftClip? = nil) {
        self.id = id
        self.draftID = draftID
        self.position = position
        self.fileName = fileName
        self.width = width
        self.height = height
        self.thumbhash = thumbhash
        self.credit = credit
        self.sourceURL = sourceURL
        self.isUploaded = isUploaded
        self.clip = clip
    }
}
