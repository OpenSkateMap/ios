import APIClientKit
public import FactoryKit

extension Container {
    public var photoUploadManager: Factory<PhotoUploadManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var clipPreparer: Factory<ClipPreparer> {
        self { .live }
            .singleton
            .onPreview { .preview }
            .onTest { .test }
    }
}
