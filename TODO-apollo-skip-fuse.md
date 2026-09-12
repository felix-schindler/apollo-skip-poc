# TODO: Verify `apollo-skip-fuse` end-to-end in this app

**Purpose:** exercise the forked Apollo runtime (`../apollo-skip-fuse`) from a real Skip Fuse app —
codegen, Darwin/iOS + Android builds, HTTP, caching, WebSockets, errors — and report every failure.

**Fork under test:** `../apollo-skip-fuse` (fork of `apollographql/apollo-ios` 2.4.0 with Android/Skip Fuse
support). Record the revision you tested:

```sh
git -C ../apollo-skip-fuse rev-parse HEAD          # record this in Findings
git -C ../apollo-skip-fuse status --short          # must be clean for a reproducible run
```

References:
- Fork porting notes: `../apollo-skip-fuse/AGENTS.md`
- This app's conventions: `AGENTS.md` (operations in `Sources/TanukiApp/Queries/`, generated code in
  `GitLabAPI/` is `@generated` — never hand-edit it, use the CLI).
- This directory is **not** a git repo, so do not rely on `git status` for diffs. Snapshot before/after
  and use `diff -r` instead.

Do not fix fork issues from inside this repo. Test, record the failure in **Findings** below, and also
append it to `../apollo-skip-fuse/TODO-from-apollo-test.md` (create it) so the fork maintainer sees it.

---

## Phase 0 — Point the app at the fork

- [ ] In root `Package.swift`, replace the `apollographql/apollo-ios` dependency with
      `.package(path: "../apollo-skip-fuse")` and change every
      `.product(name: ..., package: "apollo-ios")` to `package: "apollo-skip-fuse"`.
- [ ] In `GitLabAPI/Package.swift`, replace the pinned `exact: "2.4.0"` dependency with
      `.package(path: "../../apollo-skip-fuse")` and change `package: "apollo-ios"` to
      `package: "apollo-skip-fuse"`. (Path is relative to that package, hence two levels.)
- [ ] Do **not** mix path and URL for the two packages — SwiftPM treats those as different packages.
      If you test the remote instead, use the URL in both: the fork has no 2.4.0 tag, so
      `.package(url: "https://github.com/felix-schindler/apollo-skip-fuse.git", branch: "main")`.
- [ ] Refresh resolution: `swift package resolve` from the repo root. Confirm the resolved graph uses the
      fork and not `apollo-ios` 2.4.0 (`Package.resolved` / `swift package show-dependencies`).
- [ ] `skip doctor` passes; `swift build` at the repo root succeeds.

## Phase 1 — Code generation with the CLI

- [ ] `./apollo-ios-cli --version` prints `2.4.0`. Also verify the fork's bundled CLI:
      `cd ../apollo-skip-fuse && make && ./apollo-ios-cli --version` (should also be `2.4.0`).
- [ ] Snapshot generated output, regenerate, and diff:
      `cp -R GitLabAPI/Sources /tmp/GitLabAPI-Sources.before`
      then `./apollo-ios-cli generate`
      then `diff -r /tmp/GitLabAPI-Sources.before GitLabAPI/Sources`
      Expected: no diff (deterministic codegen). Any diff is a finding.
- [ ] End-to-end codegen change: add a field to `Sources/TanukiApp/Queries/CurrentUser.graphql`
      (e.g. `name` or `id`), run `./apollo-ios-cli generate`, confirm only the expected generated files
      change, then `swift build` and use the new field from `ContentView`/`loadUser()`. Revert the query
      afterwards unless the field is wanted.
- [ ] (Optional, network) `./apollo-ios-cli fetch-schema` regenerates `gitlab@current.graphqls` and the
      result still generates and builds. Note: schema download may take a while; treat network failures
      as inconclusive, not as fork bugs.

## Phase 2 — Build and run matrix

- [ ] macOS compile: `swift build` (no run needed).
- [ ] iOS simulator: build/run the `TanukiApp App` scheme in `Project.xcworkspace` (or
      `xcodebuild -workspace Project.xcworkspace -scheme "TanukiApp App" -destination 'platform=iOS Simulator,name=<available device>' build`).
      Set `SKIP_ACTION = none` in `Darwin/TanukiApp.xcconfig` for iOS-only runs, and restore it to
      `launch` afterwards.
