public import Foundation

public enum AppLink: Hashable, Sendable {
    case spot(id: String)
    case collection(id: String)
    case collectionMap(id: String)

    // MARK: Static Properties

    public static let host = "openskatemap.app"

    private static let site = URL(string: "https://\(host)")!

    // MARK: Computed Properties

    public var url: URL {
        switch self {
        case .spot(let id):
            Self.site.appending(components: "spots", id, directoryHint: .notDirectory)
        case .collection(let id):
            Self.site.appending(components: "collections", id, directoryHint: .notDirectory)
        case .collectionMap(let id):
            Self.site.appending(components: "collections", id, "map", directoryHint: .notDirectory)
        }
    }

    // MARK: Lifecycle

    public init?(url: URL) {
        guard url.scheme?.lowercased() == "https", url.host()?.lowercased() == Self.host else {
            return nil
        }
        let path = Array(url.pathComponents.dropFirst())
        guard path.count >= 2, !path[1].isEmpty else {
            return nil
        }
        let id = path[1]
        switch (path[0], Array(path.dropFirst(2))) {
        case ("spots", []): self = .spot(id: id)
        case ("collections", []): self = .collection(id: id)
        case ("collections", ["map"]): self = .collectionMap(id: id)
        default: return nil
        }
    }
}
