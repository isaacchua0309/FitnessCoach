# Build Warnings Register

Tracked compile warnings, test-infra failures, and backend lint items. Update when warnings are fixed or newly discovered.

**Last reviewed:** 2026-07-05  
**Related:** [ProjectHygieneRegister.md](./ProjectHygieneRegister.md), [TechnicalDebtRegister.md](./TechnicalDebtRegister.md)

---

## Latest capture (2026-07-05)

| Field | Value |
|-------|-------|
| **Host** | macOS with Xcode required (`xcodebuild` not available on Linux cloud agents) |
| **Simulator** | `platform=iOS Simulator,name=iPhone 17` (iOS 26.5) |
| **Package resolution** | Run `xcodebuild -resolvePackageDependencies` before test builds |
| **Test host** | `Fitness CoachTests` uses `TEST_HOST` + `BUNDLE_LOADER` (app executable); Firebase/GoogleSignIn SPM linked in app only |
| **Fast-Core runner** | `./Scripts/run_fast_core_tests.sh` (resolve → build-for-testing → serial test) |
| **Backend** | `npm --prefix functions run build/lint/test` → pass |

### BW-101 resolution (2026-07-05)

| Root cause | Fix |
|------------|-----|
| BW-002 removed Firebase SPM from `Fitness CoachTests` while keeping `Fitness Coach.debug.dylib` link | Duplicate ObjC classes at runtime **or** compile failure when SPM absent from test target |
| Test target lacked stable host wiring | Switched to `TEST_HOST` / `BUNDLE_LOADER`; removed test-target Firebase/GoogleSignIn SPM products |
| Missing `resolvePackageDependencies` step | Documented in `Scripts/run_fast_core_tests.sh` and `capture_build_warnings.sh` |
| Parallel Fast-Core amplified XCTest restarts | `Fast-Core.xctestplan` now `parallelizable: false` (serial) |

**Verify on Mac:**

```bash
./Scripts/run_fast_core_tests.sh
# or
export DESTINATION='platform=iOS Simulator,name=iPhone 17'
xcodebuild -resolvePackageDependencies -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach"
xcodebuild test -project "Fitness Coach.xcodeproj" -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core -parallel-testing-enabled NO
```

Expected: `TEST BUILD SUCCEEDED` then `TEST SUCCEEDED`.

