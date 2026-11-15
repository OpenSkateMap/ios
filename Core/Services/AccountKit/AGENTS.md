# AccountKit

**Purpose:** Whether this device is signed in, and every way that changes: Sign in with Apple, restoring and checking the stored session, signing out, deleting the account.
**Tier:** Services
**Project deps:** `APIClientKit` (packages: `FactoryKit`, OpenAPIRuntime)
**Public Factory keys:** `authSession` (`.cached`, `@MainActor`), `appleSignInManager`, `authAPIManager`, `keychainManager` (all `.singleton`, with `.onPreview` / `.onTest` fakes), `accountEndHandler` (bound by the app)
**Entry points:**
- `AuthSession` — `@MainActor @Observable` facade. `phase: .signedOut(notice:) | .signingIn | .signedIn(Account)`; `signInWithApple()`, `refreshAccount()`, `signOut()`, `deleteAccount()`; `sessionToken` and `sessionRefused(token:)` back the app's `SessionCredentials` binding.
- `AccountEndHandler` — work outside this module that runs whenever a session ends, before `Scope.account` resets (the app stops the spot sync and clears local spots).
- `AppleSignInManager` — `ASAuthorizationController` behind one `async` call; makes the nonce per attempt. `credentialState` asks Apple whether a stored Apple user id still signs in here (the completion-handler form: the async one throws away `.notFound`), `revocations` streams `credentialRevokedNotification`. `.live`, `.preview`; `init(signIn:)` never revokes.
- `AuthAPIManager` — `POST /v1/auth/apple`, `GET /v1/me`, `POST /v1/auth/logout`, `DELETE /v1/me`, each mapped to `AuthAPIError`. `.live(makeClient:)`, `.preview`.
- `KeychainManager` — generic-password items, after-first-unlock, this device only. `.live(service:)`, `.inMemory(_:)`, `.preview(signedInAs:)`.
- `Nonce` — random nonce and its SHA-256 hex (Apple gets the hash, the API the raw value).
- `Account`, `SignedInAccount`, `SignedOutNotice`, `AppleCredential`.

**Ownership map:**
- Session token + account + the Apple user id it signed in with → one Keychain item (`auth.session`), owned by `AuthSession`. Nothing else stores them.
- Signed-in or not, and why the last session ended → `AuthSession.phase`.
- Account-scoped objects → `Scope.account` (APIClientKit), reset by `AuthSession` whenever a session ends, right after `accountEndHandler` runs.

## Rules

- Features talk to `AuthSession`, never to the managers.
- The stored session is restored synchronously in `init` so the first frame is right; the server check is `refreshAccount()`, which the app calls on foreground. Offline or a 5xx keeps the stored account; `401` ends the session (`.sessionExpired`), `403` too (`.accountDisabled`).
- **A revoked Apple ID signs out** (Ertem, 2026-10-20): `refreshAccount()` (launch and every foreground) first asks Apple about the session's Apple user id, and so does Apple's `credentialRevokedNotification`. `.revoked` or `.notFound` (the person stopped using Sign in with Apple for the app, or deleted their Apple Account, which sends no notification) ends the session as a `401` does (`.sessionExpired`, no new copy), then signs out on the server best-effort. `.authorized`, `.transferred` or a failed check keep it: the check never signs anyone out by failing. Sessions stored before the id was kept skip the check until the next sign-in. The server hears the same from Apple's server-to-server notices and ends the account's sessions there.
- Every API call that needs a session takes the token explicitly, and a late answer only ends the session if that token is still current. Keep both when adding calls.
- Closing Apple's sheet is not a failure: back to `.signedOut(notice: nil)`. Every other failure leaves a `SignedOutNotice` for the sign-in screen.
- Sign-out is local first, then best-effort on the server. Deletion is server first; the session ends only once the server confirms.
- Never log a `ClientError` description: it includes request headers. Log the `AuthAPIError` case or the error's type, as `AuthSession` does.
- Tests build a real `AuthSession` with stub managers (`AuthSessionTests`); the live `AuthAPIManager` is tested against canned responses in the API's real wire format (`AuthAPIManagerTests`).
