# APIClientKit

**Purpose:** The typed client for the OpenSkateMap API, generated from the backend's OpenAPI document.
**Tier:** Foundation
**Project deps:** none (packages: swift-openapi-runtime, swift-openapi-urlsession, swift-http-types, `FactoryKit`)
**Public Factory keys:** `apiServerURL` (production; a DEBUG launch argument may point it at a local server), `sessionCredentials` (signed out until the app binds it to `AuthSession`, account id included); `Scope.account`
**Entry points:**
- `Client.production(serverURL:middlewares:)` / `Client.production(serverURL:transport:middlewares:)` — the client for `serverURL` (default `URL.openSkateMapAPI`), with the API's millisecond ISO 8601 dates, compact request bodies (the runtime's default sorts keys and pretty-prints; key order is then unspecified, so tests that compare bodies sort them), and `FailureEnvelopeMiddleware` first (outermost), which throws every answer outside 2xx as an `APIFailure`. Registrations pass `Container.apiServerURL()`.
- `SessionCredentials` — the signed-in session as other services see it: `token()`, `refused(token)` (a `401`) `doNotTrack()` (the person turned analytics off; the app binds it to AnalyticsKit) and `accountID()` (the signed-in account's id, `nil` signed out; `@MainActor`). Lets services act on the account's behalf without depending on AccountKit.
- `Scope.account` — everything tied to the signed-in account; reset whenever a session ends. Lives here so every service tier can register into it.
- `SessionCredentials.authorized(_:signedOut:offline:failure:_:)` — how every service calls the API for the account: a client with the session's token (`BearerTokenMiddleware`), a `401` reported for that exact token by a middleware inside the failure one (it still sees the response), `DNT: 1` while `doNotTrack()` (the server then sends no analytics about the person), no session → `signedOut`, and failures through `withAPIFailures(offline:_:_:)`. Call sites read only the generated `.ok.body.json.data`.
- `APIFailure` — an answer outside 2xx: `status`, and `error` (code, message, retryable, details) when the body was the API's envelope. Each service maps it in one `init(_ failure: APIFailure)` on its own error enum; an operation whose status means something of its own (a profile save's `409` is a taken username) passes its own `failure:` closure.
- `withAPIFailures(offline:_:_:)` — an `APIFailure` through the caller's mapping, a transport failure as `offline`; cancellation and contract mismatches (decoding `ClientError`s, bugs) pass through. `AuthAPIManager` uses it directly, since it holds the token itself.
- `BearerTokenMiddleware(token:)` — adds `Authorization: Bearer <token>`; anonymous calls use a client without it.
- `Sources/Generated/*` — generated operations (`Operations.*`) and schemas (`Components.Schemas.*`). Never edit by hand.

**Ownership map:** `openapi.json` is a copy of the backend's committed document (`cloud/apps/api/openapi.json`); the backend owns the contract, this module owns the Swift side of it.

## Rules

- Change the API in the backend first. Then run `mise run ios:pull-api-spec` (copies the document from the sibling `cloud/` checkout and regenerates). CI runs `mise run ios:generate-api -- --check` and fails when `Sources/Generated` is stale.
- The generator is pinned in `.mise/tasks/ios/generate-api`; `Tuist/Package.swift` minor-pins the runtime to match. Bump both together.
- Every response is an envelope: `{ ok: true, data }` or `{ ok: false, error: { code, message, retryable } }`. `ErrorCode` is one generated enum; handle new cases where the app maps errors.
- Tests use a stub `ClientTransport`; no network.
- Registrations read `apiServerURL()` and `sessionCredentials()` inside their factory body, never in a capture list: the app binds them in `autoRegister()`, which has run by the time the factory does.
- The client holds no session. Callers that need one pass its token (see `AccountKit`'s `AuthAPIManager`), so a `401` is always about a known token.
