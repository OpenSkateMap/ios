public import SQLiteData

@Table("draft_photo")
public struct DraftPhoto: Identifiable, Equatable, Sendable {
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

    public init(id: String,
                draftID: String,
                position: Int,
                fileName: String,
                width: Int,
                height: Int,
                thumbhash: String,
                credit: String?,
                sourceURL: String?,
                isUploaded: Bool = false) {
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
    }
}
