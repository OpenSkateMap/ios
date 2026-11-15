public import SQLiteData

// MARK: - CollectionRole

/// `guest`: a public collection opened by its link.
public enum CollectionRole: String, CaseIterable, Codable, Sendable, QueryBindable {
    case owner
    case admin
    case editor
    case viewer
    case guest

    // MARK: Computed Properties

    public var canEdit: Bool {
        [.owner, .admin, .editor].contains(self)
    }

    /// Inviting, requests, roles, removing people, the visibility and deleting it.
    public var managesPeople: Bool {
        [.owner, .admin].contains(self)
    }

    public var isMember: Bool {
        self != .guest
    }
}

// MARK: - CollectionMemberRole

public enum CollectionMemberRole: String, CaseIterable, Codable, Sendable, QueryBindable {
    case viewer
    case editor
    case admin
}
