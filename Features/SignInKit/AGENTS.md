# SignInKit

**Purpose:** The sign-in screen, the whole app while signed out: looping skate footage under one headline ("All over town", Ertem 2026-10-21: an everyday phrase that answers where the spots are, in the voice of skate magazine titles; no slogans or questions), one line on what the app is, and Sign in with Apple.
**Tier:** Feature
**Project deps:** `AccountKit`, `AppLinkKit`, `ComponentKit` (packages: `FactoryKit`, PinLayout; tests: SnapshotTesting)
**Public Factory keys:** none
**Entry points:**
- `SignInViewController` — renders `AuthSession.phase`; its one intent is `signInWithApple()`.

**Ownership map:** loading and the notice line come from `AuthSession.phase`; the screen keeps no auth state. Whether the footage moves is the person's pause/play choice, or until they make one, the system's video autoplay and Reduce Motion settings; `SignInBackdropView` only renders it.

## Rules

- One sign-in method, so no method sheet: the system `ASAuthorizationAppleIDButton` (`.continue`, `.white`, capsule) is the only button. The screen is always dark (`overrideUserInterfaceStyle`), because the footage is its background in either appearance, so the button is always white (HIG: white on dark backgrounds) and the status bar light (`RootViewController` forwards `childForStatusBarStyle`).
- Type: the headline is SF Compressed Bold caps, sized so its longest line fills the width, capped by Dynamic Type, smaller when large text leaves less room, hidden only below 34 pt. The wordmark is SF Expanded; everything else is the system text styles. No other typefaces.
- Bottom up: the legal line sits right under the button; the copy sits 20 pt above the button (Ertem, 2026-10-20: the empty two-line slot left too much space), and a notice (why sign-in failed, or that the session ended) takes its place on the button, pushing the copy up. The headline sits 14 pt (baseline to copy) above the copy, so they read as one block.
- Signing in shows on the button itself: a white capsule with a spinner fades in over the system button and takes its taps. Not a custom Apple button: the HIG allows those only when the interface requires it, and only with Apple's downloaded artwork.
- The legal line is a non-scrolling text view so "Terms of Use" and "Privacy Policy" are real, underlined links (VoiceOver lists them as links). They open `openskatemap.app/terms` and `/privacy` in `SFSafariViewController`; the pages are served by the cloud repo's `apps/web` Worker.
- Footage (HIG accessibility: autoplay, motion, flashing lights): it autoplays only when `UIAccessibility.isVideoAutoplayEnabled` and Reduce Motion is off, and follows changes to either; the glass pause/play button stops and starts it; otherwise the poster frame shows. Grain animates only while the footage plays. No audio track, muted, `preventsDisplaySleepDuringVideoPlayback = false`, paused in the background, resumed on foreground. Clips with flashing lights (sparks, strobes, flashlights) never go in.
- `Resources/SignInLoop.mp4` and its poster `Resources/SignInPoster.jpg` are Romain Batard's *Giddy* footage (#07, #13), used in the app with his permission (Ertem, 2026-10-10): **not covered by the repo's licence, not for reuse, never committed** (gitignored). They live in the private R2 bucket `openskatemap-ios-assets` under the same paths, and `mise run ios:fetch-assets` puts them in `Resources` for maintainers' builds (`.docs/commands.md` → Media). `SignInFootage.bundled` looks both up in the bundle at run time (never through generated accessors, which exist only when the files do) and is nil without them; then the screen is plain black: no video, poster, grain, pause/play button or credit. `mise run ios:render-sign-in-loop` cuts, slows (half speed) and crops them and uploads the result; change footage only through it, and only with footage we may ship in the app.
- The credit "Footage: Romain Batard" sits under the wordmark and opens his YouTube channel; it stays as long as his footage does.
- Separate from onboarding: never show product tours here.

## Tests

`SignInViewControllerTests` snapshots each phase (signed out, signing in with the spinner on the button, a failed sign-in) on an iPhone 13 Pro and an iPhone SE frame and at an accessibility text size, at 1x, without the footage (`footage: nil`), so no image holds a frame of it and CI needs no bucket access. One more puts a flat grey stand-in poster behind the signed-out screen to cover the credit and the pause/play button. Record with `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all xcodebuild … test` on the iOS 27 simulator after an intended design change and look at every new image before committing it.
