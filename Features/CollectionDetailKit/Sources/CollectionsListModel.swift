import CollectionsKit
import FactoryKit
import Foundation
import Observation
import SpotModelKit
import SQLiteData

@MainActor
@Observable
final class CollectionsListModel {

    // MARK: Types

    enum Source: Equatable {
        case mine
        case user(id: String)
    }

    enum Phase: Equatable {
        case loading
        case loaded
        case failed
    }

    // MARK: Computed Properties

    var own: [CollectionRow] {
        switch source {
        case .mine: stored.filter { $0.role == .owner }
        case .user: remote
        }
    }

    var shared: [CollectionRow] {
        source == .mine ? stored.filter { $0.role != .owner && $0.role.isMember } : []
    }

    var invitations: [CollectionInvitation] {
        source == .mine ? storedInvitations : []
    }

    var phase: Phase {
        guard source == .mine else {
            return userPhase
        }
        switch session.lastOutcome {
        case .failed?: return .failed
        case .synced?, .cancelled?: return .loaded
        case nil: return session.isSyncing ? .loading : .loaded
        }
    }

    // MARK: Properties

    let source: Source
    private(set) var remote = [CollectionRow]()
    private(set) var isCreating = false

    private var userPhase = Phase.loading

    @ObservationIgnored @Fetch(CollectionsListRequest()) private var stored = []
    @ObservationIgnored @FetchAll(CollectionInvitation.order { $0.position }) private var storedInvitations
    @ObservationIgnored @LazyInjected(\.collectionsSession) private var session

    // MARK: Lifecycle

    init(source: Source) {
        self.source = source
    }

    // MARK: Functions

    func refresh() async -> (any Error)? {
        switch source {
        case .mine:
            await session.syncNow()
            guard case .failed(let error) = session.lastOutcome else {
                return nil
            }
            return error

        case .user(let id):
            do {
                remote = try await session.collections(of: id).map(CollectionRow.init)
                userPhase = .loaded
                return nil
            } catch {
                userPhase = remote.isEmpty ? .failed : .loaded
                return error
            }
        }
    }

    func create(named name: String) async throws -> String {
        isCreating = true
        defer { isCreating = false }
        return try await session.create(CollectionDraft(name: name))
    }
}
