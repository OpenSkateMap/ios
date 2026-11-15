public import FactoryKit
public import SpotModelKit
public import UIKit

extension Container {
    public var userProfileScreen: ParameterFactory<String, UIViewController?> {
        promised()
    }

    public var spotReportScreen: ParameterFactory<String, UIViewController?> {
        promised()
    }

    public var collectionPickerScreen: ParameterFactory<String, UIViewController?> {
        promised()
    }

    public var addVideoScreen: ParameterFactory<AddVideoTarget, UIViewController?> {
        promised()
    }

    public var suggestEditScreen: ParameterFactory<SpotEditTarget, UIViewController?> {
        promised()
    }
}

// MARK: - AddVideoTarget

public struct AddVideoTarget: Sendable {
    public let spotID: String
    public let spotTitle: String
}
