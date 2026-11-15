import Foundation
import SpotModelKit

// MARK: - VideoLinkStatus

public enum VideoLinkStatus: Equatable, Sendable {
    case available(title: String, author: String?)
    case unavailable
    case unknown
}

// MARK: - VideoLinkChecker

/// YouTube's keyless oEmbed answers 200 for a public or unlisted video, 401 for a private one, 400 or 404 if gone.
public struct VideoLinkChecker: Sendable {

    // MARK: Static Properties

    public static let live = VideoLinkChecker { link in
        guard link.provider == .youtube else {
            return .unknown
        }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.youtube.com"
        components.path = "/oembed"
        components.queryItems = [
            URLQueryItem(name: "url", value: link.url.absoluteString),
            URLQueryItem(name: "format", value: "json"),
        ]
        guard let url = components.url else {
            return .unknown
        }
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url, timeoutInterval: 8))
            switch (response as? HTTPURLResponse)?.statusCode {
            case 200:
                let video = try JSONDecoder().decode(OEmbed.self, from: data)
                return .available(title: video.title, author: video.authorName)

            case 400, 401, 403, 404:
                return .unavailable

            default:
                return .unknown
            }
        } catch {
            return .unknown
        }
    }

    public static let preview = VideoLinkChecker { _ in .unknown }

    // MARK: Properties

    public var check: @Sendable (VideoLink) async -> VideoLinkStatus

    // MARK: Lifecycle

    public init(check: @escaping @Sendable (VideoLink) async -> VideoLinkStatus) {
        self.check = check
    }
}

// MARK: - OEmbed

private struct OEmbed: Decodable {
    enum CodingKeys: String, CodingKey {
        case title
        case authorName = "author_name"
    }

    let title: String
    let authorName: String?

}
