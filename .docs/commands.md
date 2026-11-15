# Commands

Tool versions are pinned in `.mise.toml`; run commands through `mise`.

## Setup

```sh
mise install                  # tuist, swiftformat, swiftlint, pre-commit
pre-commit install            # format, lint, generated-client and docs checks on commit
tuist install                 # resolve Swift packages
mise run ios:fetch-assets     # maintainers: the sign-in footage (see Media); skipped without access
tuist generate --no-open      # OpenSkateMap.xcworkspace
```

## Build and test

```sh
set -o pipefail
xcodebuild -workspace OpenSkateMap.xcworkspace -scheme OpenSkateMap \
  -destination 'platform=iOS Simulator,name=iPhone 17' test 2>&1 | xcsift -f toon -w
```

Build, install and launch:

```sh
mise run ios:run -- <launch arguments>     # on the booted simulator; SIMULATOR=<udid> when several are booted
mise run ios:install-device                # on the one reachable iPhone, cable or Wi-Fi (DEVICE=<udid> to choose), see below
```

`ios:install-device` needs no Apple Account in Xcode: it builds unsigned, downloads the personal team's
"OpenSkateMap Dev CLI" profile with `asc` (keychain profile "Ertem Personal") and signs with the certificate it
names. CI picks its simulator with `mise run -q ios:simulator-id`: an iPhone on the selected Xcode's iOS runtime.

