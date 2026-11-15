# NotificationsKit

**Purpose:** Push notifications through our self-hosted BuzzKit (`push-api.openskatemap.app`; the server side is `cloud/AGENTS.md` → Push notifications). The only module that imports BuzzKit.
**Tier:** Services
**Project deps:** none (packages: `FactoryKit`, `BuzzKit`; tests: `CustomDump`)
**Public Factory keys:** `notificationsManager` (`.singleton`; `.preview` on preview and test)
**Entry points:**
- `NotificationsManager` — `configure()` (once at launch, from `AppDelegate`), `onOpen(_:)` (where taps go, as `NotificationDestination`: one of the app's links, Contribute or the review queue; a tap that opened the app before the handler was set is delivered when it is), `identify(_:)` (the account id, name, role, join date and the server's `Me.pushIdentity`; the app's `AppDelegate` identifies at launch, on sign-in and whenever the account changes, and not at all while `pushIdentity` is nil), `setCity(_:)` (the city the map last rested in, close enough to name it: SpotsMapKit sends it when it changes; zooming out or leaving keeps it), `signOut()` (the app's account-end handler), `permission()` / `requestPermission()`, `topics()` / `setTopic(_:_:)` (each kind and the person's choice), `cachedTopics()` (the identified subscriber's last loaded choices, so settings open on them: `TopicChoices` in `UserDefaults` under the subscriber id, written only when the answer is for the subscriber who asked, removed by `signOut()`).
- `NotificationTopic` — one kind, titled in the app's own localized words (`Resources/<language>.lproj`); the server's names are English and only show for a kind the app doesn't know yet. `isForCurators` marks the review queue, which settings shows only to editors and admins.

**Ownership map:** who gets what, and each person's choices → BuzzKit (topics `review-results`, `review-queue`, `collection-invites`, `new-spots`); the device's subscriber and token → the SDK.

## Rules

- The server sends; the app never does. The app owns the subscriber's attributes (`name`, `role`, `joinedAt`, `cityId`): the server never identifies, since its identify would replace them.
- Session tracking is off (`automaticSessionTracking: false`): the privacy policy promises no analytics.
- The client key (`bk_pk_`) is public by design; the server's `bk_ws_` key and the identity secret never ship in the app.
- Ask for permission after the welcome screen (Ertem, 2026-10-13), once: `MainTabBarController` asks when the welcome closes, or on the first appearance of a session whose device has seen it, only while the answer is `notAsked`. Profile → Notifications (ProfileKit) shows the state, offers iOS's prompt before it was answered and links to the app's notification settings after a no.
- Every kind the app knows always shows in settings, in the catalog's order; one the server doesn't have yet (the topics need the APNs credential on BuzzKit first) stays off and can't change (`isAvailable` false), as all of them do while the person's choices load (`NotificationTopic.placeholders`). Rows never come and go (Ertem, 2026-10-14: they disappeared after loading).
