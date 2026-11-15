# PeopleKit

**Purpose:** People in the app: your public profile and its edits, other people's profiles, who you blocked, and reports to the admins (App Store guideline 1.2).
**Tier:** Services
**Project deps:** `APIClientKit`, `PhotoUploadKit` (the avatar), `SQLiteKit`, `SpotModelKit` (the people cache tables) (packages: `FactoryKit`, OpenAPIRuntime, `SQLiteData`)
**Public Factory keys:** `profileSession` (`@MainActor`, `.scope(.account)`), `peopleStore` (`.singleton`), `peopleAPIManager` (`.singleton`, `.onPreview`), `blocksChangedHandler` (bound by the app; `.none` by default)
**Entry points:**
- `ProfileSession` — `@MainActor @Observable` facade that keeps no copies: `accountID` (APIClientKit's `SessionCredentials.accountID`); `load(_:)` (refreshes a cached profile; joins an in-flight load of the same person), `prepareAvatar(_:)`, `save(_:over:)`, `loadBlockedUsers()`, `setBlocked(_:_:)`, `report(_:)`. Each writes what the server answered through `PeopleStore`.
- `PeopleStore` — actor, the one writer of the people cache (`people_profile`, `people_blocked_user`, `people_sync_state` in SpotModelKit): rows keyed by the account they were fetched for; `generation` and `reset()` (the account ended: clears every row and drops answers still in flight).
- `ProfileRequest(personID:account:)` and `BlockedUsersRequest(account:)` (→ `BlockedUsers`: the list and whether it has loaded once) — `FetchKeyRequest`s screens observe with `@Fetch`, so they open on the cached copy and change in place when a refresh lands.
- `PeopleAPIManager` — `profile`, `updateMyProfile`, `blockedUsers`, `setBlocked`, `report`; failures as `PeopleAPIError` (`notFound` also when the person blocked you; `usernameUnavailable` for a profile save's `409`: the username is taken or not allowed; a `409` anywhere else is `rejected` with the server's words).
- `PublicProfile` (+ `Avatar`, `Stats`, `City`, `Role`), `Handles`, `HandleNetwork` (title, "@" prefix, the page a value opens, normalising), `ProfileDraft`, `ProfileUpdate`, `Report` (+ `Target`, `Reason`), `BlockedUser`, `BlocksChangedHandler`.

**Ownership map:**
- Profiles and the blocked list → SQLite, written only by `PeopleStore`, keyed by account; the app clears them when the account ends (`accountEndHandler` → `peopleStore().reset()`).
- What emptying a field means on the wire → `ProfileUpdate.clear`.
- Whose names show on spots → the server; after a block the app expires stored spot details (`BlocksChangedHandler` → `SpotsSession.refreshDetails()`).

## Rules

- `ProfileUpdate(from:to:)` sends only what changed, compared the way the server stores it (trimmed; usernames in the case typed; handles without a leading "@"). Emptying a field goes in `clear`, never as `null`: the generated client can't send an explicit null.
- A new avatar is uploaded (`PUT /v1/photos/{id}`, the same preparation as spot photos) before the `PATCH`. Saving again after a refusal reuses the uploaded photo.
- Cache-first: screens read the cache; `load`, `save`, `loadBlockedUsers` and `setBlocked` refresh it. A failed refresh keeps the cached copy (usable data beats an error screen).
- A `404` for a profile forgets the cached copy: the person may have blocked you, and the app says only "not available".
- Every write carries the store's `generation` from before its request; one from before a `reset()` is dropped, so an old account's answer never lands after sign-out.
- Tests use `FakePeopleServer` (the contract in memory, with the call order including uploads, and scripted failures), an in-memory database (`AppDatabase.inMemory(schemas: [.people])`) read back through the requests, and a stub transport for the wire format; no sleeps.
