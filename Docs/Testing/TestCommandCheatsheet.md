# Test Command Cheatsheet

Quick reference for focused test runs during development and pre-merge checks.

Full suite layout and test-plan details: [`Fitness CoachTests/TESTING.md`](../Fitness%20CoachTests/TESTING.md).

---

## Fast-Core (local)

**Documented / CI destination:** `platform=iOS Simulator,name=iPhone 17` (iOS 26.5).

Canonical command:

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan Fast-Core
```

Recommended for local stability (serial execution avoids XCTest harness restarts):

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
```

Wrapper script (same plan, serial, simulator fallback when iPhone 17 is missing):

```bash
./Scripts/run-fast-core-serial.sh
```

Optional `DESTINATION` override:

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core -parallel-testing-enabled NO
```

App build smoke (run before or after test changes):

```bash
xcodebuild build -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

---

## Simulator fallback

List installed simulators:

```bash
xcrun simctl list devices available
```

If `iPhone 17` is not listed, pick the nearest available iPhone from that output and substitute its name in `-destination`:

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=<Your iPhone Simulator>" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
```

Or use `./Scripts/run-fast-core-serial.sh`, which prefers iPhone 17 and falls back to the first available iPhone simulator automatically.

---

## Functions checks (local)

Package lives in `functions/`. From repo root:

```bash
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
```

Equivalent from inside the package:

```bash
cd functions && npm ci && npm run lint && npm test
```

| Script | Purpose |
|--------|---------|
| `npm run build` | `tsc` compile |
| `npm run lint` | ESLint (`.js`, `.ts`) |
| `npm test` | Jest unit suite (excludes Firestore-rules integration by default) |
| `npm run test:coach` | Coach prompt/context tests (`test/coach`) |
| `npm run test:firestore-rules` | Firestore rules integration — **requires emulator on port 8080** |
| `npm run test:all` | Full Jest suite including emulator-dependent tests |

Focused Jest runs:

```bash
npm --prefix functions run test:coach
npm --prefix functions run test:food
npm --prefix functions run test:gateway
```

---

## Troubleshooting

### SPM package resolution failures

**Symptom:** `Unable to resolve module dependency: 'FirebaseCore'` (or other Firebase/GoogleSignIn modules) when building `Fitness CoachTests`.

**Cause:** `Fitness CoachTests` must link the same seven SPM products as the app for compile-time `@testable import Fitness_Coach` resolution:

- `FirebaseAnalytics`, `FirebaseAuth`, `FirebaseCore`, `FirebaseFirestore`, `FirebaseFunctions`, `GoogleSignIn`, `SwiftHorizontalRuler`

**Checks:**

```bash
xcodebuild -resolvePackageDependencies -project "Fitness Coach.xcodeproj"
xcodebuild build-for-testing -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

See BW-101 in [`Docs/TechnicalDebt/BuildWarningsRegister.md`](../TechnicalDebt/BuildWarningsRegister.md).

### Missing simulator

**Symptom:** `Unable to find a device matching the provided destination specifier` or simulator name not found.

**Fix:** Run `xcrun simctl list devices available`, install an iOS simulator in Xcode (**Settings → Platforms**), or pass a device name that appears in the list. Prefer iPhone 17 for CI parity; any available iPhone works for local runs.

### Stale DerivedData

**Symptom:** Stale symbols (`dlopen` / missing type), inconsistent compile after package or project changes, or tests passing in Xcode but failing from CLI.

