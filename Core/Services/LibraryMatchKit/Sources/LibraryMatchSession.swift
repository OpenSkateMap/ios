public import Observation
public import SpotModelKit

// MARK: - LibraryMatchSession

/// Finding the person's shots of spots in their photo library: access, the scan under way, and what they did with each
/// match. The matches themselves are in SQLite (`LibraryMatch`), which screens read.
@MainActor
@Observable
public final class LibraryMatchSession {

    // MARK: Nested Types

    public enum Phase: Equatable, Sendable {
        /// Access isn't read yet.
        case unknown
        /// Never asked: only Find My Shots asks.
        case notAsked
        case denied
        case scanning(progress: Double)
        case ready
        /// Ready, having looked only at the photos the person chose to share.
        case limited
    }

    private struct Scan {
        let id: Int
        let isLimited: Bool
        let task: Task<Void, Never>
    }

    // MARK: Properties

    public private(set) var phase = Phase.unknown

    @ObservationIgnored private let engine: LibraryMatchEngine
    @ObservationIgnored private let library: PhotoLibrary
    @ObservationIgnored private var scan: Scan?
    @ObservationIgnored private var lastScanID = 0

    // MARK: Lifecycle

    public init(engine: LibraryMatchEngine, library: PhotoLibrary) {
        self.engine = engine
        self.library = library
    }

    isolated deinit {
        scan?.task.cancel()
    }

    // MARK: Static Functions

    /// Reading it can wait on the photos daemon, which would hold the main thread up.
    @concurrent
    private nonisolated static func access(_ library: PhotoLibrary) async -> PhotoAccess {
        library.access()
    }

    private nonisolated static func scanning(_ engine: LibraryMatchEngine,
                                 isLimited: Bool,
                                 report: AsyncStream<Double>.Continuation) async -> LibraryMatchEngine.Outcome {
        let outcome = await engine.scan(isLimited: isLimited) { report.yield($0) }
        report.finish()
        return outcome
    }

    // MARK: Functions

    /// Reads access without asking, and once it's granted looks at what changed since the last scan. Returns when that
    /// scan ends; a scan under way is joined, unless access changed under it.
    public func refresh() async {
        await apply(Self.access(library))
    }

    /// Find My Shots: the system asks for access when it hasn't been answered, then the library is scanned.
    public func findMyShots() async {
        await apply(library.requestAccess())
    }

    /// Not This One.
    public func skip(_ id: LibraryMatch.ID) async {
        await engine.setState(.skipped, ofMatch: id)
    }

    public func markUsed(assetIDs: [String]) async {
        await engine.markUsed(assetIDs: assetIDs)
    }

    private func apply(_ access: PhotoAccess) async {
        switch access {
        case .notDetermined:
            stopScanning()
            phase = .notAsked

        case .denied:
            stopScanning()
            phase = .denied

        case .limited, .full:
            let isLimited = access == .limited
            if let scan, scan.isLimited == isLimited {
                return await scan.task.value
            }
            await startScan(isLimited: isLimited).value
        }
    }

    /// Replaces a scan under way: one at a time, and the newest access decides what's looked at.
    private func startScan(isLimited: Bool) -> Task<Void, Never> {
        scan?.task.cancel()
        lastScanID += 1
        let id = lastScanID
        phase = .scanning(progress: 0)
        let (progress, report) = AsyncStream.makeStream(of: Double.self, bufferingPolicy: .bufferingNewest(1))
        let task = Task { [weak self, engine] in
            async let outcome = Self.scanning(engine, isLimited: isLimited, report: report)
            for await value in progress {
                self?.show(progress: value, of: id)
            }
            let ended = await outcome
            self?.finish(id, outcome: ended, isLimited: isLimited)
        }
        scan = Scan(id: id, isLimited: isLimited, task: task)
        return task
    }

    private func show(progress: Double, of id: Int) {
        guard scan?.id == id else {
            return
        }
        phase = .scanning(progress: progress)
    }

    private func finish(_ id: Int, outcome: LibraryMatchEngine.Outcome, isLimited: Bool) {
        guard scan?.id == id else {
            return
        }
        scan = nil
        switch outcome {
        // A failure keeps the matches found before; the engine logs it.
        case .scanned, .failed: phase = isLimited ? .limited : .ready
        // Cancelled from outside (the account ended): the next refresh reads access and scans again.
        case .cancelled: phase = .unknown
        }
    }

    private func stopScanning() {
        scan?.task.cancel()
        scan = nil
    }
}
