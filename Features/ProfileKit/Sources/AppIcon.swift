import UIKit

/// Names must match `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (`mise run ios:app-icons`).
enum AppIcon: CaseIterable {
    case simple
    case clear
    case black
    case swirl
    case conical

    // MARK: Static Properties

    @MainActor
    static var current: AppIcon {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.alternateIconName == name } ?? .simple
    }

    // MARK: Computed Properties

    var alternateIconName: String? {
        switch self {
        case .simple: nil
        case .clear: "AppIcon-Clear"
        case .black: "AppIcon-Black"
        case .swirl: "AppIcon-Swirl"
        case .conical: "AppIcon-Conical"
        }
    }

    var title: String {
        switch self {
        case .simple: ProfileKitStrings.Appearance.AppIcon.simple
        case .clear: ProfileKitStrings.Appearance.AppIcon.clear
        case .black: ProfileKitStrings.Appearance.AppIcon.black
        case .swirl: ProfileKitStrings.Appearance.AppIcon.swirl
        case .conical: ProfileKitStrings.Appearance.AppIcon.conical
        }
    }

    var detail: String {
        switch self {
        case .simple: ProfileKitStrings.Appearance.AppIcon.Simple.detail
        case .clear: ProfileKitStrings.Appearance.AppIcon.Clear.detail
        case .black: ProfileKitStrings.Appearance.AppIcon.Black.detail
        case .swirl: ProfileKitStrings.Appearance.AppIcon.Swirl.detail
        case .conical: ProfileKitStrings.Appearance.AppIcon.Conical.detail
        }
    }

    var preview: UIImage {
        switch self {
        case .simple: ProfileKitAsset.appIconSimple.image
        case .clear: ProfileKitAsset.appIconClear.image
        case .black: ProfileKitAsset.appIconBlack.image
        case .swirl: ProfileKitAsset.appIconSwirl.image
        case .conical: ProfileKitAsset.appIconConical.image
        }
    }
}
