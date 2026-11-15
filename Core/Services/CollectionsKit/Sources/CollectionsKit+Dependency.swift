import APIClientKit
public import FactoryKit
import PhotoUploadKit
import SpotsKit
import SQLiteKit

extension Container {
    public var collectionsAPIManager: Factory<CollectionsAPIManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var collectionsSync: Factory<CollectionsSync> {
        self { CollectionsSync(api: self.collectionsAPIManager(), spots: self.syncEngine(), database: self.database()) }.singleton
    }

    @MainActor
    public var collectionsSession: Factory<CollectionsSession> {
        self {
            CollectionsSession(
                sync: self.collectionsSync(),
                api: self.collectionsAPIManager(),
                photos: self.photoUploadManager(),
                accountID: self.sessionCredentials().accountID,
            )
        }
        .scope(.account)
    }
}
