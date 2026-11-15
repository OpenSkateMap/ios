import ComponentKit
import SpotModelKit
import UIKit

extension UIMenu {
    static func kinds(selected: SpotKind?, onPick: @escaping (SpotKind) -> Void) -> UIMenu {
        UIMenu(children: SpotKind.allCases.map { kind in
            UIAction(title: kind.title, image: UIImage(systemName: kind.symbolName), state: kind == selected ? .on : .off) { _ in
                onPick(kind)
            }
        })
    }

    static func conditions(selected: SpotCondition, onPick: @escaping (SpotCondition) -> Void) -> UIMenu {
        UIMenu(children: SpotCondition.allCases.map { condition in
            UIAction(title: condition.title, state: condition == selected ? .on : .off) { _ in
                onPick(condition)
            }
        })
    }
}
