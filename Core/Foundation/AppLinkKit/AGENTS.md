# AppLinkKit

**Purpose:** The app's addresses on the web, `https://openskatemap.app/spots/<id>`: building them to share and reading them back when a universal link opens the app.
**Tier:** Foundation
**Project deps:** none (packages: `FactoryKit`; tests: `CustomDump`)
**Public Factory keys:** `appLinkOpener` (`AppLinkOpener`: how a feature opens a link inside the app, as a tapped universal link would; the app binds it to `AppLinks`)
**Entry points:**
- `AppLink` — `.spot(id:)`; `url` builds the address, `init?(url:)` reads one (`nil` for anything that isn't the app's).

- `AppLink.collection(id:)` — `openskatemap.app/collections/<id>`: the app presents that collection (`CollectionScreens.collection(id:)`), from its cache or fetched.

**Ownership map:**
- Which paths open the app → the site's `apple-app-site-association` (cloud `apps/web/site/pages.ts`) and the app's `applinks:openskatemap.app` entitlement; this type parses the same paths.
- The link waiting to be shown → `AppLinks` in the app target, not here.

## Rules

- A new link is a case here, its path in the site's association file and `_redirects`, and its handling in the app's `MainTabBarController.open(_:)`. Keep the three in step.
- Links carry ids, never content: the site's page for a link names nothing (spots are for signed-in skaters), and the share sheet's preview comes from the sender's device.
