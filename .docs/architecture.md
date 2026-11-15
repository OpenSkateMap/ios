# Architecture: modules that stay fast to build

Every module is a static framework. When a module changes, Xcode rebuilds it and every module that imports it, then those modules' importers, and so on up to the app. The cost of a change is the module plus everything above it in the graph. These rules keep that set small and the graph honest. `mise run repo:verify-modules` checks the mechanical ones; the tiers themselves are in `modularization.md`.

## Features stay apart

- A feature never imports another feature, so a change in one never rebuilds the others.
- A feature that needs another feature's screen declares a seam: a promised Factory key, such as SpotsMapKit's `addSpotScreen` or SpotDetailKit's `collectionPickerScreen`. The app binds it once in `autoRegister()`.
- Moving to a place (a spot, a collection) goes through AppLinkKit's `AppLink` and `AppLinkOpener`. Never through another feature's view controller type.
- The app target is the only module that knows every concrete module.

## Depend on what changes rarely

- A module that changes often should have few dependents. A module many depend on (Foundation, Models, ComponentKit) should stay small and change rarely. Put something there only when most of its dependents need it.
- When several modules need one narrow piece of a busy module, give the piece a module of its own. PhotoUploadKit came out of ContributionsKit: People, Collections and the collection screens only wanted photo upload, and they rebuilt on every change to the spot outbox.
- A helper doesn't belong in a module just because it was first written there. Move it to the lowest module its users share.
- Services may depend on other services when they need a more basic capability: CollectionsKit → SpotsKit (the spot tables have one writer), services → PhotoUploadKit. The check prints these edges. Cycles are impossible: Tuist refuses them.
- A service never imports AccountKit to learn who is signed in. It reads `SessionCredentials.accountID()` (APIClientKit), which the app binds.
- The generated API client is the most volatile module: every contract change regenerates it. Map its types to domain types inside the service that calls it, and keep `Components.Schemas` out of what features see. Today's exceptions:
  - the managers' `live(credentials:makeClient:)` takes a `Client`;
  - SpotModelKit maps the generated enums.

  Don't add more.

## Imports

- Imports are internal by default (`InternalImportsByDefault`): a plain `import` doesn't reach your dependents.
- `public import` re-exports the dependency's interface to every module that imports yours. Use it only where a public declaration names that module's types; the compiler warns about unused ones.
- Declare every module you import in `Project.swift`. Never rely on reaching one through another module. `MemberImportVisibility` also makes you import the module whose members you use, not only the module that handed you the value.
- Remove a dependency as soon as nothing in `Sources` imports it: an unused edge still rebuilds you when it changes. Test-only modules go in `testDependencies`.

## Linking

- Modules are static frameworks (`moduleProject`), linked into the app at build time.
- FactoryKit is the one dynamic framework, so there is a single `Container.shared`. Don't add more dynamic frameworks: each one is loaded at launch.

## Lifecycles

- Managers are `Sendable` structs of closures with `live`, `preview` and test values. Factory singletons are lazy: nothing is made until it's first used.
- Account state lives in `.scope(.account)` sessions, which reset when the account ends. Account-keyed stores and writers reset in the app's `accountEndHandler`. Nothing account-scoped goes in a plain singleton.
- Initializers do no I/O. Launch work is explicit: `SceneDelegate` starts the syncs on launch and foreground.

## Isolation

- Every module can be built and tested alone. Its fakes are manager values (`.preview`, test fakes such as `FakeContributionsServer`), its databases are in memory (`AppDatabase.inMemory`), and snapshot tests render without a host app.
- A feature's tests depend on services and fakes, never on another feature.

## When not to split

- No interface/implementation module pairs, no service registry, no runtime dependency graph. With about 25 modules and one team, the tiers, seams and Factory give the same isolation with far less machinery.
- Revisit when a one-line change inside a feature takes more than about a minute to build, or when several teams own modules.
- Add a module for a capability with more than one consumer, or when a measured rebuild hurts. Never "for later".

## Before you finish a change

- Every new import is declared, and sits on a lower tier (or is a same-tier service edge you mean to have).
- New public API that names another module's type: does it need `public import`, or would a domain type do?
- Anything you added to ComponentKit, SpotModelKit or APIClientKit rebuilds every feature. Keep it small.
- `mise run repo:verify-modules` and `mise run repo:verify-docs` pass.
