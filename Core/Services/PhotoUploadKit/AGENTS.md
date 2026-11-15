# PhotoUploadKit

**Purpose:** A photo someone picked, made ready to share and uploaded: the one capability spots, avatars and collection photos all need.
**Tier:** Services
**Project deps:** `APIClientKit`, `ImageKit` (ThumbHash) (packages: `FactoryKit`, OpenAPIRuntime; tests: `CustomDump`)
**Public Factory keys:** `photoUploadManager` (`.singleton`, `.onPreview`)
**Entry points:**
- `PhotoUploadManager` — `prepare` (upright via ImageIO's transform, ≤ 2048 px, re-encoded with no source metadata, ThumbHash from ≤ 100 px) and `upload` (`PUT /v1/photos/{id}`); failures as `PhotoUploadError` (`unauthorized`, `offline`, `unavailable`, `rejected(_:)` with the server's reason, `refused(status:)` for a refusal without the server's words, such as a status the API doesn't document).
- `PreparedPhoto` — the JPEG, its size and ThumbHash. `preview(maxPixelSide:)` decodes it off the main thread at the size a view shows (Edit Profile's avatar, Edit Collection's hero), never the full 2048 px.

**Ownership map:** the photo's bytes → the caller until uploaded (ContributionsKit's outbox files, a profile or collection draft); the photo → R2 under the id the caller minted.

## Rules

- Its own module so the services that only upload photos (PeopleKit, CollectionsKit) don't depend on the spot outbox, which changes far more often.
- Callers map `PhotoUploadError` into their own errors (ContributionsKit's `APICall.swift`, PeopleKit's `ProfileSession`), so an upload fails the same way the rest of their calls do.
- No location, device or time leaves the device: only a quality setting goes into the re-encode.
- Tests (`PhotoPreparationTests`) prepare real JPEGs in memory; no network.