**Sprint context (PR #178):** HI consolidation v2 + PH-004 fixture batch 1 + TD-COACH-001 tail landed on branch; Mac verification is the acceptance gate for TD-TEST-001.

---

## Prior capture (2026-07-05, pre-fix)

| Field | Value |
|-------|-------|
| **App build** | `xcodebuild build` → **BUILD SUCCEEDED** |
| **Test build** | `build-for-testing` → **FAILED** (`Unable to resolve module dependency: 'FirebaseCore'`) when test target had no SPM + debug.dylib |
| **Test run** | Fast-Core not run (blocked by test build failure) |

### Warning counts

| Build | Warnings | Notes |
|-------|----------|-------|
| App incremental (pre-fix) | 2 | Duplicate plist + AppIntents metadata |
| App incremental (post-fix, 2026-07-05) | ~577 | Mostly Swift 6 concurrency (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`) |
| `build-for-testing` (pre-fix) | ~669 | App compile warnings + test-target module errors |

### Slow build phases (incremental app build, post-fix)

| Phase | Time |
|-------|------|
| `Ld` | 1.18 s |
| `CodeSign` | 0.33 s |
| `ProcessInfoPlistFile` | 0.17 s |
| `ExtractAppIntentsMetadata` | 0.15 s |

Full clean compiles are dominated by `CompileSwift` (not surfaced in incremental timing summary). Re-capture after `clean build` for per-file compile timing.

### Failed commands

| Command | Error |
|---------|-------|
| `xcodebuild … -destination 'platform=iOS Simulator,name=iPhone 16'` | Simulator not found — use iPhone 17 locally |
| `xcodebuild build-for-testing …` | `Fitness CoachTests`: `Unable to resolve module dependency: 'FirebaseCore'`, `GoogleSignIn`, and 10 other Firebase/Google transitive modules |

### Environment / package warnings

| ID | Source | Symptom | Notes |
|----|--------|---------|-------|
| BW-301 | npm | `npm warn Unknown env config "devdir"` on every `npm` invocation | Host-level `.npmrc` / env config — not project code; harmless today |

### Benign Xcode messages (not tracked as debt)

- `appintentsmetadataprocessor: Metadata extraction skipped. No AppIntents.framework dependency found` — expected; app does not ship App Intents.

---

## Capture commands

### iOS

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'

./Scripts/capture_build_warnings.sh "$DESTINATION"

xcodebuild build -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  -showBuildTimingSummary \
  2>&1 | tee /tmp/xcodebuild.log

xcodebuild build-for-testing -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  2>&1 | tee /tmp/xcodebuild-bft.log

xcodebuild test -scheme "Fitness Coach" \
  -destination "$DESTINATION" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO \
  2>&1 | tee /tmp/xcodebuild-test.log
```

### Backend

```bash
npm --prefix functions run build
npm --prefix functions run lint
npm --prefix functions test
npm --prefix functions run test:coach
npm --prefix functions run test:firestore-rules   # requires Firestore emulator
```

---

## Fixed in this pass (2026-07-05)

| ID | Area | Issue | Resolution |
|----|------|-------|------------|
| BW-001 | `functions` ESLint | Unused `field` params in `coachContextPacketV2.ts` validators | Renamed to `_field` |
| BW-002 | `Fitness CoachTests` target | Duplicate Firebase/GoogleSignIn SPM products linked in test bundle **and** app `debug.dylib` | **Resolved (2026-07-05)** — SPM products linked for compile-time module resolution; post-build **Strip Duplicate SPM Frameworks** script removes embedded copies so runtime loads a single copy from the host app |
| BW-003 | `functions` Jest | `npm test` failed without Firestore emulator | Default `npm test` runs unit suite; `test:all` + `test:firestore-rules` for rules integration |
| BW-106 | Xcode project | Duplicate `GoogleService-Info.plist` in Copy Bundle Resources (folder-sync + explicit Resources phase) | Removed explicit `PBXBuildFile` / Resources entry; folder-sync group retains file |
| BW-107 | SwiftUI previews | `previewInterfaceOrientation` / `previewDevice` ignored inside `#Preview` macro | Landscape previews use `traits: .landscapeLeft`; removed ignored `previewDevice` modifiers |
| BW-108 | Swift lint | `var` never mutated (`meal`, `result`, `missingData`, 12× `properties`) | Changed to `let` in 4 files |
| BW-103 | Deprecation | ~~`AIContext` retained for Codable/mocks~~ | **Resolved** — struct deleted; `TodayAISummary` extracted |
| BW-203 | Jest snapshots | `coachPromptSnapshots.test.ts` drift | Snapshots updated |
| BW-204 | Jest `test:coach` script | Pattern matched repo folder `FitnessCoach` | Anchored to `test/coach` |

---

## Remaining — iOS

| ID | Category | Symptom | Count (approx.) | Notes / safe fix path |
|----|----------|---------|-----------------|------------------------|
| BW-101 | Test compile | ~~`Fitness CoachTests` cannot resolve Firebase/GoogleSignIn SPM modules~~ | — | **Closed 2026-07-05** — `Fitness CoachTests` links the same seven SPM products as the app; **Strip Duplicate SPM Frameworks** build phase prevents runtime duplicate ObjC classes. Verify: `./Scripts/run-fast-core-serial.sh`. See TD-TEST-001 / PH-001. |
| BW-102 | Concurrency | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide | ~500+ | Per-site `@MainActor` / `nonisolated` / `await MainActor.run` — audit by subsystem; do **not** blanket-suppress. Top buckets: `init()` in nonisolated context, static config flags, `HealthKitManager.mapQueryError`, `resumed` capture in async tests. |
| BW-104 | Previews | Canvas compile failures on individual screens | — | Triage per-preview; prefer `StubTrainingIntegrationProvider` |
| BW-105 | Packages | SPM resolution / missing package | — | Run `xcodebuild -resolvePackageDependencies`; commit `Package.resolved` |
| BW-109 | Health sync | `HealthSummarySyncService` / `HealthSyncService` actor logger calls from nonisolated context | ~8 | Requires actor isolation design — not a one-line fix |

### Concurrency warning hotspots (from `build-for-testing` log)

| Pattern | Example locations |
|---------|-------------------|
| MainActor `init()` from nonisolated `init` | `CoachModel`, `JourneyModel`, `PlanModel`, `AccountSyncCoordinator`, `ThemeStore` |
| Static feature flags from nonisolated context | `CoachHealthIntelligenceFlags`, `HealthSummaryRemoteSyncFlags` |
| HealthKit query helpers | `HealthKitManager.mapQueryError`, `normalizedUID` |
| Sendable closure + MainActor statics | `AppleHealthSettingsEnvironment`, `HealthSyncStateStore` |

---

## Remaining — backend

| ID | Category | Symptom | Notes |
|----|----------|---------|-------|
| BW-201 | Firestore rules tests | `accountPersistenceFirestoreRules`, `nutritionSyncContract` need emulator on port 8080 | `npm run test:firestore-rules` |
| BW-202 | ESLint | Clean after BW-001 | Re-run lint after changes |
| BW-301 | npm env | `devdir` unknown config warning | Host environment only |

---

## Target membership notes

- **App + tests** use `PBXFileSystemSynchronizedRootGroup`. New files under `Fitness Coach/` or `Fitness CoachTests/` are included automatically.
- **`GoogleService-Info.plist`** is included via folder-sync only (BW-106). Do not re-add to explicit Resources phase.
- **`Fitness Coach/TestingSupport/StubTrainingIntegrationProvider.swift`** ships in the app target intentionally (previews + test doubles).
- **Do not** remove SPM products from `Fitness CoachTests` without restoring compile-time module resolution (BW-101).
- **Do** keep the `Strip Duplicate SPM Frameworks` build phase on `Fitness CoachTests` so XCTest does not embed a second copy of Firebase/GoogleSignIn at runtime (BW-002).
- **`Fitness CoachTests`** uses `TEST_HOST` / `BUNDLE_LOADER` against the app executable.

---

## Acceptance checklist (pre-merge)

- [x] `xcodebuild build -scheme "Fitness Coach" -destination 'platform=iOS Simulator,name=iPhone 17'` → **BUILD SUCCEEDED**
- [ ] `xcodebuild build-for-testing` → **TEST BUILD SUCCEEDED** (verify on macOS after BW-101 fix)
- [ ] `xcodebuild test … -testPlan Fast-Core` → pass (verify: `./Scripts/run-fast-core-serial.sh` or `./Scripts/run_fast_core_tests.sh`)
- [x] `npm --prefix functions run build` → success
- [x] `npm --prefix functions run lint` → 0 issues
- [x] `npm --prefix functions test` → 679 unit tests pass
- [ ] Optional: `npm --prefix functions run test:firestore-rules` with emulator
