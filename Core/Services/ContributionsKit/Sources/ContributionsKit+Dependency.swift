import APIClientKit
public import FactoryKit
import PhotoUploadKit
import SQLiteKit

extension Container {
    public var contributionsAPIManager: Factory<ContributionsAPIManager> {
        self {
            let serverURL = self.apiServerURL()
            return .live(credentials: self.sessionCredentials()) { Client.production(serverURL: serverURL, middlewares: $0) }
        }
        .singleton
        .onPreview { .preview }
    }

    public var videoLinkChecker: Factory<VideoLinkChecker> {
        self { .live }
            .singleton
            .onPreview { .preview }
    }

    public var publishedSpotHandler: Factory<PublishedSpotHandler> {
        self { .none }
    }

    public var backgroundTime: Factory<BackgroundTime> {
        self { .none }
    }

    public var contributionsOutbox: Factory<ContributionsOutbox> {
        self {
            ContributionsOutbox(
                api: self.contributionsAPIManager(),
                photos: self.photoUploadManager(),
                database: self.database(),
                files: .applicationSupport(),
                spotPublished: self.publishedSpotHandler(),
                backgroundTime: self.backgroundTime(),
            )
        }
        .singleton
    }

    @MainActor
    public var contributionsSession: Factory<ContributionsSession> {
        self { ContributionsSession(outbox: self.contributionsOutbox(), photos: self.photoUploadManager()) }.scope(.account)
    }
}
