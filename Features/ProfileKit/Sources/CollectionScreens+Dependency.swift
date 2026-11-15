public import FactoryKit
public import UIKit

extension Container {
    public var collectionsListScreen: Factory<UIViewController?> {
        promised()
    }

    public var userCollectionsScreen: ParameterFactory<String, UIViewController?> {
        promised()
    }
}
