# Contributing to OpenSkateMap

Thanks for wanting to help. This app is small and opinionated, so a few minutes here saves both of us time.

Security issues don't go in issues or pull requests: see [SECURITY.md](SECURITY.md).

## Ask first

Some changes are welcome straight away, as a pull request:

- bug and crash fixes,
- tests,
- docs, including the `AGENTS.md` files,
- translations from native speakers,
- accessibility fixes (VoiceOver, Dynamic Type, contrast),
- performance work that comes with a measurement.

**Open an issue first** for anything else:

- a new feature;
- anything that changes how the app looks or behaves, such as layout, copy, icons, navigation, animation or
  settings;
- a new dependency;
- a change to the API.

The screens and their wording are deliberate. A pull request that changes them without an agreed issue gets closed,
however good the code is.

## Spots aren't here

Spot data lives on the server, not in this repository. To add or correct a spot, use the app: New Spot or Suggest
an Edit sends it to that city's curators. To flag one, use Report on its page. Please don't post spot locations in
issues: some spots are kept quiet on purpose.

## Setting up

[RUNNING.md](RUNNING.md) runs the app against a local backend with sample spots.
Every command is in [.docs/commands.md](.docs/commands.md).

## How it's built

### Local-first

Screens read a local SQLite database only (Point-Free's [sqlite-data](https://github.com/pointfreeco/sqlite-data) on
GRDB) and never wait on the network. A sync engine fills it: the spot index arrives in pages behind a version
cursor, removals as tombstones, details when a spot is opened. New spots and edits go into an outbox and are sent
under fixed ids, so a retry never creates a duplicate. Every tab opens from the cache after the app is killed, with
no connection at all.

### UIKit, laid out by hand

UIKit throughout, SwiftUI only in small leaf views. Layout is [PinLayout](https://github.com/layoutBox/PinLayout) in
`layoutSubviews`, with no Auto Layout (a lint rule enforces it). State lives in `@Observable` models that views read
in iOS 26's `updateProperties()`, so UIKit tracks what each view depends on. No Combine.

### Small modules with one direction

[Tuist](https://tuist.dev) modules in tiers, each depending only on the tiers below it: Foundation → Models →
Services → UI → Features → the app. Features never import each other; the app wires them together through
[FactoryKit](https://github.com/hmlongco/Factory) seams. See [.docs/modularization.md](.docs/modularization.md).

### One contract with the backend

The API client is generated from the backend's OpenAPI document with
[swift-openapi-generator](https://github.com/apple/swift-openapi-generator), and CI fails when it's stale. A
change to the API starts in the [backend](https://github.com/OpenSkateMap/cloud); `mise run
ios:pull-api-spec` brings it here.

### Docs for people and agents

Every module has an `AGENTS.md`: what it owns, its entry points and its rules. [AGENTS.md](AGENTS.md) indexes them
all, and `mise run repo:verify-docs` keeps the index complete. They're written to be read by people and by coding
agents alike.

## Making a change

- **One pull request does one thing.** Small ones get reviewed fastest.
- **Read the `AGENTS.md` of the module you touch.** The rules live there: what the module owns, where state lives,
  what it may import. If your change makes it wrong, update it in the same pull request; `mise run repo:verify-docs`
  checks the index.
- **Formatting and lint:** `mise run ios:format`, then `mise run ios:lint`. The build has no warnings, and it stays
  that way. `mise install` sets up Git hooks that format and lint on every commit and run every check before a push.
- **Tests:** change behaviour, add a test for it; fix a bug, add the test that would have caught it. Tests use Swift
  Testing, with no sleeps (a lint rule enforces it). Snapshot tests change only when you meant to change the design:
  re-record them as [.docs/commands.md](.docs/commands.md) describes, and look at every image you commit.
- **Strings:** a new string goes in the module's `Localizable.strings` in all 15 languages
  (`mise run ios:check-translations`). If you can't translate one, put the English in and say so in the pull request.
- **Commits:** a short summary that starts with the area (`Discover: …`, `Collections: …`), then a body that says
  why.
- **The API** is generated from the backend's OpenAPI document. Never edit `Core/Foundation/APIClientKit/Sources/Generated`:
  change the [backend](https://github.com/OpenSkateMap/cloud) first, then run `mise run ios:pull-api-spec`.

## Coding agents

The repository is set up for them: `AGENTS.md` everywhere. Using one is fine, as long as you've read, run and
understood everything you send. Say in the pull request which parts an agent wrote. Large unreviewed changes get
closed.

## Licensing

Your contribution is licensed under this repository's licence, [GPL-3.0-or-later](LICENSE), including its permission
to ship through the App Store ([APP-STORE-EXCEPTION.md](APP-STORE-EXCEPTION.md)). Send only changes you wrote or have
the right to submit under that licence. Images, icons and other assets keep their own terms ([NOTICE.md](NOTICE.md)).

## Conduct

Everyone here follows the [Code of Conduct](CODE_OF_CONDUCT.md).
