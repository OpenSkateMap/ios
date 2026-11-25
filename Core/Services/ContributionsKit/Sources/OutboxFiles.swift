public import Foundation
import os

public struct OutboxFiles: Sendable {

    // MARK: Static Properties

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "outbox")

    // MARK: Properties

    public let directory: URL

    // MARK: Lifecycle

    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: Static Functions

    public static func applicationSupport() -> OutboxFiles {
        OutboxFiles(directory: URL.applicationSupportDirectory.appending(path: "Outbox", directoryHint: .isDirectory))
    }

    // MARK: Functions

    func write(_ data: Data, named name: String) throws {
        try makeDirectory()
        try data.write(to: url(name), options: .atomic)
    }

    /// Takes over a file someone else wrote, such as a prepared clip in the temporary folder.
    func move(_ file: URL, named name: String) throws {
        try makeDirectory()
        try FileManager.default.moveItem(at: file, to: url(name))
        // Dated now, as a written file is: the orphan sweep spares files younger than ten minutes.
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url(name).path(percentEncoded: false))
    }

    func read(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }

    func url(_ name: String) -> URL {
        directory.appending(path: name)
    }

    func remove(_ names: [String]) {
        for name in names {
            do {
                try FileManager.default.removeItem(at: url(name))
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                Self.logger.error("Could not remove an outbox file: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
    }

    func removeOrphans(keeping kept: Set<String>, olderThan cutoff: Date) {
        let names: [URL]
        do {
            names = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
            )
        } catch CocoaError.fileReadNoSuchFile {
            return
        } catch {
            Self.logger.error("Could not list the outbox folder: \(String(describing: type(of: error)), privacy: .public)")
            return
        }
        let orphans = names.filter { file in
            guard !kept.contains(file.lastPathComponent) else {
                return false
            }
            let written = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            return (written ?? .distantPast) < cutoff
        }
        remove(orphans.map(\.lastPathComponent))
    }

    func removeAll() {
        guard FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Self.logger.error("Could not clear the outbox folder: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func makeDirectory() throws {
        guard !FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var folder = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try folder.setResourceValues(values)
    }

}
