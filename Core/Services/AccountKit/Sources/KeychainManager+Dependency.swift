public import FactoryKit
import Foundation

extension Container {
    public var keychainManager: Factory<KeychainManager> {
        self {
            let keychain = KeychainManager.live(service: KeychainManager.appService)
            // Only the system Keychain outlives the app's deletion; the in-memory ones start empty.
            AuthSession.forgetSessionFromEarlierInstall(keychain: keychain)
            return keychain
        }
        .singleton
        .onTest { .inMemory() }
        .onPreview { .inMemory() }
    }
}

extension KeychainManager {
    static let appService = Bundle.main.bundleIdentifier ?? "com.ertembiyik.openskatemap"
}
