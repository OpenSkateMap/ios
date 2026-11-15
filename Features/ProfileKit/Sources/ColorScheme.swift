public import UIKit

/// Per device, like the map's camera.
public enum ColorScheme: String, CaseIterable, Sendable {
    case system
    case light
    case dark

    // MARK: Static Properties

    public static var current: ColorScheme {
        get { UserDefaults.standard.string(forKey: key).flatMap(ColorScheme.init) ?? .system }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }

    private static let key = "appearance.colorScheme"

    // MARK: Computed Properties

    var title: String {
        switch self {
        case .system: ProfileKitStrings.Appearance.system
        case .light: ProfileKitStrings.Appearance.light
        case .dark: ProfileKitStrings.Appearance.dark
        }
    }

    var symbolName: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon.fill"
        }
    }

    // MARK: Functions

    /// On the scene, so every window in it follows, the toasts' included; System removes the override.
    public func apply(to scene: UIWindowScene) {
        switch self {
        case .system: scene.traitOverrides.remove(UITraitUserInterfaceStyle.self)
        case .light: scene.traitOverrides.userInterfaceStyle = .light
        case .dark: scene.traitOverrides.userInterfaceStyle = .dark
        }
    }

}
