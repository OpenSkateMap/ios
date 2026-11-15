public import FactoryKit
public import UIKit

extension Container {
    public var addSpotScreen: Factory<UIViewController?> {
        promised()
    }
}
