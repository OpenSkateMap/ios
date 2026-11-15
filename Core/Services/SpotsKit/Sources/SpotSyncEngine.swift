public import Foundation
import os
public import SpotModelKit
public import SQLiteData

public actor SpotSyncEngine {

    // MARK: Types

    public enum Outcome: Equatable, Sendable {
        case synced
        case failed(SpotsAPIError)
        case cancelled
    }

    public struct DetailStamp: Equatable, Sendable {
        let generation: Int
        let votes: Int
    }

    // MARK: Static Properties

    /// About 60 KB of index rows. DEBUG pages by 2, so the paging path runs on every developer launch.
    public static var defaultPageSize: Int {
        #if DEBUG
        2
        #else
        500
        #endif
    }

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "sync")

    // MARK: Properties

    public private(set) var generation = 0

    private let api: SpotsAPIManager
    private let database: any DatabaseWriter
    private let pageSize: Int
    private let now: @Sendable () -> Date
    private let passes = PassQueue<Outcome>()
    private var votes = 0
    private var votedAt = [String: Int]()

    // MARK: Lifecycle

    public init(api: SpotsAPIManager,
                database: any DatabaseWriter,
                pageSize: Int = SpotSyncEngine.defaultPageSize,
                now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.database = database
        self.pageSize = pageSize
        self.now = now
    }

    // MARK: Static Functions

    static func apply(_ page: SyncPage, from cursor: Int, reindexing: Bool, at now: Date, _ db: Database) throws -> Bool {
        guard let state = try SyncState.find(SyncState.rowID).fetchOne(db),
              state.resyncNeeded == reindexing,
              (reindexing ? state.reindexCursor : state.cursor) == cursor else {
            return false
        }
        var rows = page.items
        for index in rows.indices {
            rows[index].reindexEpoch = state.reindexEpoch
        }
        if !reindexing {
            // Only rows that move forward: a stale page can't take a spot back, and unchanged rows don't wake the map.
            let stored = try Dictionary(
                SpotIndex.where { $0.id.in(rows.map(\.id)) }.select { ($0.id, $0.version) }.fetchAll(db),
                uniquingKeysWith: { first, _ in first },
            )
            rows.removeAll { row in stored[row.id].map { $0 >= row.version } ?? false }
        }
        if !rows.isEmpty {
            try SpotIndex.upsert { rows }.execute(db)
        }
        if !page.tombstones.isEmpty {
            try SpotIndex.where { $0.id.in(page.tombstones) }.delete().execute(db)
        }
        var next = state
        if reindexing, page.hasMore {
            next.reindexCursor = page.nextCursor
        } else if reindexing {
            try SpotIndex.where { $0.reindexEpoch.lt(state.reindexEpoch) && $0.isPrivate.eq(false) }.delete().execute(db)
            next.cursor = page.nextCursor
            next.resyncNeeded = false
            next.reindexCursor = 0
        } else {
            next.cursor = page.nextCursor
        }
        if !page.hasMore {
            next.lastSuccessAt = now
        }
        try SyncState.upsert { next }.execute(db)
        return true
    }

    private static func write(_ totals: SpotVoteTotals, on spotID: String, _ db: Database) throws {
        try SpotDetail.find(spotID).update {
            $0.upvotes = #bind(totals.up)
            $0.downvotes = #bind(totals.down)
            $0.myVote = #bind(totals.mine)
        }
        .execute(db)
    }

    private static func beginReindex(expecting state: SyncState, _ db: Database) throws {
        guard try SyncState.find(SyncState.rowID).fetchOne(db) == state else {
            return
        }
        var next = state
        next.resyncNeeded = true
        next.reindexEpoch += 1
        next.reindexCursor = 0
        try SyncState.upsert { next }.execute(db)
    }

    // MARK: Functions

    /// `joining`: a pass already under way answers (launch, foreground); otherwise the next one, which sees everything
    /// changed before the call (a link to a spot not yet indexed, Try Again).
    public func sync(joining: Bool = false) async -> Outcome {
        await passes.run(joining: joining) { await self.pass() }
    }

    public func reset() async {
        generation += 1
        votedAt = [:]
        await passes.cancel()
        do {
            try await database.write { db in
                try SpotIndex.delete().execute(db)
                try City.delete().execute(db)
                try SpotScore.delete().execute(db)
                try SyncState.upsert { SyncState() }.execute(db)
            }
        } catch {
            Self.logger.error("Clearing local spots failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    public func replacePrivateSpots(with spots: [SpotIndex], requestedIn generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        try await database.write { db in
            let stored = try Dictionary(
                SpotIndex.where { $0.isPrivate.eq(true) }.select { ($0.id, $0.version) }.fetchAll(db),
                uniquingKeysWith: { first, _ in first },
            )
            var rows = spots
            for index in rows.indices {
                rows[index].isPrivate = true
            }
            let changed = rows.filter { stored[$0.id] != $0.version }
            if !changed.isEmpty {
                try SpotIndex.upsert { changed }.execute(db)
            }
            let kept = Set(rows.map(\.id))
            let gone = stored.keys.filter { !kept.contains($0) }
            if !gone.isEmpty {
                try SpotIndex.where { $0.id.in(gone) }.delete().execute(db)
            }
        }
    }

    /// A spot taken down on the server leaves now, as its tombstone would on the next pass.
    public func applyRemoval(of spotID: String) async throws {
        try await database.write { db in
            try SpotIndex.find(spotID).delete().execute(db)
        }
    }

    public func expireDetails() async throws {
        try await database.write { db in
            try SpotDetail.update { $0.fetchedAt = #bind(Date.distantPast) }.execute(db)
        }
    }

    public func detailStamp() -> DetailStamp {
        DetailStamp(generation: generation, votes: votes)
    }

    public func applyDetails(_ page: SpotDetailsPage, requestedAt stamp: DetailStamp) async throws {
        guard stamp.generation == generation, !page.spots.isEmpty else {
            return
        }
        let fetchedAt = now()
        let votedSince = Set(page.spots.map(\.id).filter { votedAt[$0, default: 0] > stamp.votes })
        try await database.write { db in
            let ids = page.spots.map(\.id)
            let indexed = try Set(SpotIndex.where { $0.id.in(ids) }.select { $0.id }.fetchAll(db))
            let stored = try Dictionary(SpotDetail.where { $0.id.in(ids) }.fetchAll(db).map { ($0.id, $0) }) { first, _ in
                first
            }
            for detail in page.spots where indexed.contains(detail.id) && (stored[detail.id]?.version ?? .min) <= detail.version {
                var row = detail.row(fetchedAt: fetchedAt)
                if votedSince.contains(detail.id), let kept = stored[detail.id] {
                    row.setVotes(SpotVoteTotals(kept))
                }
                try SpotDetail.upsert { row }.execute(db)
                // Compared, not keyed on the version: credits follow renames and blocks without one.
                let photos = detail.photoRows().sorted { ($0.position, $0.id) < ($1.position, $1.id) }
                let storedPhotos = try SpotPhoto.where { $0.spotID.eq(detail.id) }.order { ($0.position, $0.id) }.fetchAll(db)
                if storedPhotos != photos {
                    try SpotPhoto.where { $0.spotID.eq(detail.id) }.delete().execute(db)
                    if !photos.isEmpty {
                        try SpotPhoto.insert { photos }.execute(db)
                    }
                }
                let videos = detail.videoRows()
                let storedVideos = try SpotVideo.where { $0.spotID.eq(detail.id) }.order(by: \.position).fetchAll(db)
                if storedVideos != videos {
                    try SpotVideo.where { $0.spotID.eq(detail.id) }.delete().execute(db)
                    if !videos.isEmpty {
                        try SpotVideo.insert { videos }.execute(db)
                    }
                }
            }
        }
    }

    public func applyVote(_ vote: SpotVote, on spotID: String, requestedIn generation: Int) async throws -> SpotVoteTotals? {
        guard generation == self.generation else {
            return nil
        }
        markVote(on: spotID)
        return try await database.write { db in
            guard let row = try SpotDetail.find(spotID).fetchOne(db) else {
                return nil
            }
            let previous = SpotVoteTotals(row)
            try Self.write(previous.voting(vote), on: spotID, db)
            return previous
        }
    }

    public func applyVoteTotals(_ totals: SpotVoteTotals, on spotID: String, requestedIn generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        markVote(on: spotID)
        try await database.write { db in
            guard let row = try SpotDetail.find(spotID).fetchOne(db), SpotVoteTotals(row) != totals else {
                return
            }
            try Self.write(totals, on: spotID, db)
        }
    }

    private func markVote(on spotID: String) {
        votes += 1
        votedAt[spotID] = votes
    }

    private func pass() async -> Outcome {
        let generation = generation
        // They don't depend on the pages, so they load alongside them; they're still written after the last one.
        async let cities = fetched("Refreshing cities") { [api] in try await api.cities() }
        async let scores = fetched("Refreshing scores") { [api] in try await api.scores() }
        do {
            while true {
                try Task.checkCancellation()
                let state = try await database.read { db in try SyncState.find(SyncState.rowID).fetchOne(db) } ?? SyncState()
                let reindexing = state.resyncNeeded
                let cursor = reindexing ? state.reindexCursor : state.cursor
                let page = try await api.syncPage(cursor, pageSize)
                try Task.checkCancellation()
                guard generation == self.generation else {
                    return .cancelled
                }
                if page.resetRequired {
                    // Cursor 0 can never be ahead of the server; if it still says reset, retrying won't help.
                    guard !(reindexing && cursor == 0) else {
                        return .failed(.rejected)
                    }
                    try await database.write { db in try Self.beginReindex(expecting: state, db) }
                    continue
                }
                let now = now()
                let applied = try await database.write { db in
                    try Self.apply(page, from: cursor, reindexing: reindexing, at: now, db)
                }
                if applied, !page.hasMore {
                    break
                }
            }
            if let cities = await cities {
                await store(cities, generation: generation)
            }
            if let scores = await scores {
                await store(scores, generation: generation)
            }
            return .synced
        } catch is CancellationError {
            return .cancelled
        } catch let error as SpotsAPIError {
            return .failed(error)
        } catch {
            Self.logger.error("Sync failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failed(.unavailable)
        }
    }

    private nonisolated func fetched<Value: Sendable>(_ label: StaticString,
                                                      _ request: @Sendable () async throws -> Value) async -> Value? {
        do {
            return try await request()
        } catch {
            Self.logger.notice("\(label) failed: \(String(describing: type(of: error)), privacy: .public)")
            return nil
        }
    }

    private func store(_ cities: [City], generation: Int) async {
        do {
            guard generation == self.generation, !Task.isCancelled else {
                return
            }
            try await database.write { db in
                guard try City.order(by: \.id).fetchAll(db) != cities.sorted(by: { $0.id < $1.id }) else {
                    return
                }
                try City.delete().execute(db)
                if !cities.isEmpty {
                    try City.insert { cities }.execute(db)
                }
            }
        } catch {
            Self.logger.notice("Refreshing cities failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func store(_ scores: [SpotScore], generation: Int) async {
        do {
            guard generation == self.generation, !Task.isCancelled else {
                return
            }
            try await database.write { db in
                let stored = try Dictionary(SpotScore.fetchAll(db).map { ($0.id, $0) }) { first, _ in first }
                let changed = scores.filter { stored[$0.id] != $0 }
                if !changed.isEmpty {
                    try SpotScore.upsert { changed }.execute(db)
                }
                let kept = Set(scores.map(\.id))
                let gone = stored.keys.filter { !kept.contains($0) }
                if !gone.isEmpty {
                    try SpotScore.where { $0.id.in(gone) }.delete().execute(db)
                }
            }
        } catch {
            Self.logger.notice("Refreshing scores failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
