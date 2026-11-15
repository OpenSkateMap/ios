import Foundation
import SpotModelKit
@testable import SpotsKit

actor FakeSpotServer {

    // MARK: Types

    private struct Entry {
        var spot: SpotIndex
        var removed: Bool
    }

    // MARK: Computed Properties

    nonisolated var api: SpotsAPIManager {
        SpotsAPIManager(
            syncPage: { try await self.syncPage(cursor: $0, limit: $1) },
            details: { ids in SpotDetailsPage(spots: [], missing: ids) },
            cities: { [] },
            vote: { _, _ in throw SpotsAPIError.rejected },
            scores: { await self.scores },
        )
    }

    // MARK: Properties

    private(set) var requestedCursors = [Int]()

    var scores = [SpotScore]()

    private var entries = [String: Entry]()
    private var head = 0
    private var failingCursor: Int?

    // MARK: Functions

    func rate(_ scores: [SpotScore]) {
        self.scores = scores
    }

    func publish(_ id: String,
                 title: String? = nil,
                 latitude: Double = 51.5,
                 longitude: Double = -0.12,
                 obstacles: [String] = []) {
        head += 1
        entries[id] = Entry(
            spot: SpotIndex(
                id: id,
                title: title ?? id,
                kind: .street,
                condition: .skateable,
                cityID: nil,
                latitude: latitude,
                longitude: longitude,
                version: head,
                obstacles: obstacles,
            ),
            removed: false,
        )
    }

    func remove(_ id: String) {
        head += 1
        entries[id]?.removed = true
        entries[id]?.spot.version = head
    }

    func replaceAll(with ids: [String]) {
        entries = [:]
        head = 0
        for id in ids {
            publish(id)
        }
    }

    func failOnce(at cursor: Int) {
        failingCursor = cursor
    }

    func syncPage(cursor: Int, limit: Int) throws -> SyncPage {
        requestedCursors.append(cursor)
        if failingCursor == cursor {
            failingCursor = nil
            throw SpotsAPIError.offline
        }
        guard cursor <= head else {
            return SyncPage(items: [], tombstones: [], nextCursor: 0, hasMore: false, resetRequired: true)
        }
        let changed = entries.values.filter { $0.spot.version > cursor }.sorted { $0.spot.version < $1.spot.version }
        let page = changed.prefix(limit)
        return SyncPage(
            items: page.filter { !$0.removed }.map(\.spot),
            tombstones: page.filter(\.removed).map(\.spot.id),
            nextCursor: page.last?.spot.version ?? cursor,
            hasMore: changed.count > limit,
            resetRequired: false,
        )
    }

}
