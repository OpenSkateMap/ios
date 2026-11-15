# AnalyticsKit

**Purpose:** Product analytics through PostHog, keyed by the account id, off when the person turns Share Analytics off. The only module that imports PostHog.
**Tier:** Services
**Project deps:** none (packages: `FactoryKit`, `PostHog`; tests: `CustomDump`)
**Public Factory keys:** `analyticsManager` (`.singleton`; `.preview` on preview and test)
**Entry points:**
- `AnalyticsManager` — `configure()` (once at launch, from `AppDelegate`), `identify(_:)` (the account id: at launch, on sign-in and when the account changes, alongside NotificationsKit's), `capture(_:)`, `reset()` (the account-end handler, on sign-out and deletion), `isEnabled()` / `setEnabled(_:)` (Profile → Share Analytics, on by default).
- Crash and hang reports: `configure()` subscribes `DiagnosticsForwarder` to MetricKit (`MXMetricManager`), which delivers the last session's diagnostics on a later launch. Crashes (`fatal`), hangs, CPU and disk-write exceptions and slow launches (`error`, with the launch's seconds or the megabytes written) go to PostHog as `$exception` events (`ExceptionReport`, PostHog's error-tracking format, `$exception_source` `ios.metrickit`): the attributed thread's frames outermost first with `instruction_addr`/`image_addr` and the binaries' UUIDs as `$debug_images` for symbolication, the build that crashed in `diagnostic_*`, an Objective-C exception's format string (never its composed message, whose arguments can carry data). They're captured like any event, so Share Analytics off (and Debug builds without `-OSMAnalytics YES`) sends none. The iOS 27 SDK adds Swift's `MetricManager` and marks `MX*` "to be deprecated"; move when the deployment target is 27.
- `AnalyticsEvent` — every event the app sends besides screens and app open/close: `spot_opened` with where from (`SpotSource`: map, list, recent, nearby, search, link), `place_opened`, `directions_opened`, `spot_shared` (only when the share sheet completed), `filters_changed` (counts). A new event is a new case first.

**Ownership map:** the choice to share → `UserDefaults` (`analytics.disabled`, per device), applied to the SDK at setup and on change; identity and the event queue → the SDK.

## Rules

- **Who sends what** (cloud `AGENTS.md` → Analytics): the app sends screens (`$screen`, named after the view controller's class, so no titles or names), app open/close and intent the server never sees; outcomes (submissions, votes, reviews, shares of collections, reports) come from the server, with the same account id. Don't capture an outcome here.
- **Opt-out is both sides.** Off stops the SDK (`optOut`), and the app registers `SessionCredentials.doNotTrack`, so every signed-in request says `DNT: 1` and the server sends nothing about the person either.
- PostHog drops `identify` while opted out, so `setEnabled(true)` identifies the last account again.
- **Where people are** comes from PostHog's GeoIP transformation (country, region, city from the connection's IP); the project has "Discard client IP data" on, so the IP itself isn't stored. Events never carry the device's location. The manifest declares it as coarse location.
- Never free text, names or emails in events; ids, enums and counts only.
- The project token (`phc_`) is public by design and lives in `AnalyticsManager` (project OpenSkateMap, 666695); empty, nothing is sent and Debug builds log a fault saying so. Never a personal key (`phx_`) in the app.
- Debug builds send nothing unless launched with `-OSMAnalytics YES`, so simulators and dev phones never mix into the production numbers.
- Push belongs to BuzzKit: `capturePushNotificationSubscriptions` and `capturePushNotificationOpened` stay off, or PostHog would swizzle the token and taps. Feature flags aren't used (`preloadFeatureFlags` off).
- PostHog's agent skills (`integration-swift`, `posthog-best-practices`) are in `.agents/skills`, installed with `posthog-cli api skill install <id>`. This file wins over them.
