public import Foundation
public import SQLiteData

// MARK: - MySubmission

@Table("my_submission")
public struct MySubmission: Identifiable, Equatable, Sendable {
    public let id: String
    public var title: String
    public var kind: SpotKind
    public var cityID: String?
    public var latitude: Double
    public var longitude: Double
    public var status: SubmissionStatus
    public var rejectReason: String?
    public var spotID: String?
    public var collectionID: String?
    @Column(as: [SpotEditField].JSONRepresentation.self)
    public var changedFields: [SpotEditField]
    public var coverKey: String?
    public var coverThumbhash: String?
    public var removalReason: SpotRemovalReason?
    public var removedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: String,
                title: String,
                kind: SpotKind,
                cityID: String?,
                latitude: Double,
                longitude: Double,
                status: SubmissionStatus,
                rejectReason: String?,
                spotID: String?,
                collectionID: String? = nil,
                changedFields: [SpotEditField] = [],
                coverKey: String? = nil,
                coverThumbhash: String?,
                removalReason: SpotRemovalReason? = nil,
                removedAt: Date? = nil,
                createdAt: Date,
                updatedAt: Date) {
        self.id = id
        self.title = title
        self.kind = kind
        self.cityID = cityID
        self.latitude = latitude
        self.longitude = longitude
        self.status = status
        self.rejectReason = rejectReason
        self.spotID = spotID
        self.collectionID = collectionID
        self.changedFields = changedFields
        self.coverKey = coverKey
        self.coverThumbhash = coverThumbhash
        self.removalReason = removalReason
        self.removedAt = removedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

extension MySubmission {
    public var isEdit: Bool {
        !changedFields.isEmpty
    }
}
