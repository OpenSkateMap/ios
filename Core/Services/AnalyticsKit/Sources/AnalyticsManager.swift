import Foundation
import MetricKit
import os
import PostHog
import Synchronization

// MARK: - AnalyticsManager

public struct AnalyticsManager: Sendable {
    public var configure: @Sendable () -> Void
    public var identify: @Sendable (_ accountID: String) -> Void
    public var capture: @Sendable (_ event: AnalyticsEvent) -> Void
    public var reset: @Sendable () -> Void
    public var isEnabled: @Sendable () -> Bool
    public var setEnabled: @Sendable (_ isEnabled: Bool) -> Void

    public init(configure: @escaping @Sendable () -> Void,
                identify: @escaping @Sendable (_ accountID: String) -> Void,
                capture: @escaping @Sendable (_ event: AnalyticsEvent) -> Void,
                reset: @escaping @Sendable () -> Void,
                isEnabled: @escaping @Sendable () -> Bool,
                setEnabled: @escaping @Sendable (_ isEnabled: Bool) -> Void) {
        self.configure = configure
        self.identify = identify
        self.capture = capture
        self.reset = reset
        self.isEnabled = isEnabled
        self.setEnabled = setEnabled
    }
}

extension AnalyticsManager {
    /// Public by design: a PostHog project token can only send events.
    private static let projectToken = "phc_ksR9GhRebVK7mepaLCi6iw68bZpmaPD4zTiWkHe26Ppr"
    /// Share Analytics. Kept here, not only in the SDK, so it holds before setup.
    private static let disabledKey = "analytics.disabled"

    private static let logger = Logger(subsystem: "com.ertembiyik.openskatemap", category: "analytics")

    public static let live: AnalyticsManager = {
        // Identify is dropped while opted out, so turning Share Analytics back on identifies again.
        let identifiedAccount = Mutex<String?>(nil)
        // Captured like any event, so Share Analytics off drops these too.
        let diagnostics = DiagnosticsForwarder { report, timestamp in
            PostHogSDK.shared.capture("$exception", properties: report.properties, timestamp: timestamp)
        }
        return AnalyticsManager {
            guard !projectToken.isEmpty else {
                #if DEBUG
                logger.fault(
                    "projectToken required by PostHog is missing or un-configured, this causes events to be silently missed. This error stops appearing once projectToken is configured"
                )
                #endif
                return
            }
            #if DEBUG
            // Simulators and dev phones stay out of the production project unless launched with `-OSMAnalytics YES`.
            guard UserDefaults.standard.bool(forKey: "OSMAnalytics") else {
                return
            }
            #endif
            let config = PostHogConfig(projectToken: projectToken, host: "https://us.i.posthog.com")
            // A state the SDK stored wins over this, but only our setEnabled writes one, so they agree.
            config.optOut = UserDefaults.standard.bool(forKey: disabledKey)
            config.preloadFeatureFlags = false
            // Push belongs to BuzzKit (NotificationsKit); PostHog would swizzle the token and taps.
            config.capturePushNotificationSubscriptions = false
            config.capturePushNotificationOpened = false
            // UIKit's own screens (the share sheet's host, alerts) aren't ours.
            config.setBeforeSend { event in
                let screen = event.properties["$screen_name"] as? String ?? ""
                return event.event == "$screen" && (screen.hasPrefix("_") || screen.hasPrefix("UI")) ? nil : event
            }
            PostHogSDK.shared.setup(config)
            MXMetricManager.shared.add(diagnostics)
        } identify: { accountID in
            identifiedAccount.withLock { $0 = accountID }
            PostHogSDK.shared.identify(accountID)
        } capture: { event in
            PostHogSDK.shared.capture(event.name, properties: event.properties)
        } reset: {
            identifiedAccount.withLock { $0 = nil }
            PostHogSDK.shared.reset()
        } isEnabled: {
            !UserDefaults.standard.bool(forKey: disabledKey)
        } setEnabled: { isEnabled in
            UserDefaults.standard.set(!isEnabled, forKey: disabledKey)
            if isEnabled {
                PostHogSDK.shared.optIn()
                if let accountID = identifiedAccount.withLock({ $0 }) {
                    PostHogSDK.shared.identify(accountID)
                }
            } else {
                PostHogSDK.shared.optOut()
            }
        }
    }()

    public static var preview: AnalyticsManager {
        let isEnabled = Mutex(true)
        return AnalyticsManager { } identify: { _ in
        } capture: { _ in
        } reset: { } isEnabled: {
            isEnabled.withLock { $0 }
        } setEnabled: { value in
            isEnabled.withLock { $0 = value }
        }
    }
}
