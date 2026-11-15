import ObjectiveC
import SwiftMacros
public import UIKit

/// iPad's tab bar at the top while an iPhone lies on its side, through UIKit private API (iOS 26 and 27): the adaptive
/// visual style shows its floating bar once its configuration's `supportsFloatingTabBar` is on and the width is
/// regular. Each accessor's shape is checked first; on a mismatch the bar stays at the bottom.
extension UITabBarController {

    // MARK: Static Properties

    private static let styleName = #Obfuscate("_visualStyle")
    private static let configurationName = #Obfuscate("configuration")
    private static let floatingKey = #Obfuscate("supportsFloatingTabBar")
    private static let setFloatingName = #Obfuscate("setSupportsFloatingTabBar:")
    private static let updateAvailabilityName = #Obfuscate("_updateBarAvailabilityAnimated:")
    private static let positionName = #Obfuscate("_effectiveTabBarPosition")

    // MARK: Computed Properties

    /// Whether `updateTabBarPlacement()` put the bar at the top.
    public var isTabBarAtTop: Bool {
        traitOverrides.contains(UITraitHorizontalSizeClass.self)
    }

    // MARK: Functions

    /// Puts the bar where it belongs for the current size classes and window; call it again whenever they change.
    public func updateTabBarPlacement() {
        // Only an iPhone on its side whose bar UIKit keeps at the bottom: a foldable's displays move it to a side.
        let wantsTopBar = traitCollection.userInterfaceIdiom == .phone
            && traitCollection.verticalSizeClass == .compact
            && [.left, .right].contains(view.window?.deviceTopEdge)
            && placesBarAtBottom
        guard setSupportsFloatingTabBar(wantsTopBar) else {
            return
        }
        if wantsTopBar {
            traitOverrides.horizontalSizeClass = .regular
        } else if traitOverrides.contains(UITraitHorizontalSizeClass.self) {
            traitOverrides.remove(UITraitHorizontalSizeClass.self)
        }
    }

    /// Call alongside a size transition. A bottom bar coming back from the top mid-rotation leaves its landscape height
    /// in the children's safe area (65 pt instead of 83); showing it again has the controller measure it anew.
    public func tabBarPlacementDidSettle() {
        guard !isTabBarAtTop, !isTabBarHidden else {
            return
        }
        setTabBarHidden(true, animated: false)
        setTabBarHidden(false, animated: false)
    }

    /// UIKit's own placement of the bar: 1 and below are the bottom, 3 and 4 the sides.
    private var placesBarAtBottom: Bool {
        guard let method = class_getInstanceMethod(UITabBarController.self, NSSelectorFromString(Self.positionName)),
              method_getTypeEncoding(method).map({ String(cString: $0) }) == "q16@0:8",
              let position = value(forKey: Self.positionName) as? Int else {
            return true
        }
        return position <= 1
    }

    private func setSupportsFloatingTabBar(_ isOn: Bool) -> Bool {
        guard let ivar = class_getInstanceVariable(UITabBarController.self, Self.styleName),
              ivar_getTypeEncoding(ivar).map({ String(cString: $0) })?.hasPrefix("@") == true,
              let style = object_getIvar(self, ivar) as? NSObject,
              style.responds(to: NSSelectorFromString(Self.configurationName)),
              let configuration = style.value(forKey: Self.configurationName) as? NSObject,
              let setter = class_getInstanceMethod(type(of: configuration), NSSelectorFromString(Self.setFloatingName)),
              method_getTypeEncoding(setter).map({ String(cString: $0) }) == "v20@0:8B16" else {
            return false
        }
        guard configuration.value(forKey: Self.floatingKey) as? Bool != isOn else {
            return true
        }
        configuration.setValue(isOn, forKey: Self.floatingKey)
        // The style rereads the flag only when the width class changes, and a Pro Max is regular width either way.
        // Off waits for that change: refreshed mid-rotation, the bottom bar keeps its landscape height.
        let update = NSSelectorFromString(Self.updateAvailabilityName)
        if isOn, let method = class_getInstanceMethod(type(of: style), update),
           method_getTypeEncoding(method).map({ String(cString: $0) }) == "v20@0:8B16" {
            typealias UpdateAvailability = @convention(c) (AnyObject, Selector, Bool) -> Void
            unsafeBitCast(method_getImplementation(method), to: UpdateAvailability.self)(style, update, false)
        }
        return true
    }
}
