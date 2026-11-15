import Foundation
public import SpotModelKit

extension SpotObstacle {

    // MARK: Static Functions

    /// A chip's, menu's or filter's label: a common obstacle in the app's language, any other as stored, capitalized.
    public static func title(of obstacle: String) -> String {
        common(for: obstacle)?.title ?? obstacle.capitalized
    }

    /// The word in a list or a sentence: a common obstacle in the app's language, any other exactly as stored.
    public static func name(of obstacle: String) -> String {
        common(for: obstacle)?.name ?? obstacle
    }

    /// A spelling variant ("gap") is translated only where the language has its own word, so English shows it as stored.
    private static func common(for obstacle: String) -> Common? {
        guard let common = Common(stored: obstacle) else {
            return nil
        }
        return common.rawValue == obstacle.lowercased() || common.name != common.rawValue ? common : nil
    }
}

extension SpotObstacle.Common {
    var title: String {
        switch self {
        case .ledges: ComponentKitStrings.Obstacle.Ledges.title
        case .rails: ComponentKitStrings.Obstacle.Rails.title
        case .stairs: ComponentKitStrings.Obstacle.Stairs.title
        case .banks: ComponentKitStrings.Obstacle.Banks.title
        case .gaps: ComponentKitStrings.Obstacle.Gaps.title
        case .manualPads: ComponentKitStrings.Obstacle.ManualPads.title
        case .hubbas: ComponentKitStrings.Obstacle.Hubbas.title
        case .bowl: ComponentKitStrings.Obstacle.Bowl.title
        case .miniRamp: ComponentKitStrings.Obstacle.MiniRamp.title
        case .quarterPipe: ComponentKitStrings.Obstacle.QuarterPipe.title
        case .flatBars: ComponentKitStrings.Obstacle.FlatBars.title
        case .transitions: ComponentKitStrings.Obstacle.Transitions.title
        }
    }

    var name: String {
        switch self {
        case .ledges: ComponentKitStrings.Obstacle.Ledges.name
        case .rails: ComponentKitStrings.Obstacle.Rails.name
        case .stairs: ComponentKitStrings.Obstacle.Stairs.name
        case .banks: ComponentKitStrings.Obstacle.Banks.name
        case .gaps: ComponentKitStrings.Obstacle.Gaps.name
        case .manualPads: ComponentKitStrings.Obstacle.ManualPads.name
        case .hubbas: ComponentKitStrings.Obstacle.Hubbas.name
        case .bowl: ComponentKitStrings.Obstacle.Bowl.name
        case .miniRamp: ComponentKitStrings.Obstacle.MiniRamp.name
        case .quarterPipe: ComponentKitStrings.Obstacle.QuarterPipe.name
        case .flatBars: ComponentKitStrings.Obstacle.FlatBars.name
        case .transitions: ComponentKitStrings.Obstacle.Transitions.name
        }
    }
}
