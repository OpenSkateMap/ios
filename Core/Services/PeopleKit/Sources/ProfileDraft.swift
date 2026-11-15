public import PhotoUploadKit

public struct ProfileDraft: Equatable, Sendable {

    // MARK: Types

    public enum AvatarChoice: Equatable, Sendable {
        case unchanged
        case removed
        case replaced(PreparedPhoto)
    }

    // MARK: Properties

    public var name: String
    public var username: String
    public var bio: String
    public var handles: [HandleNetwork: String]
    public var avatar = AvatarChoice.unchanged

    // MARK: Lifecycle

    public init(_ profile: PublicProfile) {
        name = profile.name
        username = profile.username ?? ""
        bio = profile.bio
        handles = Dictionary(uniqueKeysWithValues: HandleNetwork.allCases.map { ($0, profile.handles[$0] ?? "") })
    }
}
