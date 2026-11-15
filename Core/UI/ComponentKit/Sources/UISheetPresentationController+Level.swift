import ObjectiveC
import SwiftMacros
public import UIKit

/// Sheet levels through UIKit private API (iOS 26.5 and 27). Each setter's type encoding is checked first;
/// on a mismatch sheets stack the public way.
extension UISheetPresentationController {

    // MARK: Static Properties

    private static let setSheetIDName = #Obfuscate("_setSheetID:")
    private static let setHiddenAncestorSheetIDName = #Obfuscate("_setHiddenAncestorSheetID:")

    // MARK: Functions

    public func setSheetLevel(_ level: String) {
        send(Self.setSheetIDName, level)
    }

    public func hidesSheet(at level: String) {
        send(Self.setHiddenAncestorSheetIDName, level)
    }

    private func send(_ name: String, _ value: String) {
        let selector = NSSelectorFromString(name)
        guard let method = class_getInstanceMethod(UISheetPresentationController.self, selector),
              method_getTypeEncoding(method).map({ String(cString: $0) }) == "v24@0:8@16" else {
            return
        }
        _ = perform(selector, with: value as NSString)
    }
}
