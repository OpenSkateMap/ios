# PhotoUploadKit

**Purpose:** A photo someone picked, made ready to share and uploaded: the one capability spots, avatars and collection photos all need. Also a short clip cut from a picked video, with its sound and its poster, for a spot photo.
**Tier:** Services
**Project deps:** `APIClientKit`, `ImageKit` (ThumbHash) (packages: `FactoryKit`, OpenAPIRuntime; tests: `CustomDump`)
**Public Factory keys:** `photoUploadManager` (`.singleton`, `.onPreview`), `clipPreparer` (`.singleton`, `.onPreview`, `.onTest` → `.test`, which hands the source back without AVFoundation and refuses a window outside `durations` as the live one does)
**Entry points:**
- `PhotoUploadManager` — `prepare` (upright via ImageIO's transform, ≤ 2048 px, re-encoded with no source metadata, ThumbHash from ≤ 100 px) and `upload` (`PUT /v1/photos/{id}`); failures as `PhotoUploadError` (`unauthorized`, `offline`, `unavailable`, `rejected(status:message:)`: refused for good, with the server's message for a status the API documents; callers choose what people read).
- `PhotoUploadManager.uploadClip` — `PUT /v1/clips/{id}` with the file mapped rather than read; the same failures.
- `ClipPreparer` — `prepare(source, start, duration)`: the window cut to the video, then refused outside `durations` (3…16 s) as `ClipPreparationError` (`tooShort`, `tooLong`, `unreadable`, `encoding`); encoded with `AVAssetReader` → `AVAssetWriter` (iOS 26's async provider and receiver) to H.264 High at ~1.8 Mbps, the track's transform baked into the pixels (upright, its size the display size), short side ≤ 720 and long side ≤ 1920 without upscaling, even sides, ≤ 30 fps, Rec. 709 (HDR tone mapped), with the sound as AAC at 64 kbps a channel (the enabled sound track, at most stereo, at its own 44.1 kHz or else 48 kHz; a phone's spatial recording adds a four-channel track that's off; sound neither side can handle is left out), no metadata, no creation date, the index before the media; into a temporary file the caller owns. `poster(source, at)`: that exact frame, upright, through the photo's encode, so the poster is an ordinary `PreparedPhoto`.
- `PreparedClip` — the MP4 file, its display size, duration and bytes.
- `PreparedPhoto` — the JPEG, its size and ThumbHash. `preview(maxPixelSide:)` decodes it off the main thread at the size a view shows (Edit Profile's avatar, Edit Collection's hero), never the full 2048 px.

**Ownership map:** the photo's bytes → the caller until uploaded (ContributionsKit's outbox files, a profile or collection draft); the photo → R2 under the id the caller minted. A clip's file → whoever holds the `PreparedClip` (ContributionsKit's outbox moves it into its own files); the clip → the server under the id the caller minted.

## Rules

- Its own module so the services that only upload photos (PeopleKit, CollectionsKit) don't depend on the spot outbox, which changes far more often.
- Callers map `PhotoUploadError` into their own errors (ContributionsKit's `APICall.swift`, PeopleKit's `ProfileSession`), so an upload fails the same way the rest of their calls do.
- No location, device or time leaves the device: only a quality setting goes into the re-encode, and a clip is re-encoded from its picture and sound alone, and the times `AVAssetWriter` stamps into its headers are zeroed (`MP4BoxTimes`).
- The server's clip checks (`cleanMp4`: one H.264 track, at most one AAC sound and no other track, moov first, not fragmented, ≤ 16 s, ≤ 1920 px, H.264) are what `ClipPreparer` writes; change them together.
- Tests (`PhotoPreparationTests`) prepare real JPEGs in memory; `ClipPreparationTests` encode a video written in the test (sideways, with sound) and read the result back; no network.
