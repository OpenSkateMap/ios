# LocationKit

**Purpose:** Where the device is (asked only when someone taps locate) and readable addresses for coordinates.
**Tier:** Services
**Project deps:** none (packages: `FactoryKit`)
**Public Factory keys:** `locationManager`, `geocodingManager` (`.singleton`, `.onPreview`)
**Entry points:**
- `LocationManager` — `currentLocation()`: a When In Use `CLServiceSession` plus `CLLocationUpdate.liveUpdates()`, ending at the first fix; throws `LocationError.denied` / `.unavailable` (no fix within 15 s, counted from the permission prompt's answer, so reading the prompt doesn't use the time up). `isAuthorized()` reads whether location is already allowed without asking; `lastLocation()` is the last fix the system has, maybe from an earlier launch, without waiting (the map opens on it when allowed).
- `GeocodingManager` — MapKit's `MKReverseGeocodingRequest` (iOS 26): `address(_:)`, one line, no country for the device's own region (the spot page); `place(_:)`, the city and country (`PlaceName`) for the map's header. Rate-limited by MapKit: callers debounce and cache.

## Rules

- Never ask for location at launch (HIG); only from the locate button. The purpose string is in the app's Info.plist.
