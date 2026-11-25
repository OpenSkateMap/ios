public import Foundation
public import SQLiteData

/// `id` is also the server's submission id, sent unchanged on every retry, so the server keeps one submission.
@Table("submission_draft")
public struct SubmissionDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var about: String
    public var kind: SpotKind
    @Column(as: [String].JSONRepresentation.self)
    public var obstacles: [String]
    public var condition: SpotCondition
    public var latitude: Double
    public var longitude: Double
    public var note: String
    public var collectionID: String?
    public var editsSpotID: String?
    @Column(as: [SpotEditField].JSONRepresentation.self)
    public var changedFields: [SpotEditField]
    /// An edit's photos as it leaves the spot: the spot's photo ids and this draft's photo ids, the cover first.
    @Column(as: [String].JSONRepresentation?.self)
    public var photoOrder: [String]?
    /// The spot's photo ids as the editor showed them; set with `photoOrder`.
    @Column(as: [String].JSONRepresentation?.self)
    public var basePhotoIDs: [String]?
    public var status: OutboxStatus
    public var problem: OutboxProblem?
    public var attempts: Int
    public var nextAttemptAt: Date?
    public var createdAt: Date

    public init(id: String,
                title: String,
                about: String,
                kind: SpotKind,
                obstacles: [String],
                condition: SpotCondition,
                latitude: Double,
                longitude: Double,
                note: String,
                collectionID: String? = nil,
                editsSpotID: String? = nil,
                changedFields: [SpotEditField] = [],
                photoOrder: [String]? = nil,
                basePhotoIDs: [String]? = nil,
                status: OutboxStatus = .pending,
                problem: OutboxProblem? = nil,
                attempts: Int = 0,
                nextAttemptAt: Date? = nil,
                createdAt: Date) {
        self.id = id
        self.title = title
        self.about = about
        self.kind = kind
        self.obstacles = obstacles
        self.condition = condition
        self.latitude = latitude
        self.longitude = longitude
        self.note = note
        self.collectionID = collectionID
        self.editsSpotID = editsSpotID
        self.changedFields = changedFields
        self.photoOrder = photoOrder
        self.basePhotoIDs = basePhotoIDs
        self.status = status
        self.problem = problem
        self.attempts = attempts
        self.nextAttemptAt = nextAttemptAt
        self.createdAt = createdAt
    }
}
