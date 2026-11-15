import APIClientKit
public import FactoryKit
import PhotoUploadKit
import SQLiteKit

extension Container {
    public var peopleAPIManager: Factory<PeopleAPIManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var blocksChangedHandler: Factory<BlocksChangedHandler> {
        self { .none }
    }

    public var peopleStore: Factory<PeopleStore> {
        self { PeopleStore(database: self.database()) }.singleton
    }

    @MainActor
    public var profileSession: Factory<ProfileSession> {
        self {
            ProfileSession(
                api: self.peopleAPIManager(),
                photos: self.photoUploadManager(),
                store: self.peopleStore(),
                viewerID: self.sessionCredentials().accountID,
                blocksChanged: self.blocksChangedHandler(),
            )
        }
        .scope(.account)
    }
}
