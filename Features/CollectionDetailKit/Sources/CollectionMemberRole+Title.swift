import SpotModelKit

extension CollectionMemberRole {
    var title: String {
        switch self {
        case .viewer: CollectionDetailKitStrings.Role.viewer
        case .editor: CollectionDetailKitStrings.Role.editor
        case .admin: CollectionDetailKitStrings.Role.admin
        }
    }

    /// What the role may do.
    var detail: String {
        switch self {
        case .viewer: CollectionDetailKitStrings.Role.Viewer.detail
        case .editor: CollectionDetailKitStrings.Role.Editor.detail
        case .admin: CollectionDetailKitStrings.Role.Admin.detail
        }
    }

    var symbolName: String {
        switch self {
        case .viewer: "eye"
        case .editor: "pencil"
        case .admin: "person.badge.key"
        }
    }
}
