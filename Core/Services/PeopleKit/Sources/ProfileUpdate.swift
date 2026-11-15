import Foundation

/// Emptying a field goes in `clear`, never as `null`: the generated client can't send an explicit null.
public struct ProfileUpdate: Equatable, Sendable {

    // MARK: Types

    public struct AvatarUpload: Equatable, Sendable {
        public var photoID: String
        public var thumbhash: String

        public init(photoID: String, thumbhash: String) {
            self.photoID = photoID
            self.thumbhash = thumbhash
        }
    }

    public enum Field: String, CaseIterable, Sendable {
        case username
        case bio
        case avatar
        case instagram
        case tiktok
        case youtube
        case x
        case telegram
        case website

        // MARK: Lifecycle

        init(_ network: HandleNetwork) {
            switch network {
            case .instagram: self = .instagram
            case .tiktok: self = .tiktok
            case .youtube: self = .youtube
            case .x: self = .x
            case .telegram: self = .telegram
            case .website: self = .website
            }
        }
    }

    // MARK: Computed Properties

    public var isEmpty: Bool {
        name == nil && username == nil && bio == nil && avatar == nil && handles.isEmpty && clear.isEmpty
    }

    // MARK: Properties

    public var name: String?
    public var username: String?
    public var bio: String?
    public var avatar: AvatarUpload?
    public var handles: [HandleNetwork: String]
    public var clear: [Field]

    // MARK: Lifecycle

    public init(name: String? = nil,
                username: String? = nil,
                bio: String? = nil,
                avatar: AvatarUpload? = nil,
                handles: [HandleNetwork: String] = [:],
                clear: [Field] = []) {
        self.name = name
        self.username = username
        self.bio = bio
        self.avatar = avatar
        self.handles = handles
        self.clear = clear
    }

    public init(from profile: PublicProfile, to draft: ProfileDraft) {
        var cleared = Set<Field>()
        self.init()

        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if name != profile.name {
            self.name = name
        }

        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        if username.isEmpty {
            if profile.username != nil {
                cleared.insert(.username)
            }
        } else if username != profile.username {
            self.username = username
        }

        let bio = draft.bio.trimmingCharacters(in: .whitespacesAndNewlines)
        if bio.isEmpty {
            if !profile.bio.isEmpty {
                cleared.insert(.bio)
            }
        } else if bio != profile.bio {
            self.bio = bio
        }

        for network in HandleNetwork.allCases {
            let value = network.normalized(draft.handles[network] ?? "")
            if value.isEmpty {
                if profile.handles[network] != nil {
                    cleared.insert(Field(network))
                }
            } else if value != profile.handles[network] {
                handles[network] = value
            }
        }

        if draft.avatar == .removed, profile.avatar != nil {
            cleared.insert(.avatar)
        }
        clear = Field.allCases.filter(cleared.contains)
    }
}
