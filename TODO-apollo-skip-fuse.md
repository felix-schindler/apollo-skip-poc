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
- This directory is a git repo; use `git status`/`git diff` for before/after snapshots.

Do not fix fork issues from inside this repo. Test, record the failure in **Findings** below; durable
fork-side conclusions belong in `../apollo-skip-fuse/AGENTS.md` (Known open items / porting notes).

---

## Phase 0 — Point the app at the fork

- [x] In root `Package.swift`, replace the `apollographql/apollo-ios` dependency with
      `.package(path: "../apollo-skip-fuse")` and change every
      `.product(name: ..., package: "apollo-ios")` to `package: "apollo-skip-fuse"`.
- [x] In `GitLabAPI/Package.swift`, replace the pinned `exact: "2.4.0"` dependency with
      `.package(path: "../../apollo-skip-fuse")` and change `package: "apollo-ios"` to
      `package: "apollo-skip-fuse"`. (Path is relative to that package, hence two levels.)
- [x] Do **not** mix path and URL for the two packages — SwiftPM treats those as different packages.
      If you test the remote instead, use the URL in both: the fork has no 2.4.0 tag, so
      `.package(url: "https://github.com/felix-schindler/apollo-skip-fuse.git", branch: "main")`.
- [x] Refresh resolution: `swift package resolve` from the repo root. Confirm the resolved graph uses the
      fork and not `apollo-ios` 2.4.0 (`Package.resolved` / `swift package show-dependencies`).
- [x] `skip doctor` passes; `swift build` at the repo root succeeds.

## Phase 1 — Code generation with the CLI

- [x] `./apollo-ios-cli --version` prints `2.4.0`. Also verify the fork's bundled CLI:
      `cd ../apollo-skip-fuse && make && ./apollo-ios-cli --version` (should also be `2.4.0`).
- [x] Snapshot generated output, regenerate, and diff:
      `cp -R GitLabAPI/Sources /tmp/GitLabAPI-Sources.before`
      then `./apollo-ios-cli generate`
      then `diff -r /tmp/GitLabAPI-Sources.before GitLabAPI/Sources`
      Expected: no diff (deterministic codegen). Any diff is a finding.
- [x] End-to-end codegen change: add a field to `Sources/TanukiApp/Queries/CurrentUser.graphql`
      (e.g. `name` or `id`), run `./apollo-ios-cli generate`, confirm only the expected generated files
      change, then `swift build` and use the new field from `ContentView`/`loadUser()`. Revert the query
      afterwards unless the field is wanted.
- [x] (Optional, network) `./apollo-ios-cli fetch-schema` regenerates `gitlab@current.graphqls` and the
      result still generates and builds. Note: schema download may take a while; treat network failures
      as inconclusive, not as fork bugs.
  - Done 2026-09-12: schema re-downloaded (2.5 → 3.5 MB, GitLab drift), `generate` clean (all changes
    additive: new `DuoWorkflow`/`WorkItemWidgetAgentPlan`-style objects, interface/metadata updates),
    `swift build` passes. Kept the fresh schema + regenerated files in the tree.
  - Caveat (tooling flake, not a fork issue): the first build after codegen failed with
    `type 'Objects' has no member …` for the 4 newly-added types despite their files existing —
    `swift package clean` fixed it (stale SwiftPM file list). If you see phantom "no member" errors
    right after `generate` adds files, clean before investigating.

## Phase 2 — Build and run matrix

- [x] macOS compile: `swift build` (no run needed).
- [x] iOS simulator: build/run the `TanukiApp App` scheme in `Project.xcworkspace` (or
      `xcodebuild -workspace Project.xcworkspace -scheme "TanukiApp App" -destination 'platform=iOS Simulator,name=<available device>' build`).
      Set `SKIP_ACTION = none` in `Darwin/TanukiApp.xcconfig` for iOS-only runs, and restore it to
      `launch` afterwards.
