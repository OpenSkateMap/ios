public import CoreGraphics

/// A small fixed set: each size is its own cache entry on the server and in Nuke.
public enum PhotoSize: CaseIterable, Sendable {
    case pin
    case card
    case page
    case fullScreen
    case avatar

    // MARK: Computed Properties

    public var points: CGFloat {
        switch self {
        case .pin: 48
        case .card: 360
        case .page: 440
        case .fullScreen: 1024
        case .avatar: 96
        }
    }
}
