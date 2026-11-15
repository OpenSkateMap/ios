# CollectionsKit

**Purpose:** The account's collections (public or shared with chosen people) and the private spots in them: cached in SQLite, pulled as one snapshot, changed through the server.
**Tier:** Services
**Project deps:** `APIClientKit`, `SQLiteKit`, `SpotModelKit`, `SpotsKit` (the private spots go through its spot writer), `PhotoUploadKit` (a collection's photo) (packages: `FactoryKit`, `IdentifiedCollections` (lists changed by id), OpenAPIRuntime, `SQLiteData`; tests: `CustomDump`, `GRDB` (every committed state, through `ValueObservation`))
**Public Factory keys:** `collectionsSession` (`@MainActor`, `.scope(.account)`), `collectionsSync` (`.singleton`), `collectionsAPIManager` (`.singleton`, `.onPreview`)
**Entry points:**
- `CollectionsSession` — `@MainActor @Observable` facade:
  - Pulls: `syncNow(joining:)` (launch and foreground join a pull already under way), `isSyncing`, `lastOutcome`.
  - Writes: `create(_:)`, `update(_:to:)`, `delete(_:)`, `add(_:to:)`, `remove(_:from:)`, `leave(_:)`.
  - The owner's live sharing: `access(of:)`, `share(_:with:)` (`CollectionInvitee`: `.username`, `.email`; `init(typed:)` reads what someone typed), `removeMember(_:from:)` (answers nothing: the caller reads `access(of:)` again), `cancelInvite(_:to:)`.
  - Online reads: `page(of:)` (a link to a collection the device doesn't have: the collection and the first page of its spots, `CollectionSpotsPage`), `spots(of:after:)` (the next page, by the server's opaque `nextCursor`; nil on the last) and `collections(of:)` (someone's public ones).
  - Every write goes to the server, is applied locally from its answer, then pulls.
- `CollectionsSync` — actor, the one writer of `collection` and `collection_spot`. `pull(joining:)` is serial (SpotsKit's `PassQueue`). It fetches `GET /v1/me/collections`, hands the private spots to `SpotSyncEngine.replacePrivateSpots(with:requestedIn:)`, which drops the ones the account can no longer see, then makes the tables match it in one transaction (nothing written when they already match); spots first, so a collection never shows without its private spots. `apply(_:)` writes one write's answer (a new collection goes on top); `answered(_:joined:requestedIn:)` takes an invitation away and writes the joined collection in the same transaction, so its page always finds one of them; `remove(_:)`; `reset()` for an ended account.
- `CollectionsAPIManager` — the collection endpoints, mapped to `CollectionsAPIError` (`unauthorized`, `notFound`, `forbidden`, `refused(message:)`, `unavailable`, `offline`). Every operation maps failures the same way (`CollectionsAPIError(_ failure: APIFailure)`). A `401` is reported through `SessionCredentials.refused` first.
- `RemoteCollection`, `CollectionsSnapshot`, `CollectionPage`, `CollectionDraft`, `CollectionAccess` — the API's shapes.

**Ownership map:**
- Collections and their spot lists → `CollectionsSync` (one writer), read by features with `@Fetch` / `@FetchAll`.
- Private spot rows (`spot_index.isPrivate`) → `SpotSyncEngine`, fed by `CollectionsSync`.
- Who a collection is shared with → the server only (the owner's Share sheet reads it live).

## Rules

- Pulls run on launch and foreground (the app), after every write here, and after a private spot is published (ContributionsKit's `PublishedSpotHandler`, bound by the app). A failed pull keeps what's cached and is logged at `.notice` (only a refusal's kind, never the server's text).
- Private spots never come from the public spot sync. They come only from the snapshot, which is the whole set: a private row missing from it is deleted.
- The app resets `CollectionsSync` with the other writers when an account ends.
- Tests: `FakeCollectionsServer` answers the snapshot in memory over a real in-memory database; no sleeps.