- [ ] Android: `skip devices` to pick/start an emulator, then `skip app launch` (or run the Xcode scheme
      with `SKIP_ACTION = launch`). App launches and does not crash on startup.
- [ ] Watch for crashes in logcat (`adb logcat`) and the Xcode console while the app runs.

## Phase 3 — HTTP query + auth (both platforms)

Requires a GitLab PAT (scope `read_api` is enough). Ask the human for one; never write it to a file or
commit it. The app stores it in `UserDefaults` via the PAT text field.

- [ ] Valid PAT: tap Refresh, `currentUser.username` appears. No crash, no console errors.
- [ ] Invalid PAT: error surfaces in the UI (401 path through `ResponseCodeInterceptor`). No crash.
- [ ] Device offline (airplane mode / stop emulator networking): error surfaces; `MaxRetryInterceptor`
      behavior is observable and does not hang the UI.
- [ ] Rapid Refresh taps / navigating away mid-request: no stale result, no crash (cancellation path).
- [ ] `AutomaticPersistedQueryInterceptor`: GitLab may reject persisted queries; the query must still
      succeed via fallback. If it fails, record the exact GraphQL/HTTP error.

## Phase 4 — SQLite cache (this is the fork feature to prove)

`Sources/TanukiApp/Network.swift` currently uses `InMemoryNormalizedCache` with a now-stale comment
("no filesystem paths, works on iOS and Android"). Switch it to `ApolloSQLite` from the fork:

- [ ] Replace the in-memory cache with `SQLiteNormalizedCache(fileURL:)` using a per-app file URL
      (e.g. under `URL.applicationSupportDirectory`); keep it working on both platforms.
- [ ] Load the user once, then kill the app and relaunch **offline** with a cache-first policy
      (`.cacheFirst` in `ApolloClient.fetch(query:cachePolicy:)`, or `FetchBehavior.CacheFirst` if you
      go through the transport directly): cached username still appears. This proves the vendored SQLite
      works on Android at runtime.
- [ ] Repeat on iOS.
- [ ] Note the database file path on each platform and whether it survives an app update/relaunch.
- [ ] Decide whether to keep SQLite (recommended) or revert; state the decision in Findings.

## Phase 5 — WebSocket subscriptions (`ApolloWebSocket`)

- [ ] Add the `ApolloWebSocket` product dependency to the app.
- [ ] Find a schema-supported subscription: `grep -n "type Subscription" gitlab@current.graphqls` and
      grep around it for events relevant to the test token (some GitLab subscriptions need specific
      scopes). Add one operation under `Queries/`, regenerate, and open a
      `WebSocketTransport(urlSession:store:endpointURL: URL(string: "wss://gitlab.com/api/graphql"))`.
- [ ] Subscribe on both platforms: events arrive, `ping`/`pong` keepalive works, cancellation stops the
      stream, and dropping the network triggers the transport's disconnect/reconnect behavior.
- [ ] If no usable GitLab subscription is available, test `WebSocketTransport` against a local
      `graphql-transport-ws` server (a tiny Python server over `adb reverse` works — see the fork's
      `Tests/ApolloWebSocketTests` for the protocol flow) and say so in Findings.

## Phase 6 — Edge cases / optional stretch

- [ ] Non-2xx HTTP response whose body is a valid GraphQL error JSON (the fork rewrote
      `ResponseCodeInterceptor`'s JSON parsing): error message surfaces, no crash.
- [ ] Malformed/truncated response body: clean error, no crash.
- [ ] `@defer`/multipart response and `UploadRequest` file uploads: only if GitLab supports them for
      this token; the fork replaced the Darwin `AsyncBytes` streaming path on Android, so these are
      high-value if reachable. Otherwise record as not tested.
- [ ] Custom scalars from `GitLabAPI` (`Date`, `Time`, IDs, `Color`, …) decode on both platforms when
      the response contains them.
- [ ] Client awareness headers do not crash on Android (the fork replaced `kCFBundle*Key` with
      literals); check via a local echo server if you want proof.

---

## Findings

For each issue, add a block:

```
### <short title>
- Platform: Android (device/API) | iOS (simulator) | macOS | CLI
- Fork revision: <sha>
- Command / steps:
- Expected:
- Actual (full error / stack / log excerpt):
- Suspected area: (e.g. ApolloWebSocket, ApolloSQLite, JSON parsing, codegen)
```

- (empty — add issues here as you find them)
