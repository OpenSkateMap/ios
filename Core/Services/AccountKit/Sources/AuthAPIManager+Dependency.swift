import APIClientKit
public import FactoryKit

extension Container {
    public var authAPIManager: Factory<AuthAPIManager> {
        // Resolved in the body, not a capture list, which would resolve during `autoRegister()`, before the app's bindings.
        self {
            let serverURL = self.apiServerURL()
            return .live { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }
}