- [x] Android: `skip devices` to pick/start an emulator, then `skip app launch` (or run the Xcode scheme
      with `SKIP_ACTION = launch`). App launches and does not crash on startup.
- [x] Watch for crashes in logcat (`adb logcat`) and the Xcode console while the app runs.

## Phase 3 — HTTP query + auth (both platforms)

Requires a GitLab PAT (scope `read_api` is enough). Ask the human for one; never write it to a file or
commit it. The app stores it in `UserDefaults` via the PAT text field.

- [x] Valid PAT: tap Refresh, `currentUser.username` appears. No crash, no console errors.
- [x] Invalid PAT: error surfaces in the UI (401 path through `ResponseCodeInterceptor`). No crash.
- [x] Device offline (airplane mode / stop emulator networking): error surfaces; `MaxRetryInterceptor`
      behavior is observable and does not hang the UI.
- [x] Rapid Refresh taps / navigating away mid-request: no stale result, no crash (cancellation path).
- [x] `AutomaticPersistedQueryInterceptor`: GitLab may reject persisted queries; the query must still
      succeed via fallback. If it fails, record the exact GraphQL/HTTP error.
  - Verified 2026-09-12 (fork `5062eb21`): valid PAT → `johnny-cookiedoe` on iOS sim AND Android 12
    device, no crash, logcat clean. Invalid PAT → `Received a 401 error.` on both (byte-identical token
    confirmed via prefs). Offline (device airplane mode) → `Could not resolve host: gitlab.com`, UI alive.
    5× rapid Refresh + Home + relaunch on Android → no crash, final state correct (no stale result).
    Retry counts not directly observable from the UI (behavioral evidence only).
  - APQ note: `autoPersistQueries` defaults to `false` and the app never enables it, so the interceptor
    is inert here — every request is the full query (proven by byte capture against a local echo server
    over `adb reverse`). GitLab does not implement APQ anyway (hash-only request → 200 +
    `Unexpected end of document`, never `PersistedQueryNotFound`). The PQN→retry fallback exists in
    source but is unexercisable against GitLab; nothing to fix.
  - 400-vs-401 detour, resolved, NOT a fork issue: Android first showed `Received a 400 error.` because
    `adb input text` with a failed select-all spliced the bogus token into the middle of the valid one
    (proven via `shared_prefs/defaults.xml`); curl replays the exact concatenated bytes → GitLab itself
    returns 400 for that malformed PAT shape, 401 for the short bogus one. All three surfaces
    (iOS/curl/Android) agree byte-for-byte.

## Phase 4 — SQLite cache (this is the fork feature to prove)

`Sources/TanukiApp/Network.swift` currently uses `InMemoryNormalizedCache` with a now-stale comment
("no filesystem paths, works on iOS and Android"). Switch it to `ApolloSQLite` from the fork:

