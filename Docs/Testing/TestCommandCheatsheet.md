# Test Command Cheatsheet

Quick reference for focused test runs during development and pre-merge checks.

**Simulator destination** (adjust device name as needed):

```bash
export DESTINATION='platform=iOS Simulator,name=iPhone 17'
```

> **Note:** iPhone 16 may not be installed on all machines. App builds on iPhone 17 (iOS 26.5). If `xcodebuild test` fails with `Unable to resolve module dependency: 'FirebaseCore'` in `Fitness CoachTests`, see BW-101 in [BuildWarningsRegister.md](../TechnicalDebt/BuildWarningsRegister.md).

Full suite layout and test-plan details: [`Fitness CoachTests/TESTING.md`](../Fitness%20CoachTests/TESTING.md).

---

## Default plans

| Command | When to use |
|---------|-------------|
| `xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Fast-Core` | Everyday local dev (~3–4 min) |
| `xcodebuild test -scheme "Fitness Coach" -destination "$DESTINATION" -testPlan Integration` | SwiftData, cloud, auth handoff |
| `xcodebuild test -scheme "Fitness Coach CI" -destination "$DESTINATION"` | Pre-merge full regression |

Regenerate plans after adding test files:

```bash
python3 Scripts/generate_test_plans.py
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

## Backend functions (Node / Jest)

From `functions/`:

```bash
cd functions && npm test
```

| Focus | Command |
|-------|---------|
| All unit tests | `npm test` |
| Coach prompts & context | `npm run test:coach` (or `npm test -- --testPathPatterns='test/coach'`) |
| Account persistence rules | `npm run test:firestore-rules` |
| Food estimation | `npm test -- --testPathPatterns='food'` |
| Nutrition sync contract | `npm test -- --testPathPatterns='nutritionSyncContract'` |
| AI gateway guardrails | `npm test -- --testPathPatterns='gatewayGuardrails|aiGateway'` |

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
