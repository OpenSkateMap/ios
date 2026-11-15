# TipJarKit

**Purpose:** Tips for the app: three one-off consumable purchases that unlock nothing (App Review 3.1.1 allows tipping the developer), sold through RevenueCat. The only module that imports RevenueCat.
**Tier:** Services
**Project deps:** none (packages: `FactoryKit`, `RevenueCat`)
**Public Factory keys:** `tipJarManager` (`.singleton`; `.preview` on preview and test)
**Entry points:**
- `TipJarManager` — `configure()` (once at launch, from `AppDelegate`; again does nothing), `tips()` (RevenueCat's `tips` offering, cheapest first, as `Tip`: package id, the store's localized title and price) and `buy(_:)` (`TipOutcome`: `paid`, `cancelled`, or `pending` while Ask to Buy waits for a parent). `.live` is RevenueCat with the build's public key (`tips()` and `buy(_:)` throw `notConfigured` before `configure()`, rather than trapping); `.preview` has three tips that buy at once.

**Ownership map:** purchases and their records → RevenueCat (project `proj91cdfcd4` "OpenSkateMap": a Test Store app and the App Store app `com.ertembiyik.openskatemap`, products `com.ertembiyik.openskatemap.tip.small|medium|large`, packages `tip_small|tip_medium|tip_large` in the current offering `tips`). No account is attached: tips are anonymous.

## Rules

- Debug builds (the `.dev` app) use the Test Store key, so nothing is charged; Release builds use the App Store key. Both are public SDK keys; never put a secret (`sk_`) key in the app.
- The app calls `configure()` at launch (`AppDelegate`), so RevenueCat finishes a purchase a past launch left unfinished.
- Call it "Support" or "Tip", never "Donate": App Review 3.2.2(iv) keeps fundraising for approved nonprofits.
- Dashboard work goes through the `rc` CLI (`rc auth login`) and RevenueCat's skills (`integrate-revenuecat`, `create-revenuecat-project`, `revenuecat-store-state`).
