# OnboardingKit

**Purpose:** "Welcome to OpenSkateMap": one screen on what the app has inside, shown once per device after the first sign-in (not re-openable since Ertem dropped the Profile row). Laid out as a What's New screen (Ertem, 2026-10-12): "OpenSkateMap <version>" (no glyph: Ertem rejected the skater tile, and the app has no real icon yet), a large title and subtitle, then cards with a square screenshot of the app each (Ertem, 2026-10-20: stills instead of the filmed clips), the privacy line and Share with Friends; a fixed glass ✕ closes it. Our own module; unrelated to the third-party OnBoardingKit package.
**Tier:** Feature
**Project deps:** `AppLinkKit` (the site Share with Friends sends), `ComponentKit` (packages: `FactoryKit`, PinLayout)
**Public Factory keys:** `onboardingStore` (`.singleton`; in-memory on test and preview)
**Entry points:**
- `OnboardingViewController` — the screen; the ✕ (or the VoiceOver escape gesture) dismisses it. At accessibility sizes the title grows only as far as its longest word fits the width, so "OpenSkateMap" doesn't break mid-word, and the version line shrinks to fit its one line.
- `OnboardingViewController.presentWelcomeIfNeeded(over:store:onClose:)` — full-screen, once per device; closing marks it seen, then runs `onClose` (the app asks for notification permission there).
- `WelcomeCardView` — one card: a square screenshot (24 pt continuous corners, a hairline edge), a bold title and a description.
- `OnboardingStore` — the seen flag (`onboarding.welcome.seen.v3` in the standard defaults; v3 is the What's New screen). `.live(defaults:)`, `.inMemory(seen:)`.
- `Resources/Assets.xcassets/Welcome{Map,Page,NewSpot}` — the screenshots: square 1206 px crops of the app on an iPhone 17 Pro, a light and a dark variant each (the card follows the appearance). Map: Barcelona's photo pins and clusters; Page: MACBA's sheet at half height (photo, name, Directions, Share, More); New Spot: three Fòrum photos and the name "Forum Ledges".

**Ownership map:** seen flag → `OnboardingStore`.

## Rules

- It asks nothing and blocks nothing: no permissions, no profile questions (HIG).
- The header and cards rise in with a short stagger; with Reduce Motion they only fade.
- No Rate in App Store link until the App Store page exists.
- Bump the seen key's version only when the screen changes enough to show again.

## Taking the screenshots

Ertem's bar: every spot in a shot has a real-looking photo (no glyph tiles, no test uploads), and nothing personal on screen.

- **Photos.** `Screenshots/photos/` holds photorealistic photos generated with Codex's built-in image generation (no third-party photos: we have no rights to them): `seed-<spot>.jpg` covers for every Barcelona spot of the local seed (`photos.tsv` lists each with its size and ThumbHash) and `library-forum-*.jpg` for New Spot's Photo Library. To use them: `bun run seed:local` in `cloud/apps/api`, then `Screenshots/seed-photos.sh` (gives the spots their covers in the local Postgres container), `python3 Screenshots/serve-photos.py` (answers the app's variant URLs from `photos/` on :8788), and `xcrun simctl addmedia <udid> Screenshots/photos/library-forum-*.jpg`. Take down any local test spot in Barcelona first (`status = 'removed'`), so only seeded spots show. A new seed spot needs its photo too: generate it with the same brief (an unretouched phone photo, eye level, no text, logos or faces) and add a `photos.tsv` row.
- **The simulator.** iPhone 17 Pro, status bar overridden to 9:41 and full battery (`xcrun simctl status_bar`), the simulated location away from the shot (no blue dot), the app installed fresh and launched with `-OSMAPIBaseURL http://localhost:<api port> -OSMImagesBaseURL http://localhost:8788 -OSMDebugToken <seed token>`. Each screen is taken twice, with `xcrun simctl ui <udid> appearance light`, then `dark`.
- **Cropping.** Take full-resolution screenshots (1206 × 2622) and crop a 1206 px square with `ffmpeg -i <shot>.png -vf crop=1206:1206:0:<top> <name>.png`: the map from about 200 px, the spot sheet from 1268 px, New Spot from 388 px. Save them as JPEG (`sips -s format jpeg -s formatOptions 85`) into the image sets, `<name>.jpg` for light and `<name>-dark.jpg` for dark, and look at both before committing.
