# Build Warnings Register

Tracked compile warnings, test-infra issues, and backend lint items. Update this file when warnings are fixed or newly discovered.

**Last reviewed:** 2026-07-04

---

## Capture commands

### iOS (requires Xcode on macOS)

```bash
./Scripts/capture_build_warnings.sh 'platform=iOS Simulator,name=iPhone 16'
```

Or manually:

```bash
xcodebuild build -scheme "Fitness Coach" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  2>&1 | tee /tmp/xcodebuild.log
```

### Backend

```bash
npm --prefix functions run build
npm --prefix functions run lint
npm --prefix functions test
npm --prefix functions run test:firestore-rules   # requires Firestore emulator
```

---

## Fixed in this pass

| ID | Area | Issue | Resolution |
|----|------|-------|------------|
| BW-001 | `functions` ESLint | Unused `field` params in `coachContextPacketV2.ts` validators | Renamed to `_field` (error copy intentionally generic) |
| BW-002 | `Fitness CoachTests` target | Duplicate Firebase/GoogleSignIn SPM products linked in test bundle **and** app `debug.dylib` | Removed SPM framework deps from test target; tests resolve Firebase via `@testable import Fitness_Coach` + app dylib |
| BW-003 | `functions` Jest | `npm test` failed without Firestore emulator (31 tests) | Default `npm test` runs unit suite; `test:all` + `test:firestore-rules` for rules integration |

---

## Remaining — iOS (needs local Xcode capture)

Cloud agents do not have `xcodebuild`. Run `./Scripts/capture_build_warnings.sh` on macOS and paste new rows below.

| ID | Category | Symptom | Notes / safe fix path |
|----|----------|---------|------------------------|
| BW-101 | Test runtime | XCTest crash restarts; duplicate ObjC classes (`GTMAppAuth`, Firebase) | BW-002 should reduce; verify with serial `xcodebuild test -parallel-testing-enabled NO` |
| BW-102 | Concurrency | `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` project-wide | Audit per-file `@MainActor` / `nonisolated` only when compiler flags a site; do not blanket-suppress |
| BW-103 | Deprecation | `@available(*, deprecated)` `AIContext` retained for Codable/mocks | Remove when migration entities and test mocks no longer reference it |
| BW-104 | Previews | Canvas compile failures on individual screens | Triage per-preview; prefer `StubTrainingIntegrationProvider` and preview-only hosts |
| BW-105 | Packages | SPM resolution / missing package | Run `xcodebuild -resolvePackageDependencies`; commit `Package.resolved` |

---

## Remaining — backend

| ID | Category | Symptom | Notes |
|----|----------|---------|-------|
| BW-201 | Firestore rules tests | `accountPersistenceFirestoreRules`, `nutritionSyncContract` need emulator on port 8080 | Use `npm run test:firestore-rules`; not part of default `npm test` |
| BW-202 | ESLint | Clean after BW-001 | Re-run `npm --prefix functions run lint` after changes |

---

## Target membership notes

- **App + tests** use `PBXFileSystemSynchronizedRootGroup` (folder-synced). New files under `Fitness Coach/` or `Fitness CoachTests/` are included automatically.
- **`Fitness Coach/TestingSupport/StubTrainingIntegrationProvider.swift`** ships in the app target intentionally (previews + test doubles).
- **Do not** add Firebase/GoogleSignIn SPM products back to `Fitness CoachTests` unless a test file gains a direct `import Firebase*` (none today).

---

## Acceptance checklist (pre-merge)

- [ ] `xcodebuild build -scheme "Fitness Coach" -destination 'platform=iOS Simulator,name=iPhone 16'` → **BUILD SUCCEEDED**
- [ ] `npm --prefix functions run build` → success
- [ ] `npm --prefix functions run lint` → 0 warnings
- [ ] `npm --prefix functions test` → 572+ unit tests pass
- [ ] Optional: `npm --prefix functions run test:firestore-rules` with emulator
