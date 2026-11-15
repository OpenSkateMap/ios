public import SpotModelKit
public import UIKit

extension SpotKind {
    public var title: String {
        switch self {
        case .street: ComponentKitStrings.SpotKind.street
        case .park: ComponentKitStrings.SpotKind.park
        case .diy: ComponentKitStrings.SpotKind.diy
        case .plaza: ComponentKitStrings.SpotKind.plaza
        }
    }

    public var symbolName: String {
        switch self {
        case .street: "road.lanes"
        case .park: "figure.skateboarding"
        case .diy: "hammer.fill"
        case .plaza: "building.columns.fill"
        }
    }

    public var tint: UIColor {
        switch self {
        case .street: .systemBlue
        case .park: .systemGreen
        case .diy: .systemOrange
        case .plaza: .systemPurple
        }
    }
}
