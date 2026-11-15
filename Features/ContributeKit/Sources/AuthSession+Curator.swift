import AccountKit

extension AuthSession {
    var isCurator: Bool {
        guard case .signedIn(let account) = phase else {
            return false
        }
        return account.role != .user
    }

    var isAdmin: Bool {
        guard case .signedIn(let account) = phase else {
            return false
        }
        return account.role == .admin
    }
}
