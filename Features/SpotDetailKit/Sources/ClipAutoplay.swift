import Foundation
import UIKit

/// Clips play by themselves only while Auto-Play Video Previews is on and Low Power Mode is off.
enum ClipAutoplay {

    // MARK: Static Computed Properties

    static var isAllowed: Bool {
        UIAccessibility.isVideoAutoplayEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled
    }

    // MARK: Static Properties

    static let changeNotifications: [Notification.Name] = [
        UIAccessibility.videoAutoplayStatusDidChangeNotification,
        .NSProcessInfoPowerStateDidChange,
    ]
}
