public import Foundation
public import SpotModelKit

/// Reads links the way the backend's `parseVideoLink()` does (`VideoLinkTests` mirrors its tests); keep them in step.
public struct VideoLink: Equatable, Sendable {

    // MARK: Static Properties

    private static let youtubeHosts: Set = ["youtube.com", "www.youtube.com", "m.youtube.com", "music.youtube.com"]
    private static let instagramHosts: Set = ["instagram.com", "www.instagram.com"]

    // MARK: Properties

    public let provider: VideoProvider
    public let externalID: String
    public let url: URL
    public let thumbnailURL: URL?

    // MARK: Lifecycle

    public init?(string: String) {
        guard let components = URLComponents(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = components.host?.lowercased() else {
            return nil
        }
        let path = components.path.split(separator: "/").map(String.init)
        let query = { (name: String) in components.queryItems?.first { $0.name == name }?.value }

        if host == "youtu.be" || Self.youtubeHosts.contains(host) {
            let id: String? =
                if host == "youtu.be" {
                    path.first
                } else if path.first == "watch" {
                    query("v")
                } else if let first = path.first, ["shorts", "live", "embed"].contains(first), path.count > 1 {
                    path[1]
                } else {
                    nil
                }
            guard let id, Self.isYouTubeID(id),
                  let url = URL(string: "https://www.youtube.com/watch?v=\(id)") else {
                return nil
            }
            self.init(
                provider: .youtube,
                externalID: id,
                url: url,
                thumbnailURL: URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg"),
            )
            return
        }
        if Self.instagramHosts.contains(host) {
            guard let at = path.firstIndex(where: { ["reel", "reels", "p", "tv"].contains($0) }), at <= 1, at + 1 < path.count,
                  Self.isInstagramCode(path[at + 1]) else {
                return nil
            }
            let code = path[at + 1]
            let segment = path[at] == "p" ? "p" : "reel"
            guard let url = URL(string: "https://www.instagram.com/\(segment)/\(code)/") else {
                return nil
            }
            self.init(provider: .instagram, externalID: code, url: url, thumbnailURL: nil)
            return
        }
        return nil
    }

    private init(provider: VideoProvider, externalID: String, url: URL, thumbnailURL: URL?) {
        self.provider = provider
        self.externalID = externalID
        self.url = url
        self.thumbnailURL = thumbnailURL
    }

    // MARK: Static Functions

    /// ASCII only, as the server checks it: Swift's `\w` would also take letters from other scripts.
    private static func isYouTubeID(_ value: String) -> Bool {
        value.wholeMatch(of: /[A-Za-z0-9_-]{11}/) != nil
    }

    private static func isInstagramCode(_ value: String) -> Bool {
        value.wholeMatch(of: /[A-Za-z0-9_-]{5,40}/) != nil
    }
}
