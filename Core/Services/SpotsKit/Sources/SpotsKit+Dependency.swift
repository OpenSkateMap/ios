import APIClientKit
public import FactoryKit
import SQLiteKit

extension Container {
    public var spotsAPIManager: Factory<SpotsAPIManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var syncEngine: Factory<SpotSyncEngine> {
        self { SpotSyncEngine(api: self.spotsAPIManager(), database: self.database()) }.singleton
    }

    @MainActor
    public var spotsSession: Factory<SpotsSession> {
        self {
            SpotsSession(
                engine: self.syncEngine(),
                fetcher: DetailFetcher(api: self.spotsAPIManager(), engine: self.syncEngine(), database: self.database()),
                api: self.spotsAPIManager(),
            )
        }
        .scope(.account)
    }
}
