public import SpotModelKit

extension VideoProvider {
    public var title: String {
        switch self {
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        }
    }

    public var symbolName: String {
        switch self {
        case .youtube: "play.rectangle"
        case .instagram: "camera"
        }
    }
}
