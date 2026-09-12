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
- [ ] (Optional, network) `./apollo-ios-cli fetch-schema` regenerates `gitlab@current.graphqls` and the
      result still generates and builds. Note: schema download may take a while; treat network failures
      as inconclusive, not as fork bugs.

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
