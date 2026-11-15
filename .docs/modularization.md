# Modularization

Modules are Tuist projects. Each one is a static framework built by `moduleProject(...)` in `Tuist/ProjectDescriptionHelpers/ModuleProject.swift`, with an optional `<Name>Tests` unit-test target and one scheme.

## Tiers

```
App → Features → Core/UI → Core/Services → Core/Models → Core/Foundation
```

- Dependencies only point down. A module may depend on any tier below it, never on one above. Within Services, a module may use a more basic one (never in a cycle).
- Features never import other features; cross-feature handoffs go through FactoryKit `promised()` seams that the app binds once.
- `mise run repo:verify-modules` enforces these, and that every dependency is declared and used. Why, and how to keep modules fast to build: `architecture.md`.
- Service modules are named for the capability in domain words, not "Data" or "Persistence".
- No module may share a name with an Apple framework.

| Tier | Holds | Isolation |
|---|---|---|
| Core/Foundation | Generated API client, database bootstrap, logging, test support | nonisolated |
| Core/Models | `@Table` rows and value types | nonisolated |
| Core/Services | Sessions and managers (sync, outbox, auth, location, images) | sessions `@MainActor`, managers `Sendable` |
| Core/UI | Colors, icons, shared PinLayout components | default `MainActor` |
| Features | Screens and their models | default `MainActor` |
| App | Composition root, scenes, tab bar | default `MainActor` |

Modules are added when a milestone needs them, not ahead of time.

## Adding a module

1. Create `<Tier>/<Name>Kit/Project.swift` with `moduleProject(name:dependencies:mainActorByDefault:hasTests:testDependencies:)`.
2. Put code in `Sources/` and Swift Testing suites in `Tests/`.
3. Add the path to `Workspace.swift` and to the index in the root `AGENTS.md`.
4. Write `<Name>Kit/AGENTS.md` from the template below and add `CLAUDE.md` as a symlink to it.
5. Run `mise run repo:verify-docs`, `mise run repo:verify-modules` and `tuist generate --no-open`.

## Module AGENTS.md template

```
# <Name>Kit

**Purpose:** …
**Tier:** Foundation | Models | Services | UI | Feature
**Project deps:** …
**Public Factory keys:** …
**Entry points:** - `Type` — role
**Ownership map:** fact → owner

## Rules
```

Keep each module `AGENTS.md` short (under ~15 KB). Put deep mechanics in `<Name>Kit/.docs/<topic>.md`.
