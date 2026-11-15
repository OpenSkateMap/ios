public import FactoryKit
public import UIKit

extension Container {
    public var discoverCollectionsScreen: Factory<UIViewController?> {
        promised()
    }

    public var discoverCollectionScreen: ParameterFactory<String, UIViewController?> {
        promised()
    }

    /// Discover's + → New Collection: asks for a name, then opens the collection made.
    public var newCollectionScreen: Factory<UIViewController?> {
        promised()
    }
}
