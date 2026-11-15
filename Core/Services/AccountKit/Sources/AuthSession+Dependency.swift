import APIClientKit
public import FactoryKit

extension Container {
    @MainActor
    public var authSession: Factory<AuthSession> {
        self {
            AuthSession(
                apple: self.appleSignInManager(),
                api: self.authAPIManager(),
                keychain: self.keychainManager(),
                endAccountScope: {
                    self.accountEndHandler().run()
                    self.manager.reset(scope: .account)
                },
            )
        }
        .cached
    }
}
