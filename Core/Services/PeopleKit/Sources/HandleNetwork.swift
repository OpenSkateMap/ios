public import Foundation

public enum HandleNetwork: String, CaseIterable, Sendable {
    case instagram
    case tiktok
    case youtube
    case x
    case telegram
    case website

    // MARK: Computed Properties

    public var title: String {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .youtube: "YouTube"
        case .x: "X"
        case .telegram: "Telegram"
        case .website: PeopleKitStrings.Network.website
        }
    }

    public var prefix: String {
        self == .website ? "" : "@"
    }

    // MARK: Functions

    public func url(for value: String) -> URL? {
        let handle = value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? value
        switch self {
        case .instagram:
            return URL(string: "https://instagram.com/\(handle)")

        case .tiktok:
            return URL(string: "https://www.tiktok.com/@\(handle)")

        case .youtube:
            return URL(string: "https://www.youtube.com/@\(handle)")

        case .x:
            return URL(string: "https://x.com/\(handle)")

        case .telegram:
            return URL(string: "https://t.me/\(handle)")

        case .website:
            guard let url = URL(string: value), let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else {
                return nil
            }
            return url
        }
    }

    public func normalized(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard self != .website, trimmed.hasPrefix("@") else {
            return trimmed
        }
        return String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
    }
}
