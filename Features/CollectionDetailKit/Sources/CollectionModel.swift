import AppLinkKit
import CollectionsKit
import ComponentKit
import FactoryKit
import Foundation
import Observation
import os
import SpotModelKit
import SpotsKit
import SQLiteData

// MARK: - CollectionModel

@MainActor
@Observable
final class CollectionModel {

    // MARK: Types

    struct Shown: Equatable {
        var byline: String {
            let owner = role == .owner
                ? CollectionDetailKitStrings.Collection.Byline.yours
                : CollectionDetailKitStrings.Collection.Byline.owner(ownerUsername.map { "@\($0)" } ?? ownerName)
            let reach =
                switch visibility {
                case .public: CollectionDetailKitStrings.Visibility.public
                case .private where memberCount > 0: CollectionDetailKitStrings.Collection.Byline.sharedWith(memberCount)
                case .private: CollectionDetailKitStrings.Visibility.private
                }
            return CollectionDetailKitStrings.Collection.Byline.format(owner, reach)
        }

        var face: CollectionFace {
            CollectionFace(name: name, kind: kind, look: look, coverKey: coverKey, coverThumbhash: coverThumbhash)
        }

        var name: String
        var about: String
        var visibility: CollectionVisibility
        var kind: CollectionKind
        var look: CollectionLook
        var role: CollectionRole
        var ownerName: String
        var ownerUsername: String?
        var memberCount: Int
        var coverKey: String?
        var coverThumbhash: String?
        var spots: [SpotIndex]

        init(_ collection: SpotCollection, spots: [SpotIndex]) {
            name = collection.name
            about = collection.about
            visibility = collection.visibility
            kind = collection.kind
            look = collection.look
            role = collection.role
            ownerName = collection.ownerName
            ownerUsername = collection.ownerUsername
            memberCount = collection.memberCount
            coverKey = collection.coverKey
            coverThumbhash = collection.coverThumbhash
            self.spots = spots
        }

        init(_ collection: RemoteCollection, spots: [SpotIndex]) {
            name = collection.name
            about = collection.about
            visibility = collection.visibility
            kind = collection.kind
            look = collection.look
            role = collection.role
            ownerName = collection.ownerName
            ownerUsername = collection.ownerUsername
            memberCount = collection.memberCount
            coverKey = collection.coverKey
            coverThumbhash = collection.coverThumbhash
            self.spots = spots
        }
    }

    enum Phase: Equatable {
        case loading
        case shown
        case invited(CollectionInvitation)
        /// Not the account's to see, or not there.
        case locked(requested: Bool)
        case failed
        /// It was on the device and isn't anymore: deleted, or the account is no longer in it.
        case gone
    }

    enum Action: Equatable {
        case accept
        case decline
        case requestAccess
        case delete
        case leave
    }

    private enum FetchPhase: Equatable {
        case loading
        case fetched
        case notFound
        case failed
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "collection")

    // MARK: Computed Properties

    var shown: Shown? {
        standing.collection.map { Shown($0.collection, spots: $0.spots) } ?? remote
    }

    var phase: Phase {
        if standing.collection == nil, let invitation = standing.invitation {
            return .invited(invitation)
        }
        if shown != nil {
            return .shown
        }
        if startedOnDevice {
            return .gone
        }
        switch fetchPhase {
        case .loading, .fetched: return .loading
        case .notFound: return .locked(requested: standing.requested)
        case .failed: return .failed
        }
    }

    // MARK: Properties

    let id: String
    private(set) var action: Action?
    private(set) var removing = Set<String>()
    private(set) var isLoadingMore = false

    private var remote: Shown?
    @ObservationIgnored private var nextCursor: String?
    @ObservationIgnored private var loadingMore: Task<any Error?, Never>?
    /// The next page has failed since it last loaded, so the failure was already shown.
    @ObservationIgnored private var isPagingFailing = false
    private var fetchPhase = FetchPhase.loading
    /// Its row or invitation was in SQLite when the page opened; the fetch reads at init.
    @ObservationIgnored private var startedOnDevice = false

    @ObservationIgnored @Fetch private var standing = LocalStanding()
    @ObservationIgnored @LazyInjected(\.collectionsSession) private var session
    @ObservationIgnored @LazyInjected(\.appLinkOpener) private var links

    // MARK: Lifecycle

    init(id: String) {
        self.id = id
        _standing = Fetch(wrappedValue: LocalStanding(), LocalCollectionRequest(id: id))
        startedOnDevice = standing.collection != nil || standing.invitation != nil
    }

    // MARK: Functions

    func loadIfNeeded() async {
        guard standing.collection == nil, standing.invitation == nil else {
            return
        }
        fetchPhase = .loading
        do {
            let page = try await session.page(of: id)
            let collection = page.collection
            remote = Shown(collection, spots: page.spots.spots)
            nextCursor = page.spots.nextCursor
            fetchPhase = .fetched
            if collection.role != .guest {
                Task { await session.syncNow() }
            }
        } catch CollectionsAPIError.notFound {
            fetchPhase = .notFound
        } catch {
            fetchPhase = .failed
        }
    }

    /// Throws only the first failure since the last page loaded, so a failing scroll says so once.
    func loadMoreSpots() async throws {
        if let loadingMore {
            _ = await loadingMore.value
            return
        }
        guard standing.collection == nil, let cursor = nextCursor else {
            return
        }
        let loading = Task { () -> (any Error)? in
            isLoadingMore = true
            defer {
                loadingMore = nil
                isLoadingMore = false
            }
            do {
                let page = try await session.spots(of: id, after: cursor)
                remote?.spots += page.spots
                nextCursor = page.nextCursor
                isPagingFailing = false
                return nil
            } catch {
                Self.logger
                    .notice("A collection's next spots didn't load: \(String(describing: type(of: error)), privacy: .public)")
                defer { isPagingFailing = true }
                return isPagingFailing ? nil : error
            }
        }
        loadingMore = loading
        if let error = await loading.value {
            throw error
        }
    }

    func accept() async throws {
        try await perform(.accept) { try await $0.accept(invitationTo: $1) }
    }

    func decline() async throws {
        try await perform(.decline) { try await $0.decline(invitationTo: $1) }
    }

    func requestAccess() async throws {
        try await perform(.requestAccess) { try await $0.requestAccess(to: $1) }
    }

    func showOnMap() {
        links.open(.collectionMap(id: id))
    }

    func delete() async throws {
        try await perform(.delete) { try await $0.delete($1) }
    }

    func leave() async throws {
        try await perform(.leave) { try await $0.leave($1) }
    }

    func remove(_ spotID: String) async throws {
        guard removing.insert(spotID).inserted else {
            return
        }
        defer { removing.remove(spotID) }
        try await session.remove(spotID, from: id)
    }

    private func perform(_ action: Action, _ request: (CollectionsSession, String) async throws -> Void) async throws {
        guard self.action == nil else {
            return
        }
        self.action = action
        defer { self.action = nil }
        try await request(session, id)
    }
}
