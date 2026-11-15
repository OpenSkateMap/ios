public import Foundation
public import Observation
public import PhotoUploadKit
public import SpotModelKit

@MainActor
@Observable
public final class ContributionsSession {

    // MARK: Properties

    @ObservationIgnored private let outbox: ContributionsOutbox
    @ObservationIgnored private let photos: PhotoUploadManager
    @ObservationIgnored private var refreshing: Task<Bool, Never>?

    // MARK: Lifecycle

    public init(outbox: ContributionsOutbox, photos: PhotoUploadManager) {
        self.outbox = outbox
        self.photos = photos
    }

    // MARK: Functions

    public func prepare(_ imageData: Data) async throws -> PreparedPhoto {
        try await photos.prepare(imageData)
    }

    @discardableResult
    public func submit(_ spot: NewSpot) async throws -> String {
        try await outbox.add(spot)
    }

    @discardableResult
    public func suggest(_ edit: SpotEditSuggestion) async throws -> String {
        try await outbox.add(edit)
    }

    public func addVideo(_ link: VideoLink, to spotID: String, caption: String) async throws {
        try await outbox.addVideo(spotID: spotID, url: link.url.absoluteString, caption: caption)
    }

    public func retryVideo(_ id: String) async throws {
        try await outbox.retryVideo(id)
    }

    public func discardVideo(_ id: String) async throws {
        try await outbox.discardVideo(id)
    }

    public func retry(_ id: String) async throws {
        try await outbox.retry(id)
    }

    /// False when it's already uploading.
    @discardableResult
    public func discard(_ id: String) async throws -> Bool {
        try await outbox.discard(id)
    }

    public func refresh() async {
        await pull()
    }

    /// The same refresh, saying whether the submission history came back: a pull the person started reports a failure.
    @discardableResult
    public func pull() async -> Bool {
        if let refreshing {
            return await refreshing.value
        }
        let task = Task { [outbox] in
            await outbox.start()
            return await outbox.refreshHistory()
        }
        refreshing = task
        let refreshed = await task.value
        refreshing = nil
        return refreshed
    }

    public func nearbySpots(latitude: Double, longitude: Double) async -> [NearbySpot] {
        await outbox.nearby(latitude: latitude, longitude: longitude)
    }
}
