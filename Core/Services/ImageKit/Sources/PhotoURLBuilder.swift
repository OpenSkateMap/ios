public import CoreGraphics
public import Foundation

// MARK: - PhotoURLBuilder

public struct PhotoURLBuilder: Sendable {
    public var baseURL: URL?

    public init(baseURL: URL?) {
        self.baseURL = baseURL
    }

    public func url(for key: String, size: PhotoSize, scale: CGFloat) -> URL? {
        guard let baseURL else {
            return nil
        }
        let width = Int((size.points * scale).rounded(.up))
        let fit = size == .fullScreen ? "scale-down" : "cover"
        return baseURL.appending(path: "cdn-cgi/image/width=\(width),fit=\(fit),format=auto/\(key)")
    }

    /// Clips are served as they were stored (progressive MP4), never through image transformations.
    public func clipURL(for key: String) -> URL? {
        baseURL?.appending(path: key)
    }
}

extension URL {
    public static let openSkateMapImages = URL(string: "https://images.openskatemap.app")!
}
