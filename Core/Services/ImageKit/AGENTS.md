# ImageKit

**Purpose:** Photos and their placeholders: ThumbHash decoding, the URLs of sized variants, and the one configured Nuke pipeline.
**Tier:** Services
**Project deps:** none (packages: `FactoryKit`, `Nuke`)
**Public Factory keys:** `imagePipeline`, `imageCaches`, `photoURLBuilder`, `thumbHashRenderer` (all `.singleton`)
**Entry points:**
- `ThumbHash` — decoder (checked against the reference implementation's output) and average colour.
- `ThumbHashRenderer` — actor: base64 ThumbHash → `UIImage`, decoded once and kept in an `NSCache` (500, fewer under memory pressure); `averageColor(base64:)` for tints.
- `PhotoURLBuilder` + `PhotoSize` — the variant URL for a photo key at a fixed size bucket: `https://images.openskatemap.app/cdn-cgi/image/width=…,fit=…,format=auto/<key>` (`URL.openSkateMapImages`, the R2 bucket's domain with Image Transformations). A `nil` base URL turns photo loading off, and every photo then renders as its ThumbHash. `clipURL(for:)` is a photo's clip straight from the bucket (`https://images.openskatemap.app/<key>`, progressive MP4), never through transformations.
- `ImageLoader` (`imageLoader`, `.onPreview { .placeholder }`) — images through the one pipeline (disk cache, memory caches), so features don't import Nuke. `image(_:_:)` resizes an image from outside our domain (YouTube thumbnails on spot videos); callers pass one fixed size per use (it's part of the cache key). `photo(_:_:)` loads one of our variants as the CDN sized it, the same request as `PhotoLoader` (collection covers in lists), so it shares the map's cache entries and isn't re-encoded.
- `ImagePipelines.make(caches:)` — one pipeline: decode queue width 3, the memory and disk caches of `ImageCaches` (`ImagePipelines.useCase`: pin, which every `.pin`-size request of ours is tagged with, so map thumbnails don't evict covers; photo for the rest; 400 MB on disk).
- `ImageCaches` — those caches, so they can be emptied: `removeAll()` runs when an account ends (the app's account-end handler), since a private spot's or collection's photos belong to the account that loaded them. Nuke's own `cache.removeAll()` would miss the per-use-case memory caches.

**Ownership map:** decoded placeholders → `ThumbHashRenderer`; downloaded images → the pipeline's caches.

## Rules

- One pipeline, wider queues; never a second pipeline built from the same `Configuration`.
- Request only `PhotoSize` buckets: sizes are part of every cache key.
- The ThumbHash shows until the variant arrives, and stays if it can't load: local `cf dev` photos live in a local R2, not on the image domain.