**Fix:**

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
xcodebuild -resolvePackageDependencies -project "Fitness Coach.xcodeproj"
xcodebuild clean build-for-testing -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17"
```

Then re-run Fast-Core.

### Test target membership issues

**Symptom:** New test file compiles in Xcode but is not executed, or missing from a plan.

**Checks:**

- Sources under `Fitness CoachTests/` are included via `PBXFileSystemSynchronizedRootGroup` (automatic target membership).
- Regenerate test plans after adding/removing test classes:

```bash
python3 Scripts/generate_test_plans.py
```

- Confirm the class appears in `TestPlans/Fast-Core.xctestplan` (or Integration/Full as appropriate).

### Firebase / GoogleSignIn duplicate-class crashes at runtime

**Symptom:** XCTest process restarts, `duplicate class` warnings for `GTMAppAuth` / Firebase types, or `TEST FAILED` with zero assertion failures.

**Cause:** SPM frameworks embedded in both `Fitness CoachTests.xctest/Frameworks` and the host app / `Fitness Coach.debug.dylib`.

**Fix (already in project):** `Fitness CoachTests` links SPM for compile-time resolution, and the **Strip Duplicate SPM Frameworks** build phase removes `.xctest/Frameworks` after linking. Do not remove that script or re-add embedded frameworks to the test bundle. Run serially: `-parallel-testing-enabled NO` or `./Scripts/run-fast-core-serial.sh`.

See BW-002 in [`Docs/TechnicalDebt/BuildWarningsRegister.md`](../TechnicalDebt/BuildWarningsRegister.md).

---

## CI parity

GitHub Actions workflow: [`.github/workflows/prdx-ci.yml`](../../.github/workflows/prdx-ci.yml)

Triggers on `pull_request` and `workflow_dispatch`. Jobs run in parallel:

| Job | Runner | Commands |
|-----|--------|----------|
| `functions` | `ubuntu-latest` | `npm --prefix functions ci`, `run lint`, `test` |
| `ios-fast-core` | `macos-latest` | `xcodebuild -resolvePackageDependencies`, then Fast-Core test (below) |

**iOS — Fast-Core**

```bash
xcodebuild test \
  -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  -testPlan Fast-Core \
  -parallel-testing-enabled NO
```

**Functions**

```bash
npm --prefix functions ci
npm --prefix functions run lint
npm --prefix functions test
```

Optional follow-up job (not in PRDX CI today): `npm --prefix functions run test:firestore-rules` with a Firestore emulator.

Full iOS regression (`Fitness Coach CI` scheme / `Full` test plan) remains a manual or scheduled check until wired into CI.

**GitHub Actions simulator note:** PR CI targets `iPhone 17` to match local/CI documentation. If `macos-latest` runners do not yet ship that simulator, the `ios-fast-core` job fails at destination resolution — update the workflow destination to the newest available iPhone simulator on the runner, or install the required runtime via Xcode platforms.

---

## Default plans

| Command | When to use |
|---------|-------------|
| `./Scripts/run-fast-core-serial.sh` | Everyday local dev (~3–4 min, serial, simulator fallback) |
| `xcodebuild test … -testPlan Fast-Core -parallel-testing-enabled NO` | Fast-Core with explicit destination (see [Fast-Core](#fast-core-local)) |
| `xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration` | SwiftData, cloud, auth handoff |
| `xcodebuild test -scheme "Fitness Coach CI" -destination "$DESTINATION"` | Pre-merge full regression |

Regenerate plans after adding test files:

```bash
python3 Scripts/generate_test_plans.py
```

**Simulator destination** (optional env var for commands below):

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'
```

---

## Account persistence

Sync, restore, migration, namespace, and deletion.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration \
  -only-testing:"Fitness CoachTests/AccountSyncCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountSyncPullerTests" \
  -only-testing:"Fitness CoachTests/AccountSyncUploaderTests" \
  -only-testing:"Fitness CoachTests/AccountSyncPayloadBuilderTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreEndToEndTests" \
  -only-testing:"Fitness CoachTests/AccountMigrationServiceTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionEndToEndTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionCoordinatorTests" \
  -only-testing:"Fitness CoachTests/FormaSchemaV7MigrationTests" \
  -only-testing:"Fitness CoachTests/FormaSchemaV8MigrationTests"
