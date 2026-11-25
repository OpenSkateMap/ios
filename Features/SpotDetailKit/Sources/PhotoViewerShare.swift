import Foundation
import UIKit

/// Share in the viewer: the page's photo or clip, a line naming the spot and who took it, and the spot's link.
enum PhotoViewerShare {

    // MARK: Types

    enum Media {
        case image(UIImage)
        /// A downloaded clip, alone in a temporary folder until `discard()`.
        case clip(URL)

        // MARK: Computed Properties

        var item: Any {
            switch self {
            case .image(let image): image
            case .clip(let file): file
            }
        }

        var image: UIImage? {
            if case .image(let image) = self {
                image
            } else {
                nil
            }
        }

        // MARK: Functions

        func discard() {
            if case .clip(let file) = self {
                try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
            }
        }
    }

    // MARK: Static Functions

    static func text(spot: String, credit: String?, isClip: Bool) -> String {
        guard let credit, !credit.isEmpty else {
            return spot
        }
        return isClip
            ? SpotDetailKitStrings.PhotoViewer.Share.videoText(spot, credit)
            : SpotDetailKitStrings.PhotoViewer.Share.photoText(spot, credit)
    }

    /// The spot's title as a file name: what a path or Finder can't take becomes a dash.
    static func fileName(for title: String) -> String {
        let name = title.components(separatedBy: CharacterSet(charactersIn: "/\\:"))
            .joined(separator: "-")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".")))
        return name.isEmpty ? "OpenSkateMap" : name
    }

    static func downloadClip(from url: URL, named name: String) async throws -> URL {
        let (download, response) = try await URLSession.shared.download(from: url)
        guard let status = (response as? HTTPURLResponse)?.statusCode, (200..<300).contains(status) else {
            try? FileManager.default.removeItem(at: download)
            throw URLError(.badServerResponse)
        }
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "\(name).mp4", directoryHint: .notDirectory)
        try FileManager.default.moveItem(at: download, to: file)
        return file
    }
}
