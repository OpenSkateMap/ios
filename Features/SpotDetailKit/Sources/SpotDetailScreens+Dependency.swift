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

    public var suggestEditScreen: ParameterFactory<SuggestEditRequest, UIViewController?> {
        promised()
    }
}

// MARK: - AddVideoTarget

public struct AddVideoTarget: Sendable {
    public let spotID: String
    public let spotTitle: String
}

// MARK: - SuggestEditRequest

public struct SuggestEditRequest: Sendable {
    public let spot: SpotEditTarget
    /// Photos from the person's library to add as the edit opens, by PhotoKit local identifier.
    public let libraryPhotoIDs: [String]
}
