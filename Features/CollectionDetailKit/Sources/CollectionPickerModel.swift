import CollectionsKit
import FactoryKit
import Observation
import SpotModelKit
import SQLiteData

@MainActor
@Observable
final class CollectionPickerModel {

    // MARK: Computed Properties

    var rows: [SavedIn] {
        stored
    }

    // MARK: Properties

    let spotID: String
    private(set) var busy = Set<String>()
    private(set) var isCreating = false

    @ObservationIgnored @Fetch private var stored: [SavedIn]
    @ObservationIgnored @LazyInjected(\.collectionsSession) private var session

    // MARK: Lifecycle

    init(spotID: String) {
        self.spotID = spotID
        _stored = Fetch(wrappedValue: [], SavedInRequest(spotID: spotID))
    }

    // MARK: Functions

    func toggle(_ collectionID: String) async throws {
        guard !busy.contains(collectionID), let row = stored.first(where: { $0.collection.id == collectionID }) else {
            return
        }
        busy.insert(collectionID)
        defer { busy.remove(collectionID) }
        if row.contains {
            try await session.remove(spotID, from: collectionID)
        } else {
            try await session.add(spotID, to: collectionID)
        }
    }

    func createAndSave(named name: String) async throws {
        guard !isCreating else {
            return
        }
        let id = try await create(named: name)
        busy.insert(id)
        defer { busy.remove(id) }
        try await session.add(spotID, to: id)
    }

    private func create(named name: String) async throws -> String {
        isCreating = true
        defer { isCreating = false }
        return try await session.create(CollectionDraft(name: name))
    }
}
