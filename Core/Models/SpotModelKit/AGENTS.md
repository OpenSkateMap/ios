# SpotModelKit

**Purpose:** The local tables (sqlite-data `@Table` rows) and their migrations: the light spot index the map draws, the heavy details, photos, cities and the sync cursor; the submission outbox and history; and the people cache (profiles, blocked users).
**Tier:** Models
**Project deps:** `SQLiteKit`, `APIClientKit` (the wire mappings) (packages: `SQLiteData`)
**Public Factory keys:** none
**Entry points:**
- `DatabaseSchema.spots` — the migration that creates every table below.
- `SpotIndex` (`spot_index`) — one light row per spot, its `obstacles` as JSON text; indexes on `(latitude, longitude)` and `cityID`. `SpotIndex.inViewport(_:matching:)` is the map's bounded query (newest first, at most `viewportLimit`, antimeridian-aware via `CoordinateBox`); `SpotIndex.nearest(toLatitude:longitude:in:limit:)` is search's Around Here (nearest first, ordered and limited in SQL); `SpotIndex.inCity(_:matching:)` is Discover's list (`CitySpot`: the spot and its `SpotScore`, best rated first, then by name), and `SpotIndex.inArea(_:matching:)` the same for a box outside our cities; `SpotIndex.within(_:)` is the box condition they share.
- `SpotFilter` — kinds and conditions (any listed), obstacles (all, ignoring case). `Where<SpotIndex>.matching(_:)` is the SQL every spot query goes through; `matches(_:)` is the same rule in memory, for pins already on the map (a test keeps the two agreeing).
- `SpotObstacle` — the common obstacle chips (`Common`: their raw values, lowercase English, are what's stored, synced and matched; ComponentKit names them in the app's language; `Common(stored:)` is the one a stored obstacle names, ignoring case and a plural "s"); `choices(including:)` is every obstacle picker's list (Filters, Discover's menu, the obstacles sheet): the common ones, in a spot's own spelling where it differs only by a plural "s", then the rest.
- `SpotScore` (`spot_score`) — the server's composite score per spot (0…1; ×100 is the index people see), with its votes. Its own table, so a new score never re-runs the map's query.
- `SpotDetail` (`spot_detail`) and `SpotPhoto` (`spot_photo`) — the heavy part, deleted with their index row (`ON DELETE CASCADE`). The detail carries the spot's votes: `upvotes`, `downvotes` and the account's own `myVote` (`SpotVote`: `.up`, `.down`, `.none`; stored as the API's 1, -1, 0). A photo may carry a `SpotClip` (`clip`, JSON): a short clip that plays in its place, the photo being its poster; older details without it fetch again once. `createdAt` is the day it was added to the spot, stored to the second (an unchanged photo compares equal when fetched again); nil only until details stored before it fetch again (migration "Add dates to spot photos").
- `City` (`city`) — names and boxes for the map header.
- `SyncState` (`sync_state`) — exactly one row: cursor, re-index epoch and cursor, resync flag.
- `SpotKind`, `SpotCondition`, `SpotVote` — mirror the API's values. `SpotModel+API.swift` maps them (and `SubmissionStatus`, `VideoProvider`, `SpotClip`) to and from the generated `Components.Schemas` types, once for every service.
- `NearbySpot`, `PhotoCredit` — values the contribution and review services share (New Spot's duplicate warning and a curator's card; who took a photo).
- `DatabaseSchema.contributions` — the outbox and history, a separate schema: unlike the spot tables they hold data only this device has.
- `SubmissionDraft` (`submission_draft`), `DraftPhoto` (`draft_photo`), `OutboxStatus`, `OutboxProblem` (a failed entry's `problem`, also `VideoDraft`'s: a kind, never text; contributions migration "Outbox problems are kinds, not text" cleared the free text before it) — new spots and suggested edits not yet sent (an edit has `editsSpotID` and `changedFields`, `SpotEditField`); a partial index on pending rows. A draft photo may carry its clip (`clip`, JSON `DraftClip`: the server's clip id, the outbox file, size, duration, bytes and whether it's uploaded; contributions migration "Draft photos carry their clips"); `fileNames` and `isFullyUploaded` cover both.
- `MySubmission` (`my_submission`), `SubmissionStatus` — sent submissions as the server last reported them; `isEdit` when `changedFields` isn't empty; `removalReason` and `removedAt` when an admin took its spot down (`SpotRemovalReason`, the server's presets).
- `SpotEditTarget` — a published spot as Suggest an Edit starts from (SpotDetailKit hands it to ContributeKit through the app).
- `DatabaseSchema.review`: `ReviewQueueCache` (`review_queue_cache`) — the curator's queue as last loaded, one JSON row written by ReviewKit.
- `DatabaseSchema.people` — the people cache: `PeopleProfile` (`people_profile`: profiles as the server last reported them, handles and editor cities as JSON), `PeopleBlockedUser` (`people_blocked_user`) and `PeopleSyncState` (`people_sync_state`: whether the blocked list has loaded once). Every row names the account it was fetched for.

- Collections (`DatabaseSchema.spots`, migration "Add collections and private spots"): `SpotCollection` (`collection`: name, `CollectionVisibility`, the account's `CollectionRole`, owner, member count, cover, the server's order) and `SpotCollectionEntry` (`collection_spot`: its spots, most recently added first). `SpotIndex.isPrivate` marks a private spot, which came with the collections, not the public sync. `SubmissionDraft.collectionID` and `MySubmission.collectionID` (contributions migration "Add private spot destinations") send a new spot into a private collection.

**Ownership map:** spot rows are written by `SpotSyncEngine` (SpotsKit) only; outbox and history rows by `ContributionsOutbox` (ContributionsKit) only; people rows by `PeopleStore` (PeopleKit) only; collection rows and private spots by `CollectionsSync` (CollectionsKit) through `SpotSyncEngine`. Features read with `@FetchAll` / `@FetchOne` / `@Fetch`.

## Rules

- Light and heavy stay in separate tables: sqlite-data re-runs a query when a table it reads changes, so writing a detail must never touch `spot_index`.
- Observe bounded windows (a viewport, one city), never the whole index.
- Changing a table means a new migration in `DatabaseSchema.spots`, never editing a shipped one.
