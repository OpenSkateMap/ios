import AccountKit

extension Account {
    var roleBadge: String? {
        switch role {
        case .user: nil
        case .editor: ProfileKitStrings.Profile.Role.editor
        case .admin: ProfileKitStrings.Profile.Role.admin
        }
    }
}
