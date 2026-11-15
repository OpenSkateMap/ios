public import Foundation
import os
import SpotModelKit
public import SQLiteData
import Synchronization

// MARK: - ReviewQueueStore

public struct ReviewQueueStore: Sendable {
    /// Moves on every `clear()`: a save from a session that began before it is dropped.
    public var generation: @Sendable () -> Int
    public var load: @Sendable () async -> ReviewQueue?
    public var save: @Sendable (_ queue: ReviewQueue, _ generation: Int) async -> Void
    public var clear: @Sendable () async -> Void

    public init(generation: @escaping @Sendable () -> Int,
                load: @escaping @Sendable () async -> ReviewQueue?,
                save: @escaping @Sendable (_ queue: ReviewQueue, _ generation: Int) async -> Void,
                clear: @escaping @Sendable () async -> Void) {
        self.generation = generation
        self.load = load
        self.save = save
        self.clear = clear
    }
}

extension ReviewQueueStore {
    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "review")

    public static let none = ReviewQueueStore(generation: { 0 }, load: { nil }, save: { _, _ in }, clear: { })

    public static func live(database: any DatabaseWriter, now: @escaping @Sendable () -> Date = Date.init) -> ReviewQueueStore {
        let generation = Mutex(0)
        return ReviewQueueStore(
            generation: { generation.withLock { $0 } },
            load: {
                do {
                    // Decoded on the database's queue: this closure runs on its caller's actor, the main one.
                    return try await database.read { db in
                        try ReviewQueueCache.find(ReviewQueueCache.rowID).fetchOne(db)
                            .map { try JSONDecoder().decode(ReviewQueue.self, from: $0.payload) }
                    }
                } catch {
                    logger.notice("No cached review queue: \(String(describing: type(of: error)), privacy: .public)")
                    return nil
                }
            },
            save: { queue, from in
                do {
                    // Checked inside the write, which clear() also goes through, so none lands after a clear. Encoded
                    // there too, off the caller's actor.
                    try await database.write { db in
                        guard generation.withLock({ $0 }) == from else {
                            return
                        }
                        let row = try ReviewQueueCache(payload: JSONEncoder().encode(queue), savedAt: now())
                        try ReviewQueueCache.upsert { row }.execute(db)
                    }
                } catch {
                    logger.error("The review queue wasn't cached: \(String(describing: type(of: error)), privacy: .public)")
                }
            },
            clear: {
                do {
                    try await database.write { db in
                        generation.withLock { $0 += 1 }
                        try ReviewQueueCache.delete().execute(db)
                    }
                } catch {
                    logger
                        .error("The review queue cache wasn't cleared: \(String(describing: type(of: error)), privacy: .public)")
                }
            },
        )
    }
}
