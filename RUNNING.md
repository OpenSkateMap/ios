# Running OpenSkateMap locally

You need a Mac with Xcode 27, [mise](https://mise.jdx.dev), [bun](https://bun.sh) and Docker (or
[OrbStack](https://orbstack.dev)). No Apple Developer account is needed for the simulator.

The app talks to the API, so run the backend next to it, with sample spots in London and Barcelona:

```sh
mkdir openskatemap && cd openskatemap
git clone https://github.com/OpenSkateMap/cloud.git cloud
git clone https://github.com/OpenSkateMap/ios.git ios

cd cloud
bun install
bun run db:up                     # Postgres + PostGIS on port 54330
DATABASE_URL=postgres://openskatemap:openskatemap@localhost:54330/openskatemap bun run db:migrate
cp apps/api/.dev.vars.example apps/api/.dev.vars
#   set BETTER_AUTH_SECRET in apps/api/.dev.vars to any 32+ characters: openssl rand -base64 32
bun run --filter @openskatemap/api seed:local    # prints a session token for a sample admin
bun run dev                       # the API, at the URL it prints (usually http://localhost:5173)
```

Then, in another terminal, build the app and launch it on a simulator, signed in with that token:

```sh
cd ios
mise install                      # Tuist, SwiftFormat, SwiftLint
tuist install && tuist generate --no-open
mise run ios:run -- -OSMAPIBaseURL http://localhost:5173 -OSMDebugToken <token>
```

Or open `OpenSkateMap.xcworkspace` and add those launch arguments to the scheme.

Sign in with Apple, push notifications and tips are tied to the real app's identifiers, so they don't work in your
build; the token stands in for signing in. To run on your own iPhone, create `xcconfigs/Local.xcconfig` (it's
git-ignored) with your team and a bundle id of your own; capabilities like Sign in with Apple need a paid account:

```
DEVELOPMENT_TEAM = ABCDE12345
BUNDLE_ID = com.example.openskatemap
```

Every command, the other launch arguments and the tests are in [.docs/commands.md](.docs/commands.md).
