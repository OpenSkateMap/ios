public import Foundation
import os
import SpotModelKit
public import SQLiteData

public actor DetailFetcher {

    // MARK: Static Properties

    private static let debounceDelay = Duration.milliseconds(150)
    private static let batchSize = 100
    private static let maxBatchesInFlight = 3
    private static let freshness: TimeInterval = 5 * 60
    private static let retryAfter: TimeInterval = 20

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "details")

    // MARK: Properties

    private let api: SpotsAPIManager
    private let engine: SpotSyncEngine
    private let database: any DatabaseReader
    private let clock: any Clock<Duration>
    private let now: @Sendable () -> Date

    private var selected: String?
    private var visible = [String]()
    private var inFlight = Set<String>()
    private var restingUntil = [String: Date]()
    private var failed = Set<String>()
    private var debounce: Task<Void, Never>?
    private var flushing: Task<Void, Never>?
    private var demandChangedWhileFlushing = false

    // MARK: Lifecycle

    public init(api: SpotsAPIManager,
                engine: SpotSyncEngine,
                database: any DatabaseReader,
                clock: any Clock<Duration> = ContinuousClock(),
                now: @escaping @Sendable () -> Date = Date.init) {
        self.api = api
        self.engine = engine
        self.database = database
        self.clock = clock
        self.now = now
    }

    // MARK: Static Functions

    static func needingFetch(_ ids: [String], in database: any DatabaseReader, freshAfter: Date) async throws -> [String] {
        try await database.read { db in
            let versions = try Dictionary(
                SpotIndex.where { $0.id.in(ids) }.select { ($0.id, $0.version) }.fetchAll(db),
                uniquingKeysWith: { first, _ in first },
            )
            let details = try Dictionary(
                SpotDetail.where { $0.id.in(ids) }.select { ($0.id, $0.fetchedAt, $0.version) }.fetchAll(db)
                    .map { ($0, ($1, $2)) },
                uniquingKeysWith: { first, _ in first },
            )
            return ids.filter { id in
                guard let version = versions[id] else {
                    return false
                }
                guard let (fetchedAt, storedVersion) = details[id] else {
                    return true
                }
                return fetchedAt < freshAfter || storedVersion < version
            }
        }
    }

    // MARK: Functions

    public func show(_ ids: [String]) {
        visible = ids
        debounce?.cancel()
        debounce = Task { [clock] in
            do {
                try await clock.sleep(for: Self.debounceDelay)
            } catch {
                return
            }
            await flush()
        }
    }

    /// Asks for the selected spot first; true when its details couldn't be fetched. Retrying skips the pause after a failure.
    @discardableResult
    public func select(_ id: String?, retrying: Bool = false) async -> Bool {
        selected = id
        guard let id else {
            return false
        }
        if retrying {
            restingUntil[id] = nil
        }
        await flush()
        return failed.contains(id)
    }

    public func refresh() async {
        await flush()
    }

    func flush() async {
        if let flushing {
            demandChangedWhileFlushing = true
            await flushing.value
            return
        }
        let task = Task {
            repeat {
                demandChangedWhileFlushing = false
                await fetchNeeded()
            } while demandChangedWhileFlushing
        }
        flushing = task
        await task.value
        flushing = nil
    }

    private func fetchNeeded() async {
        let now = now()
        var demand = [String]()
        var seen = Set<String>()
        for id in [selected].compactMap(\.self) + visible where seen.insert(id).inserted {
            if !inFlight.contains(id), (restingUntil[id] ?? .distantPast) <= now {
                demand.append(id)
            }
        }
        guard !demand.isEmpty else {
            return
        }
        let needed: [String]
        do {
            needed = try await Self.needingFetch(
                demand,
                in: database,
                freshAfter: now.addingTimeInterval(-Self.freshness),
            )
        } catch {
            Self.logger.error("Reading detail freshness failed: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        let batches = stride(from: 0, to: needed.count, by: Self.batchSize).map {
            Array(needed[$0..<min($0 + Self.batchSize, needed.count)])
        }
        await withTaskGroup(of: Void.self) { group in
            var running = 0
            for batch in batches {
                if running == Self.maxBatchesInFlight {
                    await group.next()
                    running -= 1
                }
                inFlight.formUnion(batch)
                group.addTask { await self.fetch(batch) }
                running += 1
            }
        }
    }

    private func fetch(_ batch: [String]) async {
        let stamp = await engine.detailStamp()
        do {
            let page = try await api.details(batch)
            try await engine.applyDetails(page, requestedAt: stamp)
            rest(page.missing)
            failed.subtract(batch)
        } catch {
            Self.logger.notice("Fetching \(batch.count) details failed: \(String(describing: type(of: error)), privacy: .public)")
            rest(batch)
            failed.formUnion(batch)
        }
        inFlight.subtract(batch)
    }

    private func rest(_ ids: [String]) {
        let until = now().addingTimeInterval(Self.retryAfter)
        for id in ids {
            restingUntil[id] = until
        }
    }

}
