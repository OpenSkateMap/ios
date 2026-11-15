import Foundation

extension KeychainManager {
    public static func preview(signedInAs account: Account, token: String = "preview-token") -> KeychainManager {
        let session = SignedInAccount(token: token, account: account)
        let data = (try? JSONEncoder().encode(session)) ?? Data()
        return .inMemory([AuthSession.storageKey: data])
    }

    /// Keeps the account the last refresh stored with `token`, so a relaunch, offline too, starts as it.
    public static func signedIn(token: String) -> KeychainManager {
        let keychain = KeychainManager.live(service: appService)
        let stored = (try? keychain.load(AuthSession.storageKey))
            .flatMap { try? JSONDecoder().decode(SignedInAccount.self, from: $0) }
        if stored?.token != token, let data = try? JSONEncoder().encode(SignedInAccount(token: token, account: .preview)) {
            try? keychain.save(data, AuthSession.storageKey)
        }
        return keychain
    }
}
