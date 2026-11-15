public import SpotModelKit
public import UIKit

extension SpotCondition {
    public var title: String {
        switch self {
        case .skateable: ComponentKitStrings.SpotCondition.skateable
        case .knobbed: ComponentKitStrings.SpotCondition.knobbed
        case .demolished: ComponentKitStrings.SpotCondition.demolished
        case .busty: ComponentKitStrings.SpotCondition.busty
        }
    }

    public var color: UIColor {
        switch self {
        case .skateable: .systemGreen
        case .knobbed, .busty: .systemOrange
        case .demolished: .systemRed
        }
    }
}
