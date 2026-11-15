import Foundation
import PeopleKit

extension PublicProfile {
    var roleBadge: String? {
        switch role {
        case .user:
            return nil

        case .editor:
            let cities = editorOf.map(\.name).joined(separator: ", ")
            return cities.isEmpty ? ProfileKitStrings.Profile.Role.editor : ProfileKitStrings.Profile.Role.editorOf(cities)

        case .admin:
            return ProfileKitStrings.Profile.Role.admin
        }
    }
}
