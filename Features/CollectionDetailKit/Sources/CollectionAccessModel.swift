import CollectionsKit
import FactoryKit
import IdentifiedCollections
import Observation
import SpotModelKit

@MainActor
@Observable
final class CollectionAccessModel {

    // MARK: Types

    enum Phase: Equatable {
        case loading
        case loaded(CollectionAccess)
        case failed
    }

    enum VisibilityConfirmation: Equatable {
        case makePublic(privateSpotCount: Int)
        case makePrivate

        var visibility: CollectionVisibility {
            switch self {
            case .makePublic: .public
            case .makePrivate: .private
            }
        }
    }

    enum Change: Hashable {
        case visibility(CollectionVisibility)
        case addPeople
        case member(String)
        case invite(String)
        case request(String)
    }

    // MARK: Computed Properties

    var managesPeople: Bool {
        role.managesPeople
    }

    var changingVisibility: CollectionVisibility? {
        for case .visibility(let visibility) in changes {
            return visibility
        }
        return nil
    }

    var showsLinks: Bool {
        guard draft.visibility == .private else {
            return true
        }
        guard case .loaded(let access) = phase else {
            return false
        }
        return !access.members.isEmpty || !access.invites.isEmpty
    }

    // MARK: Properties

    let collectionID: String
    let role: CollectionRole
    private(set) var draft: CollectionDraft
    let privateSpotCount: Int
    private(set) var phase = Phase.loading
    private(set) var changes = Set<Change>()

    /// Changes are numbered as they start; an answer older than one already shown is dropped, and the list is read again once all have answered.
    @ObservationIgnored private var lastStarted = 0
    @ObservationIgnored private var lastShown = 0
    @ObservationIgnored private var needsReload = false
    @ObservationIgnored @LazyInjected(\.collectionsSession) private var session

    // MARK: Lifecycle

    init(collectionID: String, role: CollectionRole, draft: CollectionDraft, privateSpotCount: Int) {
        self.collectionID = collectionID
        self.role = role
        self.draft = draft
        self.privateSpotCount = privateSpotCount
    }

    // MARK: Functions

    func load() async {
        if phase == .failed {
            phase = .loading
        }
        do {
            let access = try await session.access(of: collectionID)
            draft.visibility = access.visibility
            phase = .loaded(access)
        } catch {
            if case .loaded = phase {
                return
            }
            phase = .failed
        }
    }

    func confirmation(for visibility: CollectionVisibility) -> VisibilityConfirmation? {
        guard visibility != draft.visibility, changingVisibility == nil else {
            return nil
        }
        return switch visibility {
        case .public: .makePublic(privateSpotCount: privateSpotCount)
        case .private: .makePrivate
        }
    }

    func confirm(_ confirmation: VisibilityConfirmation) async throws {
        var changed = draft
        changed.visibility = confirmation.visibility
        try await change(.visibility(confirmation.visibility), edit: { $0.visibility = changed.visibility }) {
            try await self.session.update(self.collectionID, to: changed)
            self.draft = changed
            return nil
        }
    }

    func invite(_ typed: String, as role: CollectionMemberRole) async throws {
        guard let invitee = CollectionInvitee(typed: typed) else {
            return
        }
        try await change(.addPeople) { try await self.session.share(self.collectionID, with: invitee, as: role) }
    }

    func setRole(_ role: CollectionMemberRole, of member: CollectionAccess.Member) async throws {
        guard role != member.role else {
            return
        }
        try await change(.member(member.id)) { try await self.session.setRole(role, of: member.id, in: self.collectionID) }
    }

    func remove(_ member: CollectionAccess.Member) async throws {
        try await change(.member(member.id), edit: { $0.members.remove(id: member.id) }) {
            try await self.session.removeMember(member.id, from: self.collectionID)
            return nil
        }
    }

    func cancel(_ invite: CollectionAccess.Invite) async throws {
        try await change(.invite(invite.id)) { try await self.session.cancelInvite(invite.id, to: self.collectionID) }
    }

    func letIn(_ request: CollectionAccess.Request, as role: CollectionMemberRole) async throws {
        try await change(.request(request.id)) {
            try await self.session.approve(request.id, into: self.collectionID, as: role)
        }
    }

    func decline(_ request: CollectionAccess.Request) async throws {
        try await change(.request(request.id)) { try await self.session.decline(request.id, askingFor: self.collectionID) }
    }

    /// `write` returns the access the server answered with, or nil to read it again; `edit` applies the write to the
    /// shown access when that read fails, so a change that went through never reads as failed.
    private func change(_ key: Change,
                        edit: (inout CollectionAccess) -> Void = { _ in },
                        _ write: () async throws -> CollectionAccess?) async throws {
        guard changes.insert(key).inserted else {
            return
        }
        lastStarted += 1
        let number = lastStarted
        do {
            var access = try await write()
            if access == nil {
                access = await accessAfterWrite(edit)
            }
            if let access {
                show(access, number: number)
            }
        } catch {
            changes.remove(key)
            throw error
        }
        changes.remove(key)
        if changes.isEmpty, needsReload {
            needsReload = false
            await load()
        }
    }

    private func accessAfterWrite(_ edit: (inout CollectionAccess) -> Void) async -> CollectionAccess? {
        if let access = try? await session.access(of: collectionID) {
            return access
        }
        guard case .loaded(var access) = phase else {
            return nil
        }
        edit(&access)
        return access
    }

    private func show(_ access: CollectionAccess, number: Int) {
        guard number > lastShown else {
            needsReload = true
            return
        }
        lastShown = number
        draft.visibility = access.visibility
        phase = .loaded(access)
    }
}
