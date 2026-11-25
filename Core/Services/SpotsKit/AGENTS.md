# SpotsKit

**Purpose:** Keeps the local spot index in sync with the server and fills in details for the spots people look at.
**Tier:** Services
**Project deps:** `APIClientKit`, `SQLiteKit`, `SpotModelKit` (packages: `FactoryKit`, OpenAPIRuntime, `SQLiteData`)
**Public Factory keys:** `spotsSession` (`@MainActor`, `.scope(.account)`), `syncEngine` (`.singleton`), `spotsAPIManager` (`.singleton`, `.onPreview`)
**Entry points:**
- `SpotsSession` — `@MainActor @Observable` facade: `syncNow(joining:)` (launch and foreground join a pass already under way; a link to a spot not yet indexed and Try Again ask for the next one), `isSyncing`, `show(_:)` (visible ids), `select(_:)` (the open spot: `selectedID`, and `selectedDetails` — `DetailsLoad` `.loading` while its fetch runs, `.failed` when it couldn't be fetched; `retrySelectedDetails()` asks again without the 20 s rest), `refreshDetails()` (stored details are stale, e.g. after a block: expire them all, fetch the open and visible ones now), `vote(_:on:)` (below), `takeDown(_:reason:)` (an admin's takedown with a `SpotRemovalReason`, `PUT /v1/spots/{spotId}/removal`: the server marks the spot removed, then `SpotSyncEngine.applyRemoval(of:)` drops its index row at once, as its tombstone would on the next pass; a refusal throws and keeps it), `restore(_:)` (its Undo, `DELETE /v1/spots/{spotId}/removal`, then a sync pass brings the spot back under its new version).
- **Votes:** `SpotsSession.vote(_ vote: SpotVote, on spotID: String) async throws`. The spot's stored `SpotDetail` shows the vote at once (`applyVote` moves `upvotes`, `downvotes` and `myVote` the way the server counts), then takes the server's totals (`applyVoteTotals`). A failure goes back to what the server last confirmed and throws `SpotsAPIError`. Newest wins per spot (`RequestFlight`): an answer is written only while no newer vote waits, and a replaced vote neither writes nor throws. Votes never touch the index or the version; a detail answer requested before a spot's latest vote keeps the stored vote (`DetailStamp`).
- `SpotSyncEngine` — actor and the only writer of spot tables. Passes are serial (`PassQueue`, shared with CollectionsKit: a caller during a pass gets the next one, which sees what changed before it asked, unless it joins); cities and scores load alongside the pages and are written after the last one; each page is one transaction (upserts that only move forward, tombstones, then the cursor last, compare-and-swapped). Every index row it writes carries its search row (`SpotSearchText.replace(for:_:)`); `reset()` clears search first, so the index's delete trigger has nothing to look through. A detail fetched again rewrites its photos and videos only when they differ (credits change with renames and blocks, without a new version). `resetRequired` re-indexes under a new epoch without wiping. `reset()` cancels and clears for an ended account. Named apart from sqlite-data's CloudKit `SyncEngine`.
- `DetailFetcher` — actor: demand (selected first, then visible), debounced, batched `ids=` ≤ 100, ≤ 3 batches in flight, one request per id, 5 min freshness, 20 s rest for failures and `missing`. `select(_:retrying:)` says whether the selected spot's details failed (retrying skips its rest).
- `SpotsAPIManager` — `GET /v1/sync/spots`, `/v1/spots?ids=`, `/v1/cities`, `/v1/spot-scores`, `PUT /v1/spots/{spotId}/vote` (answers `SpotVoteTotals`), `PUT` and `DELETE /v1/spots/{spotId}/removal` (admins), mapped to `SpotsAPIError`; a `401` is reported through `SessionCredentials.refused` first.
- `SpotSelection` — `@Observable` "which spot is open", shared by the map and the spot sheet.

- **Private spots:** `SpotSyncEngine.replacePrivateSpots(with:requestedIn:)` is how CollectionsKit hands over the private spots in its snapshot: it writes them with `isPrivate` and deletes private rows the snapshot left out (access ended). Public passes and re-indexes never touch private rows. `SpotIndex.init(_:)` (here) is the one mapping of the API's index row, for the sync and for collections; the writer sets the epoch and `isPrivate`.

**Ownership map:**
- Spot rows, details, photos, cities, scores, the cursor → `SpotSyncEngine` (one writer). Cities and scores come whole after each pass (scores move with votes, which never move a spot's version); only changed score rows are written, and the cities only when they differ from the stored ones (a rewrite would wake every city observer after each foreground sync).
- Whether a sync runs, the last outcome, votes waiting for the server → `SpotsSession`.
- In-flight and resting detail ids → `DetailFetcher`.
- The open spot → `SpotSelection`, owned by the map screen.

## Rules

- Never write spot tables outside `SpotSyncEngine`; detail answers go through `applyDetails(_:requestedAt:)` with the `detailStamp()` taken as the request went out, which drops answers from before a `reset()` (`generation`) and keeps votes cast since.
- The cursor is written last in the same transaction as its page. A page whose starting cursor moved is dropped, and the pass pulls again.
- DEBUG pages by 2, so paging runs on every developer launch.
- Tests use `FakeSpotServer` (the real sync contract in memory), `FakeDetailServer` and `FakeVoteServer` (answered by hand, in the order a test picks), with `ImmediateClock` and a hand-moved `TestTime`; no sleeps.
