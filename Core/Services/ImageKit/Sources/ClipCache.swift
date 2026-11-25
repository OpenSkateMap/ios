import CryptoKit
public import Foundation
import os

/// Clips kept on disk as whole files named by their URL's hash, so a clip plays at once and offline the second time. It
/// owns the folder, the downloads (one per URL, whoever asked) and eviction.
public actor ClipCache {

    // MARK: Types

    private enum Purpose {
        case prefetch
        case playback
    }

    private struct Download {
        let id: UUID
        let task: URLSessionDownloadTask
        var purpose: Purpose
    }

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "clips")

    // MARK: Properties

    private let directory: URL
    private let session: URLSession
    private let sizeLimit: Int
    private var downloads = [URL: Download]()
    private var playing = [URL: Int]()
    private var prefetches = [UUID: Set<URL>]()
    private var idleWaiters = [CheckedContinuation<Void, Never>]()

    // MARK: Lifecycle

    public init(directory: URL, session: URLSession, sizeLimit: Int = 300 << 20) {
        self.directory = directory
        self.session = session
        self.sizeLimit = sizeLimit
    }

    deinit {
        session.invalidateAndCancel()
    }

    // MARK: Static Functions

    /// Runs on the session's queue, before URLSession deletes what it downloaded: the file lands as `.part`, then takes
    /// the clip's name in one rename, so a file under that name is always whole.
    private static func keep(_ location: URL?,
                             _ response: URLResponse?,
                             _ error: any Error?,
                             part: URL,
                             file: URL) throws {
        if let error {
            throw error
        }
        guard let location, (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        let files = FileManager.default
        // The session's queue is serial, so no other download writes these names meanwhile.
        try? files.removeItem(at: part)
        try files.moveItem(at: location, to: part)
        do {
            if files.fileExists(atPath: file.path(percentEncoded: false)) {
                try files.removeItem(at: part)
            } else {
                try files.moveItem(at: part, to: file)
            }
        } catch {
            try? files.removeItem(at: part)
            throw error
        }
    }

    private static func name(of url: URL) -> String {
        SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static func isRoutine(_ error: any Error) -> Bool {
        guard let error = error as? URLError else {
            return false
        }
        return error.code == .cancelled || error.code == .notConnectedToInternet || error.networkUnavailableReason != nil
    }

    // MARK: Functions

    /// Where the clip's file is, whether or not it's there yet.
    public nonisolated func file(for url: URL) -> URL {
        directory.appending(path: "\(Self.name(of: url)).mp4")
    }

    /// The clip's file when it's here (dated now, for eviction); otherwise nil, and the clip downloads alongside the
    /// stream (or a prefetch already running is raised to it), so the next play has it. The file stays until
    /// `endPlaying(_:)`.
    public func beginPlaying(_ url: URL) -> URL? {
        playing[url, default: 0] += 1
        let file = file(for: url)
        if FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) {
            touch(file)
            return file
        }
        download(url, for: .playback)
        return nil
    }

    public func endPlaying(_ url: URL) {
        guard let count = playing[url] else {
            return
        }
        playing[url] = count > 1 ? count - 1 : nil
    }

    /// What `owner` wants ahead of time, in place of what it wanted before. Each clip not here yet downloads at low
    /// priority and never over an expensive or constrained network; one nobody wants any more stops, unless a play
    /// joined it.
    public func prefetch(_ urls: [URL], for owner: UUID) {
        prefetches[owner] = urls.isEmpty ? nil : Set(urls)
        let wanted = prefetches.values.reduce(into: Set<URL>()) { $0.formUnion($1) }
        for (url, download) in downloads where download.purpose == .prefetch && !wanted.contains(url) {
            download.task.cancel()
            downloads[url] = nil
        }
        for url in wanted where !FileManager.default.fileExists(atPath: file(for: url).path(percentEncoded: false)) {
            download(url, for: .prefetch)
        }
        resumeIdleWaitersIfIdle()
    }

    /// Clears what a download cut short left behind, then removes the least recently played clips until the folder fits
    /// its limit, never one playing now.
    public func sweep() {
        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey]
        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)
        } catch CocoaError.fileReadNoSuchFile {
            return
        } catch {
            Self.logger.error("Could not list the clips folder: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        let downloading = Set(downloads.keys.map { "\(Self.name(of: $0)).part" })
        let pinned = Set(playing.keys.map { file(for: $0).lastPathComponent })
        var clips = [(file: URL, size: Int, date: Date)]()
        for item in contents {
            if item.pathExtension == "part" {
                if !downloading.contains(item.lastPathComponent) {
                    remove(item)
                }
                continue
            }
            let values = try? item.resourceValues(forKeys: Set(keys))
            clips.append((item, values?.fileSize ?? 0, values?.contentModificationDate ?? .distantPast))
        }
        var total = clips.reduce(0) { $0 + $1.size }
        for clip in clips.sorted(by: { $0.date < $1.date }) where total > sizeLimit {
            guard !pinned.contains(clip.file.lastPathComponent) else {
                continue
            }
            remove(clip.file)
            total -= clip.size
        }
    }

    /// Everything goes, downloads included, when an account ends: a private spot's clips belong to whoever loaded them.
    public func removeAll() {
        for download in downloads.values {
            download.task.cancel()
        }
        downloads.removeAll()
        prefetches.removeAll()
        resumeIdleWaitersIfIdle()
        remove(directory)
    }

    /// Returns once no download is running.
    func idle() async {
        guard !downloads.isEmpty else {
            return
        }
        await withCheckedContinuation { idleWaiters.append($0) }
    }

    private func download(_ url: URL, for purpose: Purpose) {
        if var running = downloads[url] {
            if purpose == .playback, running.purpose == .prefetch {
                running.purpose = .playback
                running.task.priority = URLSessionTask.highPriority
                downloads[url] = running
            }
            return
        }
        var request = URLRequest(url: url)
        if purpose == .prefetch {
            request.allowsExpensiveNetworkAccess = false
            request.allowsConstrainedNetworkAccess = false
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Could not make the clips folder: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        let id = UUID()
        let part = directory.appending(path: "\(Self.name(of: url)).part")
        let file = file(for: url)
        let task = session.downloadTask(with: request) { [weak self] location, response, error in
            let outcome = Result { try Self.keep(location, response, error, part: part, file: file) }
            Task {
                await self?.finish(url, id: id, outcome: outcome)
            }
        }
        task.priority = purpose == .playback ? URLSessionTask.highPriority : URLSessionTask.lowPriority
        downloads[url] = Download(id: id, task: task, purpose: purpose)
        task.resume()
    }

    private func finish(_ url: URL, id: UUID, outcome: Result<Void, any Error>) {
        guard let download = downloads[url], download.id == id else {
            return
        }
        downloads[url] = nil
        if case .failure(let error) = outcome {
            let wasLimited = download.task.originalRequest?.allowsExpensiveNetworkAccess == false
            if download.purpose == .playback, wasLimited, (error as? URLError)?.networkUnavailableReason != nil {
                // A play raised a prefetch that only the network it may not use could finish.
                self.download(url, for: .playback)
            } else if Self.isRoutine(error) {
                Self.logger.debug("A clip didn't download: \(String(describing: error), privacy: .public)")
            } else {
                Self.logger.notice("A clip didn't download: \(String(describing: error), privacy: .public)")
            }
        }
        resumeIdleWaitersIfIdle()
    }

    private func resumeIdleWaitersIfIdle() {
        guard downloads.isEmpty else {
            return
        }
        for waiter in idleWaiters {
            waiter.resume()
        }
        idleWaiters.removeAll()
    }

    private func touch(_ file: URL) {
        do {
            try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path(percentEncoded: false))
        } catch {
            Self.logger.error("Could not date a clip: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func remove(_ item: URL) {
        do {
            try FileManager.default.removeItem(at: item)
        } catch CocoaError.fileNoSuchFile {
            return
        } catch {
            Self.logger.error("Could not remove a clip file: \(String(describing: type(of: error)), privacy: .public)")
        }
    }
}