```

**Helpers:** `InMemorySwiftDataTestStore`, `FakeUIDProvider`, `FakeAccountSyncCoordinator`, `TestDateFixtures`, `FormaSwiftDataMigrationTestSupport`.

---

## Coach

Routing, context packet, mutations, transcript, and food logging.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/CoachRoutingTests" \
  -only-testing:"Fitness CoachTests/CoachContextPacketV2BuilderTests" \
  -only-testing:"Fitness CoachTests/CoachContextPacketV2CompactionTests" \
  -only-testing:"Fitness CoachTests/CoachMutationExecutorTimelineTests" \
  -only-testing:"Fitness CoachTests/CoachChatTranscriptPersistenceTests" \
  -only-testing:"Fitness CoachTests/CoachFoodLoggingRegressionTests" \
  -only-testing:"Fitness CoachTests/CoachMutationFormattingTests"
```

**Helpers:** `CoachFoodFixtures`, `CoachMutationTestFixtures`, `CoachContextPacketV2TestFixtures`, `FakeAnalyticsLogger.coach()`, `FakeClock`.

---

## Journey / weekly progress

Rolling-week habits, presentation builders, and HI weekly review.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/JourneyWeeklyPatternBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyPresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyLogMetricsTests" \
  -only-testing:"Fitness CoachTests/JourneyFormatterTests" \
  -only-testing:"Fitness CoachTests/WeeklyReviewPresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyTrainingSummaryBuilderTests" \
  -only-testing:"Fitness CoachTests/JourneyRevampQAChecklistTests"
```

**Helpers:** `WeeklyProgressFixtures`, `TestDateFixtures.journeyAsOf`, `JourneyLogMetrics` day-window helpers.

HI weekly review service (Integration):

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration \
  -only-testing:"Fitness CoachTests/WeeklyReviewServiceTests" \
  -only-testing:"Fitness CoachTests/WeeklyReviewEngineTests"
```

Manual QA checklist (Integration):

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration \
  -only-testing:"Fitness CoachTests/JourneyManualQAChecklistTests"
```

---

## Plan

Calculation, presentation, confidence, and projection builders.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/FormaCalculationEngineTests" \
  -only-testing:"Fitness CoachTests/PlanPresentationStateTests" \
  -only-testing:"Fitness CoachTests/PlanConfidenceStateTests" \
  -only-testing:"Fitness CoachTests/PlanProjectionBuilderTests" \
  -only-testing:"Fitness CoachTests/PlanLayoutCompositionTests" \
  -only-testing:"Fitness CoachTests/WeightLossPaceTests"
```

**Helpers:** `FormaCalculationTestFixtures`, `ProfileTestFixtures`, `FakeAnalyticsLogger.plan()`.

---

## Settings / privacy

Theme, account settings, export, and deletion UI.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/SettingsPresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/AccountSettingsPresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/SettingsPrivacyDataPresentationBuilderTests" \
  -only-testing:"Fitness CoachTests/ThemeStoreTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionViewModelTests"
```

**Helpers:** `FakeAnalyticsLogger.settings()`, `TestDateFixtures.referenceEpoch`.

---

## Shared infrastructure smoke

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/TestInfrastructureTests"
```

---

## Backend functions (focused runs)