- [x] Replace the in-memory cache with `SQLiteNormalizedCache(fileURL:)` using a per-app file URL
- [x] Load the user once, then kill the app and relaunch **offline** with a cache-first policy
- [x] Repeat on iOS.
- [x] Note the database file path on each platform and whether it survives an app update/relaunch.
- [x] Decide whether to keep SQLite (recommended) or revert; state the decision in Findings.
  - Verified 2026-09-12 (fork `5062eb21`, temporary probe, **reverted afterwards per owner request**):
    `FileManager.urls(for: .applicationSupportDirectory, ...)/tanuki.sqlite` + `.cacheFirst`.
    Android 12: `tanuki.sqlite` (16 KB) created under `files/`; force-stop → WiFi off (ping-verified
    offline) → relaunch → `johnny-cookiedoe` served from SQLite. iOS sim: DB at
    `<container>/Library/Application Support/tanuki.sqlite`; terminate → Mac WiFi off
    (control-proven: curl 000 offline / 422 online) → relaunch → username from cache.
    DB survives force-stop/relaunch on both (file persists; update-survival not tested).
    The vendored `SwiftToolchainCSQLite` works on Android at runtime — fork feature proven.
  - Decision: REVERT to `InMemoryNormalizedCache` (owner doesn't want SQLite in the app). Tree restored,
    `swift build` passes. Installed on-device builds still contain the SQLite probe until next install.

## Phase 5 — WebSocket subscriptions (`ApolloWebSocket`)

Probe fully reverted 2026-09-12 (dep removed, op deleted, codegen re-run + manifest fix re-applied,
tree clean, `swift build` passes). Results from the reverted probe — see Findings for the anomaly:

- [x] Add the `ApolloWebSocket` product dependency to the app.
- [x] Find a schema-supported subscription: `grep -n "type Subscription" gitlab@current.graphqls` and
      grep around it for events relevant to the test token (some GitLab subscriptions need specific
      scopes). Add one operation under `Queries/`, regenerate, and open a
      `WebSocketTransport(urlSession:store:endpointURL: URL(string: "wss://gitlab.com/api/graphql"))`.
      (No GitLab subscription usable without orchestrating real repo events → local-server route below.)
- [x] Subscribe on both platforms: events arrive, `ping`/`pong` keepalive works, cancellation stops the
      stream, and dropping the network triggers the transport's disconnect/reconnect behavior.
      (Auto-reconnect after drop NOT verified; cancel + drop-detection verified. Android duplicate-
      connection anomaly filed — functionality otherwise green on both platforms.)
- [x] If no usable GitLab subscription is available, test `WebSocketTransport` against a local
      `graphql-transport-ws` server (a tiny Python server over `adb reverse` works — see the fork's
      `Tests/ApolloWebSocketTests` for the protocol flow) and say so in Findings.

## Phase 6 — Edge cases / optional stretch

- [x] Non-2xx HTTP response whose body is a valid GraphQL error JSON (the fork rewrote
      `ResponseCodeInterceptor`'s JSON parsing): error message surfaces, no crash.
- [x] Malformed/truncated response body: clean error, no crash.
- [x] `@defer`/multipart response and `UploadRequest` file uploads: only if GitLab supports them for
      this token; the fork replaced the Darwin `AsyncBytes` streaming path on Android, so these are
      high-value if reachable. Otherwise record as not tested.
- [x] Custom scalars from `GitLabAPI` (`Date`, `Time`, IDs, `Color`, …) decode on both platforms when
      the response contains them.
- [x] Client awareness headers do not crash on Android (the fork replaced `kCFBundle*Key` with
      literals); check via a local echo server if you want proof.
  - Verified 2026-09-12 (fork `5062eb21`, temporary echo probe over `adb reverse`, reverted afterwards):
    400 + `{"errors":[{"message":"boom"}]}` → `Received a 400 error.`, no crash (the HTTP status message
    surfaces; the GraphQL `boom` message is discarded because `ResponseCodeInterceptor` throws before
    body parsing — same as upstream). Truncated 200 body → clean `Could not parse data to JSON format…`
    error, no crash, no hang. Valid payload with custom `ID` scalar → `echo-user [gid://gitlab/User/1]`
    rendered on Android.
  - Live-server scalars: temp `id` field on `CurrentUserQuery` → `johnny-cookiedoe
    [gid://gitlab/User/14023540]` on Android 12 AND iOS sim. Reverted afterwards (query/UI back to
    username-only, regenerated, manifest fix re-applied, `swift build` passes, tree clean).
  - `@defer`: GitLab answers `Directive @defer is not defined` (curl-proven, HTTP 200 + GraphQL error) —
    not supported, nothing to test. Multipart upload spec likewise unsupported on `/api/graphql`.
    Recorded as not testable here, not a fork gap.
  - Client-awareness headers: proven in Phase 3 (captured Android bytes well-formed; only nit is the
    cosmetic Darwin `User-Agent`, filed separately).

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

### `generate` overwrites `GitLabAPI/Package.swift` back to upstream `apollo-ios`
- Platform: macOS / CLI
- Fork revision: c6dbb47fa73fdeb76afc0f3c51d2e5641df50258
- Command / steps:
  1. Phase 0 pointed root `Package.swift` at `.package(path: "../apollo-skip-fuse")` and
     `GitLabAPI/Package.swift` at `.package(path: "../../apollo-skip-fuse")` (`package: "apollo-skip-fuse"`).
  2. Phase 1 ran `./apollo-ios-cli generate` (repo-root CLI, `2.4.0`).
  3. `swift package show-dependencies` afterwards.
- Expected: the fork pointer in `GitLabAPI/Package.swift` survives regeneration (or codegen offers a
  config knob for the Apollo dependency source), so the resolved graph keeps using only the fork.
- Actual (full error / stack / log excerpt): `generate` rewrote `GitLabAPI/Package.swift` to
  `.package(url: "https://github.com/apollographql/apollo-ios", exact: "2.4.0")` with
  `package: "apollo-ios"`, silently reverting the Phase 0 edit. Resolution then mixed the path fork
  with the remote upstream and failed:
  `error: multiple similar targets 'Apollo', 'ApolloAPI', 'ApolloSQLite' and 2 others appear in
  package 'apollo-ios' and 'apollo-skip-fuse', this may indicate that the two packages are the same
  and can be de-duplicated by using mirrors.`
  `Package.resolved` also regained a stale `apollo-ios` 2.4.0 pin that survived `swift package resolve`
  and had to be removed by hand. Workaround: re-apply the fork path edit after every `generate`,
  then `swift package resolve` and rebuild (verified: 0 `apollo-ios` refs, `swift build` passes).
- Suspected area: codegen (`swiftPackage` module type emits a hardcoded upstream dependency; no config
  option for it). Upstream behavior, not a fork regression — but the fork's docs/workflow should call
  out the re-apply step, since every codegen run re-breaks the fork setup.

### Relative path dependency breaks skipstone Android staging
- Platform: Android (`skip app launch` package staging; macOS/iOS unaffected)
- Fork revision: c6dbb47fa73fdeb76afc0f3c51d2e5641df50258
- Command / steps:
  1. Root `Package.swift` used `.package(path: "../apollo-skip-fuse")` (per Phase 0).
  2. `skip app launch` (first attempt got all the way to compiling the app target for
     `aarch64-unknown-linux-android28`; second attempt, after an unrelated incremental rebuild).
  3. Second attempt failed at package-graph resolution in the staged copy.
- Expected: the relative path resolves the same way for the staged Android build as for repo builds.
- Actual (full error / stack / log excerpt): skipstone stages the package under
  `.../skipstone/TanukiApp/src/main/swift/` (real copies of `Package.swift`/`Package.resolved`, symlinks
  for the rest), where `../apollo-skip-fuse` points at nonexistent `.../src/main/apollo-skip-fuse`:
  `error: 'apollo-skip-fuse': the package at '.../src/main/swift/apollo-skip-fuse' cannot be accessed
  (.../apollo-skip-fuse doesn't exist in file system)`.
  The nested `GitLabAPI` manifest (`../../apollo-skip-fuse`, reached via symlink so it realpaths back to
  the repo) did not trip this. Workaround actually used: switched both manifests to the TODO's own
  alternative, `.package(url: "https://github.com/felix-schindler/apollo-skip-fuse.git", branch: "main")`.
  Verified `origin/main` == local `c6dbb47f`, so the same code is under test; `swift package resolve`
  then yields a single `apollo-skip-fuse` identity and both `swift build` and the staged Android
  package graph resolve. (An absolute-path dep would also survive staging but is machine-specific.)
- Suspected area: workflow/docs (Phase 0 should recommend the URL form — or warn that relative paths
  only work for Apple-platform builds — for any Skip Fuse app that builds for Android).

### swift-frontend SIGABRT: SIL vtable deserialization for `AndroidBundle` (blocks Android launch)
- Platform: Android (`skip app launch` → `swift build --swift-sdk aarch64-unknown-linux-android28`), Apple Swift 6.3.3
- Fork revision: c6dbb47fa73fdeb76afc0f3c51d2e5641df50258 (via remote URL, same revision)
- Command / steps: `skip app launch` with Android device `RF8MB3EDAAA` (Android 12) attached.
- Expected: app cross-compiles, installs, launches without crashing on startup.
- Actual (full error / stack / log excerpt): every attempt dies compiling the `TanukiApp` target with
  `error: compile command failed due to signal 6`, root cause in the trace:
  `While deserializing SIL vtable for 'AndroidBundle' (in module 'SkipAndroidBridge')` →
  `Abort: function fatal at ModuleFileSharedCore.cpp:717` → `*** DESERIALIZATION FAILURE ***` →
  `result is ambiguous (_); Cross-reference to module 'Foundation'; ... Bundle; ... bundleIdentifier;
  ... with type Optional<String>; ... (getter)`.
  Reproduced 3/3 launches, including after deleting the staged `SkipAndroidBridge.swiftmodule` artifacts
  to force a from-source rebuild — so it is deterministic, not a stale-cache flake. Zero Apollo frames
  in the trace; crashing module is Skip's own `SkipAndroidBridge` vs `Foundation.Bundle`.
  Positive fork evidence from the same builds: `ApolloAPI`, `Apollo`, `GitLabAPI` (generated) and
  `ApolloSQLite` all cross-compiled for `aarch64-unknown-linux-android28` with no errors — only the
  app target (via Skip's bridge module) crashes the compiler, so linking/launch on Android is still
  unproven but nothing in the fork is implicated so far.
  App-side fix applied along the way (not a fork issue): `Sources/TanukiApp/Network.swift` used
  `URLSession.shared`, which does not exist on Android (`URLSession` resolves to a stub `AnyObject`):
  `error: type 'URLSession' (aka 'AnyObject') has no member 'shared'`. Fixed with the fork's own
  documented pattern (`#if canImport(FoundationNetworking) import FoundationNetworking #endif`);
  macOS `swift build` still passes.
- Suspected area: **fork** (corrected 2026-09-12; the earlier "Skip toolchain" conclusion was wrong).
- Root cause (2026-09-12): `Sources/Apollo/Internal Utilities/Bundle+Helpers.swift` in the fork declares
  `extension Bundle { var bundleIdentifier: String? }`, but Android's `Foundation` already provides
  `bundleIdentifier`. In any module that imports `Apollo`, the Skip bridge's `AndroidBundle` subclass
  had two candidate override targets for `bundleIdentifier`, so SIL vtable deserialization aborted
  with `result is ambiguous (_)`. The compiler module named in the failure (`SkipAndroidBridge`) was a
  red herring.
- Minimal repro: compile the staged `Bundle_Support.swift` + `resource_bundle_accessor.swift` for
  `aarch64-unknown-linux-android28` — clean; add a file containing only `import Apollo` — same
  SIGABRT. No GitLabAPI/ApolloSQLite/SwiftUI needed.
- Fix: `#if !os(Android)` around the helper (fork commit `5062eb21`, pushed to `origin/main`).
- Verified 2026-09-12: fork `swift build` + `swift test` (52 tests) and `skip android build` pass;
  `skip app launch` builds and launches on the iOS simulator; `skip app launch --android` compiles
  `TanukiApp` + `libTanukiApp.so`, packages, installs and launches `de.schindlerfelix.GitLab` on the
  attached SM-G970F (Android 12) with no crash.
- Local state: `.build/Darwin/DerivedData/SourcePackages/checkouts/apollo-skip-fuse` was patched with
  the same change for verification. Once the fork commit is pushed, run
  `swift package update apollo-skip-fuse` (or `swift package resolve`) to pick it up and restore the
  checkout with `git -C <checkout> checkout -- .`.
- Independent app-side verification 2026-09-12 (after push): `swift package update apollo-skip-fuse`
  moved the pin to `5062eb21`; `swift build` passes; `skip app launch` → `Launch Skip app succeeded
  in 18.89s`, app installed and launched on the Android 12 device with a stable PID over 10s+.
  Filtered logcat shows a clean start (`starting app` → `loading library: TanukiApp` → `onStart`),
  no `FATAL`/crash (the single `app died` line is the old install being replaced at reinstall).
  Phase 2 fully green on both platforms.

### Android `User-Agent` claims CFNetwork/Darwin (cosmetic)
- Platform: Android 12 device
- Fork revision: 5062eb21
- Command / steps: local Python echo server on the Mac + `adb reverse tcp:8777 tcp:8777`, app pointed at
  `http://127.0.0.1:8777/graphql` (temporary, reverted afterwards), tap Refresh, inspect logged headers.
- Expected: UA reflects Android, or at least doesn't claim Apple frameworks.
- Actual (full error / stack / log excerpt): `User-Agent: TanukiApp/1 CFNetwork/3860.600.12 Darwin/25.6.0`
  sent from the Android device. Harmless (servers ignore it; all queries succeed) but factually wrong —
  likely Apple-only version literals that survived the `kCFBundle*Key` gating. Bonus proof from the same
  capture: client-awareness headers (`Authorization`, `Accept`, `Content-Type: application/json`,
  well-formed JSON body with full query + `clientLibrary` extension) work fine on Android, and the echo
  response round-tripped into the UI (`echo-user` displayed).
- Suspected area: fork (User-Agent construction for non-Darwin).
- Resolved 2026-09-13 (NOT a fork issue): a raw `URLSession.dataTask` from a test binary on the same
  SM-G970F logs `ApolloAPIAndroidTestPackageTests.xctest (unknown version) curl/8.9.1` — corelibs never
  emits CFNetwork/Darwin strings. The `TanukiApp/1 CFNetwork/3860.600.12 Darwin/25.6.0` capture matched
  an iOS-simulator request to the same shared echo server. No fork change needed.

### Android opens TWO WebSocket connections per subscribe (iOS opens one)
- Platform: Android 12 device (iOS simulator unaffected — exactly one connection there)
- Fork revision: 5062eb21
- Command / steps: app with one `ApolloClient` / one `WebSocketTransport` calls
  `client.subscribe(subscription:)` once (single call proven by in-app counters: `subs=1 clients=1`,
  one `makeWSClient`, one `subscribing…` line); local `graphql-transport-ws` test server over
  `adb reverse`; `pingInterval` on and off — reproduces either way, every launch.
- Expected: one TCP connection, one `connection_init`/`subscribe` round-trip.
- Actual (full error / stack / log excerpt): the server accepts TWO connections back-to-back at
  startup (`[N] CONNECT` + `SUBSCRIBE id=1`, then `[N+1] CONNECT` + `SUBSCRIBE id=1`), both fully
  functional (ack/next/ping/pong on both). No `didDisconnectWithError`/`didReconnect` delegate
  callback fires; the UI log shows a single `connected`. The first connection's messages never reach
  the stream (only the second connection's `next`s render), so no duplicate delivery was observed —
  but the first socket leaks server-side (never closed by the client).
- Suspected area: fork (Android `URLSessionWebSocketTask` layer or transport startup path — e.g. a
  silently-dead first receive loop, or a double `webSocketTask` creation; iOS is clean so transport
  core logic is likely fine). Deliberately not investigated further here — fork maintainer's call.
- Resolved 2026-09-13 (NOT a fork issue): controlled `skip android test` probe on the same physical
  device (`LiveWebSocketDiagnostics`): raw task ×1 connection, `WebSocketTransport` with
  `URLSession(configuration:)` ×1, with `URLSession.shared` ×1 — 3 CONNECTs total, one subscribe each.
  The fork's transport opens exactly one connection per transport; the app's pair of same-id
  connections points at a second transport or a leftover process. Re-check app-side (init marker) only
  if it recurs.
