public import Foundation
import os
public import SpotModelKit
public import SQLiteData

// MARK: - LibraryMatchEngine

/// Scans the photo library for shots taken at spots, off the main actor, and is the only writer of the match tables.
/// One scan at a time: a new one replaces the one under way; `reset()` cancels and clears for an ended account.
public actor LibraryMatchEngine {

    // MARK: Types

    public enum Outcome: Equatable, Sendable {
        case scanned
        /// Replaced by a newer scan, or the account ended.
        case cancelled
        case failed
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "library-match")
    /// Vision scales its input down to about this anyway; a larger thumbnail only costs decoding.
    private static let thumbnailSide: CGFloat = 360

    // MARK: Properties

    private let database: any DatabaseWriter
    private let library: PhotoLibrary
    private let classifier: ImageClassifier
    private let now: @Sendable () -> Date
    private let calendar: Calendar
    /// Moves on every `reset()`: a scan that began before it writes nothing.
    private var generation = 0
    private var running: Task<Outcome, Never>?

    // MARK: Lifecycle

    public init(database: any DatabaseWriter,
                library: PhotoLibrary,
                classifier: ImageClassifier,
                now: @escaping @Sendable () -> Date = Date.init,
                calendar: Calendar = .current) {
        self.database = database
        self.library = library
        self.classifier = classifier
        self.now = now
        self.calendar = calendar
    }

    // MARK: Functions

    /// Looks at what changed since the last scan (everything when access, or the spots, changed since); `onProgress`
    /// hears the share of candidate photos looked at so far, from 0 to 1.
    public func scan(isLimited: Bool, onProgress: @escaping @Sendable (Double) -> Void = { _ in }) async -> Outcome {
        running?.cancel()
        let task = Task { [generation] in
            await self.pass(isLimited: isLimited, generation: generation, onProgress: onProgress)
        }
        running = task
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if running == task {
            running = nil
        }
        return outcome
    }

    public func reset() async {
        generation += 1
        let scan = running
        scan?.cancel()
        _ = await scan?.value
        do {
            try await database.write { db in
                try LibraryMatch.delete().execute(db)
                try LibraryScan.delete().execute(db)
            }
        } catch {
            Self.logger.error("Clearing library matches failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    public func setState(_ state: LibraryMatchState, ofMatch id: LibraryMatch.ID) async {
        await write { db in
            try LibraryMatch.find(id).update { $0.state = #bind(state) }.execute(db)
        }
    }

    /// The photos went out with an edit: their matches leave the tab for good.
    public func markUsed(assetIDs: [String]) async {
        guard !assetIDs.isEmpty else {
            return
        }
        await write { db in
            try LibraryMatch.where { $0.assetID.in(assetIDs) }.update { $0.state = #bind(LibraryMatchState.used) }.execute(db)
        }
    }

    @concurrent
    private nonisolated func pass(isLimited: Bool, generation: Int, onProgress: @Sendable (Double) -> Void) async -> Outcome {
        do {
            let (last, spots) = try await database.read { db in
                let last = try LibraryScan.find(LibraryScan.rowID).fetchOne(db)
                let spots = try SpotIndex
                    .where { !$0.isPrivate && $0.condition.neq(SpotCondition.demolished) }
                    .select { ($0.id, $0.latitude, $0.longitude, $0.kind) }
                    .fetchAll(db)
                    .map { SpotPoint(id: $0, latitude: $1, longitude: $2, kind: $3) }
                return (last, spots)
            }
            let digest = LibraryMatcher.digest(of: spots)
            let since = last.flatMap { $0.isLimited == isLimited && $0.spotsDigest == digest ? $0.changeToken : nil }
            let changes = await library.changes(since)
            try Task.checkCancellation()
            let candidates = LibraryMatcher.candidates(
                among: changes.assets,
                near: LibraryMatcher.Locator(spots),
                calendar: calendar,
            )
            onProgress(0)
            var scored = [LibraryMatcher.Scored]()
            for (index, candidate) in candidates.enumerated() {
                try Task.checkCancellation()
                if let score = await LibraryMatcher.score(labels(of: candidate.asset.id), for: candidate, now: now()) {
                    scored.append(LibraryMatcher.Scored(candidate: candidate, score: score))
                }
                onProgress(Double(index + 1) / Double(candidates.count))
            }
            let scan = LibraryScan(changeToken: changes.token, isLimited: isLimited, spotsDigest: digest, scannedAt: now())
            try await save(LibraryMatcher.best(of: scored), from: changes, scan: scan, generation: generation)
            return .scanned
        } catch is CancellationError {
            return .cancelled
        } catch {
            Self.logger.error("A library scan failed: \(String(describing: type(of: error)), privacy: .public)")
            return .failed
        }
    }

    /// No labels when the photo has no local thumbnail or Vision fails: the match then rests on place and date alone.
    private nonisolated func labels(of assetID: String) async -> [String: Float] {
        guard let image = await library.image(assetID, Self.thumbnailSide, false) else {
            return [:]
        }
        do {
            return try await classifier.labels(image)
        } catch {
            Self.logger.notice("A photo couldn't be classified: \(String(describing: error), privacy: .public)")
            return [:]
        }
    }

    /// A complete read replaces every waiting match; a partial one replaces those of the photos it read again or lost.
    /// Skipped and used matches stay, and keep their spot and day from coming back.
    private func save(_ found: [LibraryMatch], from changes: LibraryChanges, scan: LibraryScan, generation: Int) async throws {
        guard generation == self.generation else {
            return
        }
        try await database.write { db in
            if changes.isComplete {
                try LibraryMatch.where { $0.state.eq(LibraryMatchState.new) }.delete().execute(db)
            } else {
                let gone = Array(changes.deletedIDs) + changes.assets.map(\.id)
                if !gone.isEmpty {
                    try LibraryMatch.where { $0.state.eq(LibraryMatchState.new) && $0.assetID.in(gone) }.delete().execute(db)
                }
            }
            let stored = try Dictionary(
                LibraryMatch.where { $0.id.in(found.map(\.id)) }.fetchAll(db).map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first },
            )
            let rows = found.filter { match in
                stored[match.id].map { $0.state == .new && $0.score < match.score } ?? true
            }
            if !rows.isEmpty {
                try LibraryMatch.upsert { rows }.execute(db)
            }
            try LibraryScan.upsert { scan }.execute(db)
        }
    }

    private func write(_ change: @escaping @Sendable (Database) throws -> Void) async {
        do {
            try await database.write(change)
        } catch {
            Self.logger.error("A library match change failed: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