Media: the sign-in footage (Romain Batard's, `Features/SignInKit/AGENTS.md`) isn't in this repo. `mise run
ios:fetch-assets` downloads it from the private R2 bucket `openskatemap-ios-assets` into `Features/SignInKit/Resources`
(gitignored) with wrangler's login (`bunx wrangler login`) or `CLOUDFLARE_API_TOKEN`; `ios:run`, `ios:install-device`,
`ios:speedflight` and `ios:release` run it first, and the last two fail without it. Without access it skips, and the
sign-in screen is plain dark. `mise run ios:render-sign-in-loop` renders the footage and uploads it to the bucket.

Snapshot tests compare against PNGs in each module's `Tests/__Snapshots__`, recorded with Xcode 27.0 on its iOS 27.0 simulator. CI selects the same Xcode (`DEVELOPER_DIR` in `.github/workflows/ios.yml`), since a newer runtime renders them differently enough to fail; moving to a newer Xcode re-records them and changes `DEVELOPER_DIR` together. Every scheme's tests run in English (UK) (`testActionOptions` in `Tuist/ProjectDescriptionHelpers/Settings.swift`), so dates and text draw the same whatever the simulator's language and region. On CI, a failing snapshot's image is the run's `failed-snapshots` artifact. After an intended design change, re-record with `TEST_RUNNER_SNAPSHOT_TESTING_RECORD=all` in front of the same command (xcodebuild hands `TEST_RUNNER_`-prefixed variables to the tests without the prefix) and review every changed image before committing it.

## Checks

`mise run ios:format` runs SwiftFormat, then `ios:format-pinlayout`, which orders every PinLayout chain the way its README's style guide does (the order never changes the layout); `-- --lint` only reports. `mise run ios:format-pinlayout -- --self-test` checks the ordering itself.

| Command | What it checks |
|---|---|
| `mise run ios:format` | SwiftFormat (`-- --lint` to check only) |
| `mise run ios:lint` | The custom SwiftLint rules; proves every rule still fires on `Lint/fixtures` |
| `mise run ios:generate-api -- --check` | The generated API client matches `APIClientKit/openapi.json` |
| `mise run ios:check-translations` | Every language in `appLanguages` has every English string, with the same format specifiers and plural variables |
| `mise run repo:verify-docs` | Doc module names, `CLAUDE.md` symlinks, and the root `AGENTS.md` index |
| `mise run repo:verify-modules` | The module graph: dependencies point down a tier, features never depend on features, every dependency is declared and used (same-tier service edges are listed) |

## Acknowledgements

The Settings app shows every Swift package's licence (Settings → Apps → OpenSkateMap → Acknowledgements) from `OpenSkateMap/Resources/Settings.bundle`, which is generated and committed. After adding, removing or updating a package (`tuist install` first):

```sh
mise run ios:licenses    # needs swift-package-list: brew install swift-package-list
```

## API client

The backend repo owns the contract. After an API change there, with the backend checked out next to this repo:

```sh
mise run ios:pull-api-spec    # copies ../cloud/apps/api/openapi.json and regenerates the client
```

## Running without an Apple Account (DEBUG)

Sign in with Apple needs an Apple Account on the device and the App ID's capability. For QA and screenshots, DEBUG builds read these launch arguments (`OpenSkateMap/Sources/LaunchArgument.swift`):

| Argument | Effect |
|---|---|
| `-OSMPreviewAuth` | Apple and the account API answer from preview fakes and the session lives in memory: starts signed out, the Apple button signs in as "Preview Skater" with no network |
| `-OSMPreviewSignedIn` | The same, but starts signed in |
| `-OSMResetOnboarding` | Forgets the welcome screen was seen, so it shows again |
| `-OSMAPIBaseURL <url>` | Every API call goes to `<url>` instead of production |
| `-OSMImagesBaseURL <url>` | Photo variants load from `<url>` instead of the photos domain (the welcome screenshots' local photo server) |
| `-OSMDebugToken <token>` | Starts signed in with that server session token, stored in the Keychain like a real sign-in; the foreground refresh loads the real account, and relaunches (offline too) keep it |
| `-OSMAnalytics YES` | Sends analytics to the production PostHog project; Debug builds send nothing without it |

```sh
mise run ios:run -- -OSMPreviewSignedIn -OSMResetOnboarding
```

## A build for a phone that isn't here (Speedflight)

```sh
mise run ios:speedflight -- "<title>" "<what changed, what to test>" [screenshot.png …]
```

Cuts a signed ad hoc **Release** build (`com.ertembiyik.openskatemap`, the production API), uploads it to [speedflight.dev](https://speedflight.dev) and prints `Build page: <url>` last: that page installs it from Safari on any iPhone registered to the personal team (MD55Y22MQS), with every earlier build listed. It needs a committed, pushed HEAD and `.env.speedflight` (gitignored): `ASC_KEY_ID`/`ASC_ISSUER_ID`/`ASC_PRIVATE_KEY_PATH` (the personal team's key), `SPEEDFLIGHT_SECRET` (the upload key), `SPEEDFLIGHT_DEEP_LINK=openskatemap://` (the URL scheme the page opens the app with) and `SPEEDFLIGHT_AUTHOR`. The page link is the only key to install: share it privately; the secret never leaves the Mac and the `release` environment's secrets.

Without the Mac: Actions → **speedflight** → Run workflow (or `gh workflow run speedflight --ref <branch>`), with the same names as secrets of the `release` environment (Releases, below) and the `SPEEDFLIGHT_DEEP_LINK` variable; the link lands in the run's summary. Workflow dispatch needs the workflow on `main`. The runner signs with the fixed CI identity (`mise run ios:ci-keychain`, below). The global `speedflight` agent skill covers the rest, including adding a teammate's device.

## App icons

```sh
mise run ios:app-icons
```

The Wheel family (Ertem's picks, 2026-10-16): `Design/AppIcons/<key>.png` are the chosen images (generated with Codex), and the task cuts each into an Icon Composer file, `OpenSkateMap/Resources/<name>.icon`. The layers are a background (the wheel painted out), the urethane (the fitted ellipse) and the hub (by its colour). All three carry the source's own pixels, so the default render is the source. iOS builds dark, clear and tinted from the layers: the background image is hidden in tinted (and Black's in dark too, where a dark fill replaces its paper). The task also renders the App Icon picker's previews with Icon Composer's `ictool` at the row's size (60 pt at @2x and @3x, light and dark, PNG: a 1024 px render drawn at 60 pt is sampled without mipmaps and speckles the edges) and fails when a default render drifts below 40 dB from its source. Simple is the primary; the alternates are listed in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (`xcconfigs/Common.xcconfig`) and ProfileKit's `AppIcon`, so change all three together. To check any appearance: `ictool <name>.icon --export-image --output-file out.png --platform iOS --rendition TintedDark --width 1024 --height 1024 --scale 1` (renditions: Default, Dark, ClearLight, ClearDark, TintedLight, TintedDark).

## Releases: a tag is a version

```sh
git tag v1.0.0 && git push origin v1.0.0   # Actions → release archives that commit and uploads it
mise run ios:release                       # the same from the Mac, with the tag checked out
```

A tag `vX.Y.Z` is the version people see (`MARKETING_VERSION`); the build number is the upload's UTC time (`YYYYMMDD.HHMM`), so every upload is newer than the last, and a version always names one commit. `ios:release` archives Release, exports for the App Store and uploads straight to App Store Connect (`destination: upload`), where the build shows in TestFlight once Apple has processed it; submitting for review stays a step in App Store Connect. On the Mac it needs a clean tree, the tag pushed and `.env.speedflight`'s App Store Connect key. Other builds keep `1.0 (1)` from `xcconfigs/Common.xcconfig`.

**Secrets in CI.** The release and speedflight jobs run in the `release` environment, which holds `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY`, `CI_SIGNING_P12`, `CI_SIGNING_P12_PASSWORD`, `SPEEDFLIGHT_SECRET` and `CLOUDFLARE_API_TOKEN` (read access to the footage bucket's objects); the repository itself holds none.

**Signing in CI.** Archives sign with Apple Development and exports re-sign with Apple's cloud-managed distribution certificate through the App Store Connect key, so no distribution `.p12` exists. A runner has no development identity, so `ios:ci-keychain` imports the fixed one (certificate `46527CWCSP`, "Apple Development: Created via API", until 2027-10-15) from the `CI_SIGNING_P12` and `CI_SIGNING_P12_PASSWORD` secrets into a temporary keychain. Before it expires, make a new one the same way (`asc certificates create --certificate-type DEVELOPMENT --generate-csr …`, then a `.p12` with `/usr/bin/openssl`, whose format `security import` reads) and replace both secrets.

## Running against a local API with sample spots (DEBUG)

With the backend checked out next to this repo (`../cloud`, see its `AGENTS.md`):

```sh
cd ../cloud
bun run db:up                                         # local PostGIS (OrbStack)
DATABASE_URL=postgres://openskatemap:openskatemap@localhost:54330/openskatemap bun run db:migrate
bun run --filter @openskatemap/api seed:local         # London + Barcelona spots; prints an admin session token
bun run dev                                           # cf dev; note the port it prints
```

Then launch the app at that server, signed in with the printed token:

```sh
mise run ios:run -- -OSMAPIBaseURL http://localhost:<port> -OSMDebugToken <token>
```
