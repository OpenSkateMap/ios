public import Foundation
public import SQLiteData

@Table("spot_detail")
public struct SpotDetail: Identifiable, Equatable, Sendable {
    public let id: String
    public var about: String
    @Column(as: [String].JSONRepresentation.self)
    public var obstacles: [String]
    public var addedByID: String?
    public var addedByName: String?
    public var createdAt: Date
    public var version: Int
    public var fetchedAt: Date
    public var upvotes: Int
    public var downvotes: Int
    public var myVote: SpotVote

    public init(id: String,
                about: String,
                obstacles: [String],
                addedByID: String?,
                addedByName: String?,
                createdAt: Date,
                version: Int,
                fetchedAt: Date,
                upvotes: Int = 0,
                downvotes: Int = 0,
                myVote: SpotVote = .none) {
        self.id = id
        self.about = about
        self.obstacles = obstacles
        self.addedByID = addedByID
        self.addedByName = addedByName
        self.createdAt = createdAt
        self.version = version
        self.fetchedAt = fetchedAt
        self.upvotes = upvotes
        self.downvotes = downvotes
        self.myVote = myVote
    }
}