See [Functions checks (local)](#functions-checks-local) for install, lint, and default test commands.

| Focus | Command |
|-------|---------|
| Coach prompts & context | `npm --prefix functions run test:coach` |
| Account persistence rules | `npm --prefix functions run test:firestore-rules` (emulator required) |
| Food estimation | `npm --prefix functions run test:food` |
| AI gateway guardrails | `npm --prefix functions run test:gateway` |
| Nutrition sync contract | `npm --prefix functions run test:account-persistence` |

---

## Shared test helpers (`Fitness CoachTests/TestingSupport/`)

| Helper | Purpose |
|--------|---------|
| `TestFixtureFactory` | Central factory for clocks, SwiftData harnesses, nutrition scenarios, HI harness |
| `TestDateFixtures` | Canonical fixed dates and UTC calendars |
| `ProfileFixtures` | Profile drafts, models, and cloud documents (`ProfileTestFixtures` alias) |
| `DailyLogFixtures` | Pure `DailyLog` scenarios for nutrition/review tests (`DailyNutritionSummaryTestFixtures` alias) |
| `FoodLogFixtures` | Food drafts, entries, water logs (`CoachFoodFixtures` alias) |
| `WeightFixtures` | Deterministic `WeightEntry` builders for Journey tests |
| `WeeklyProgressFixtures` | Journey rolling-week logs and habit builder inputs |
| `HealthIntelligenceFixtures` | HI calendar anchors and default plan snapshots |
| `FakeClock` | Injectable `DateProviding` + `HealthIntelligenceClockProviding` |
| `FakeUIDProvider` | Mutable session UID for sync/restore tests |
| `FakeAnalyticsLogger` | Factory for capturing analytics loggers |
| `InMemorySwiftDataTestStore` | In-memory `ModelContainer` / `SwiftDataStore` |
| `FakeAccountSyncCoordinator` | Sync mocks + coordinator harness |
| `AsyncTestSupport` | `waitUntil` / `drainMainActorTasks` / `waitUntilWallClock` |

**Conventions**

- Prefer `TestFixtureFactory` or `TestDateFixtures` over bare `Date()` in assertions.
- Use `DailyLogFixtures.NutritionScenario` for shared nutrition characterization logs.
- Use `AsyncTestSupport.waitUntil` or `waitUntilWallClock` instead of fixed `Task.sleep` when polling for async side effects.
- Use `InMemorySwiftDataTestStore` or `TestFixtureFactory.dailyLogHarness()` instead of duplicating container setup.

### Nutrition summary / review / coach mapper

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core \
  -only-testing:"Fitness CoachTests/DailyNutritionSummaryBuilderTests" \
  -only-testing:"Fitness CoachTests/DailyReviewSummaryBuilderTests" \
  -only-testing:"Fitness CoachTests/CoachNutritionSummaryTests" \
  -only-testing:"Fitness CoachTests/TestInfrastructureTests"
```

**Helpers:** `TestFixtureFactory.nutritionLog()`, `DailyLogFixtures`, `ProfileFixtures`, `FoodLogFixtures`.

---

## Code Bloat Reduction v2 smoke

Copy split equivalence, consolidated fixtures, and account persistence polling.

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -parallel-testing-enabled NO \
  -only-testing:"Fitness CoachTests/FormaProductCopyEquivalenceTests" \
  -only-testing:"Fitness CoachTests/TestInfrastructureTests" \
  -only-testing:"Fitness CoachTests/DailyNutritionSummaryBuilderTests" \
  -only-testing:"Fitness CoachTests/DailyReviewSummaryBuilderTests" \
  -only-testing:"Fitness CoachTests/CoachNutritionSummaryTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionViewModelTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionEndToEndTests" \
  -only-testing:"Fitness CoachTests/AccountDeletionCancellationTests" \
  -only-testing:"Fitness CoachTests/AccountRestoreCoordinatorTests" \
  -only-testing:"Fitness CoachTests/AccountSyncCoordinatorTests"
```

Backend coach prompt snapshots:

```bash
cd functions && npm run test:coach
```

CoachModel characterization and decomposition (post-v1):

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -parallel-testing-enabled NO \
  -only-testing:"Fitness CoachTests/CoachModelDecompositionCharacterizationTests" \
  -only-testing:"Fitness CoachTests/CoachModelStateReducerTests" \
  -only-testing:"Fitness CoachTests/CoachModelCharacterizationTests"
```

Legacy characterization-only (pre-decomposition freeze):

```bash
xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -parallel-testing-enabled NO \
  -only-testing:"Fitness CoachTests/CoachModelCharacterizationTests"
```
