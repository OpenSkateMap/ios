import APIClientKit
public import FactoryKit
import SQLiteKit

extension Container {
    public var reviewAPIManager: Factory<ReviewAPIManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var reviewQueueStore: Factory<ReviewQueueStore> {
        self { .live(database: self.database()) }
            .singleton
            .onPreview { .none }
    }

    @MainActor
    public var reviewSession: Factory<ReviewSession> {
        self { ReviewSession(api: self.reviewAPIManager(), store: self.reviewQueueStore()) }.scope(.account)
    }
}
