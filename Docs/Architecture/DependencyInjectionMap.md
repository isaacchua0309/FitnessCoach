# Dependency Injection Map

**Last updated:** 2026-07-05  
**Related:** [AppArchitectureOverview.md](./AppArchitectureOverview.md), `Fitness Coach/App/AppContainer.swift`, `AppContainer+Construction.swift`, `AppContainer+FeatureFactories.swift`

---

## 1. DI Strategy

The app uses **manual constructor injection** via a single composition root:

| Pattern | Usage |
|---------|--------|
| `AppContainer` | Constructs all services, coordinators, engines; exposes `let` dependencies and `make*Model()` factories |
| Protocol-oriented analytics | `*AnalyticsLogging` protocols; DEBUG → `OSLog*`, Release → `NoOp*` |
| Test overrides | `AppContainer(inMemory:)`, injectable loggers, `accountDataRemoteStore`, `onboardingUserDefaults` |
| `FormaAbTest.testOverride` | Unit test flag injection |
| No global service locator | Except `UserDefaults.standard` in a few places (`MainTabView`, migration gate) |

**Construction layout:** Domain-grouped private bundles and `build*Dependencies()` factories live in `AppContainer+Construction.swift` (init-time services plus Journey/Plan model wiring). Feature `make*Model()` factories are thin delegates grouped by tab in `AppContainer+FeatureFactories.swift`. Public `AppContainer` properties and init parameters are unchanged.

---

## 2. AppContainer Construction Order

`AppContainer.init` runs on `@MainActor` and delegates to private `build*Dependencies()` factories. Order matters for dependencies that reference `authManager` weakly or need `store` first.

| Factory | Domain bundle | File |
|---------|---------------|------|
| `buildAuthDependencies` | Auth, onboarding prefs, refresh bus | `Fitness Coach/App/Dependencies/AuthDependencies.swift` |
| `buildAnalyticsDependencies` | Analytics loggers via `AnalyticsDependencies` | `Fitness Coach/App/Dependencies/AnalyticsDependencies.swift` |
| `buildHealth` | HealthKit, sync, training insights (shared) | `Fitness Coach/App/Dependencies/HealthDependencies.swift` |
| `buildPersistenceDependencies` | SwiftData, account sync core, log services | `AppContainer+Construction.swift` |
| `buildHealthIntelligenceDependencies` | HI engine, snapshot, weekly review | `AppContainer+Construction.swift` |
| `buildCoachDependencies` | Coach timeline stores, backfill | `Fitness Coach/App/Dependencies/CoachPlatformDependencies.swift` |
| `buildAI` | LLM client, AIService | `AppContainer+Construction.swift` |
| `buildSyncDependencies` | Restore, cross-device, deletion, export | `Fitness Coach/App/Dependencies/SyncDependencies.swift` |
| `buildSettingsDependencies` | Theme store | `AppContainer+Construction.swift` |
| `buildTodayDependencies` | ReviewService, FitnessActionCenter | `AppContainer+Construction.swift` |
| `buildJourneyDependencies` | JourneyModel wiring (feature factory) | `AppContainer+Construction.swift` |
| `buildPlanDependencies` | PlanModel wiring (feature factory) | `AppContainer+Construction.swift` |

### Init call sequence

```
buildAuthDependencies
  → buildAnalyticsDependencies
  → buildHealth
  → buildPersistenceDependencies
  → buildHealthIntelligenceDependencies
  → buildCoachDependencies
  → buildAI
  → buildSyncDependencies
  → buildSettingsDependencies
  → buildTodayDependencies
```

`makeJourneyModel()` and `makePlanModel()` delegate to `buildJourneyDependencies()` / `buildPlanDependencies()` in `AppContainer+Construction.swift`. Other feature factories remain in `AppContainer+FeatureFactories.swift`.

### Phase A — Session and preferences

| Step | Constructed | Notes |
|------|-------------|-------|
| A1 | `AppRefreshCenter`, `AccountRestoreSessionState` | Refresh bus |
| A2 | `AuthManager`, `AuthUIDCache` | UID cache updated from auth |
| A3 | `onboardingUserDefaults` | Suite or standard; tests can inject |
| A4 | `OnboardingDraftStore`, `PublicEntrySessionStore`, `OnboardingCoachingContextStore` | UserDefaults-backed |
| A5 | Analytics loggers | `#if DEBUG` → OSLog; `#else` → NoOp |
| A6 | `ThemeStore` | Theme analytics injected |

### Phase B — Health / training (before SwiftData)

| Step | Constructed | Notes |
|------|-------------|-------|
| B1 | `HealthTrainingService` | Apple Health integration |
| B2 | `HealthKitManager` (shared) | Single instance |
| B3 | `healthKitWorkoutReader`, `healthKitStepReader` | Via `HealthTrainingReaderFactory` |
| B4 | `LocalHealthCacheStore` | UID from `authUIDCache` |
| B5 | `HealthDataRepository` | HealthKit + cache |
| B6 | `healthBaselineService`, engines (`TrainingLoad`, `Workout`, `Recovery`, etc.) | Pure engines |
| B7 | `healthActivityQueryService` | Today/Coach/reviews workout counts |
| B8 | `healthSyncService`, consent stores, `healthSummarySyncService` | Flag-gated remote sync |
| B9 | `healthSyncStateStore`, `trainingInsightsStore`, `trainingInsightsModel` | Tab environment |

### Phase C — SwiftData and account sync core

| Step | Constructed | Notes |
|------|-------------|-------|
| C1 | `FormaModelContainer` / `SwiftDataStore` | `inMemory` for tests |
| C2 | `SwiftDataAccountSyncOutboxStore` | Outbox |
| C3 | `AccountLocalMutationTracker` | Enqueues on mutation; `ownerUID` from auth |
| C4 | `UserProfileService`, `cloudUserProfileStore` | NoOp cloud when `inMemory` |
| C5 | `accountDataRemoteStore` | InMemory / Firestore / test inject |
| C6 | `AccountSyncUploader`, `AccountSyncPuller`, `AccountSyncCoordinator` | Sync orchestration |
| C7 | `ProfileCloudSyncStore`, `dailyLogService`, `profileBootstrapService` | Profile path |
| C8 | `foodLogService`, `waterLogService`, `weightLogService` | All use `mutationTracker` |
| C9 | `targetService` | Plan targets |

### Phase D — Health Intelligence composition

| Step | Constructed | Notes |
|------|-------------|-------|
| D1 | `HealthIntelligenceContextBuilder` | Nutrition/weight/plan providers |
| D2 | `HealthIntelligenceEngine` | Sub-engines injected |
| D3 | `HealthIntelligenceSnapshotService` | Actor; cache + coalescing |
| D4 | `WeeklyReviewService` | Flag-gated weekly review |

### Phase E — Coach persistence

| Step | Constructed | Notes |
|------|-------------|-------|
| E1 | `SwiftDataCoachTimelineStore`, `SwiftDataCoachChatTranscriptStore` | `userIdProvider` from auth |
| E2 | `CoachTimelineBackfillService`, `DefaultCoachTimelineRecorder` | Async backfill `Task` |

### Phase F — AI

| Step | Constructed | Notes |
|------|-------------|-------|
| F1 | `llmClient` | `inMemory` → Mock; else `FormaAIBackendClient` + auth token |
| F2 | `AIService` | Wraps LLM |
| F3 | `ReviewService` | Daily review generation |

### Phase G — Restore / cross-device / deletion

| Step | Constructed | Notes |
|------|-------------|-------|
| G1 | `AccountRestoreStateStore`, inspectors, `AccountSyncCursorStore` | |
| G2 | `AccountIncrementalPuller`, `AccountDataRefreshEventBus` | |
| G3 | `CrossDeviceSyncCoordinator` | Foreground + manual refresh |
| G4 | `accountRealtimeChangeListener` | Firestore or NoOp |
| G5 | `AccountDataNamespaceService`, `AccountMigrationService` | UID hardening / switch |
| G6 | `AccountInitialRestoreService`, `AccountRestoreCoordinator` | Phase 4 |
| G7 | `AccountDeletionRemoteClient`, `LocalAccountDataWipeService` | Phase 6 |
| G8 | `AccountDeletionCoordinator` | Full delete orchestration |
| G9 | `AccountDataExportService` | Export foundation (policy off) |

### Phase H — Action center

| Step | Constructed | Notes |
|------|-------------|-------|
| H1 | `FitnessActionCenter` | All log services, profile, review, sync tracker, timeline recorder |

---

## 3. Factory Methods (feature models)

Grouped in `AppContainer+FeatureFactories.swift`:

| Section | Factory | Returns |
|---------|---------|---------|
| Health Intelligence | `makeHealthIntelligenceEngine()`, `refreshHealthIntelligenceSnapshotIfNeeded()`, `makeHealthIntelligenceAnalyticsCoordinator()` | HI engine / refresh / analytics |
| Today | `makeTodayModel()`, `makeTodayActionCoordinator()` | `TodayModel`, `TodayActionCoordinator` |
| Coach | `makeCoachServices()`, `makeCoachDependencies()`, `makeCoachModel()` | `CoachModel` |
| Journey | `makeJourneyModel()`, `makeJourneyAnalyticsCoordinator()` | `JourneyModel`, analytics |
| Plan | `makePlanModel()`, `makePlanAnalyticsCoordinator()`, `makeWeeklyProgressAnalyticsCoordinator()` | `PlanModel`, analytics |
| Settings | `makeSettingsPrivacyDataEnvironment()`, `makeSettingsAnalyticsCoordinator()` | Settings env / analytics |
| App shell | `makeRootModel()`, `makeOnboardingModel(onCompletion:)`, `resolveAppShellRoute(...)` | Shell / onboarding |

### Key injections (unchanged)

- **Today:** log readers, HI snapshot, restore session, cross-device sync, analytics
- **Coach:** `CoachServices` + `CoachDependencies` assembly; `actionCenter`, `aiService`, transcript store, timeline recorder, context builder — see §3.1
- **Journey:** log readers, HI section loader inputs, weekly review service, training store
- **Plan:** profile, target service, HI, training, weekly progress analytics
- **Onboarding:** draft store, plan generation, auth, health training integration

---

## 4. Coordinator vs Service vs Repository

| Type | Responsibility | Examples | Constructed in |
|------|----------------|----------|----------------|
| **Repository** | Entity CRUD, queries, UID predicates, outbox enqueue | `FoodLogService`, `DailyLogService`, `UserProfileService`, `WeightLogService` | `AppContainer` |
| **Store (infra)** | Low-level SwiftData / Firestore adapter | `SwiftDataStore`, `FirestoreAccountDataRemoteStore` | `AppContainer` / Infrastructure |
| **Service** | Domain operation spanning repos or AI | `TargetService`, `AIService`, `ReviewService`, `ProfileBootstrapService` | `AppContainer` |
| **Use case** | Canonical mutation API | `FitnessActionCenter` | `AppContainer` |
| **Coordinator** | Multi-step lifecycle, ordering, progress, flags | `AccountSyncCoordinator`, `AccountRestoreCoordinator`, `AccountDeletionCoordinator`, `CrossDeviceSyncCoordinator`, `AuthGateCoordinator`, `CoachSendFlowCoordinator`, `CoachPhotoFlowCoordinator`, `CoachPendingConfirmationCoordinator`, `CoachMessagePersistenceCoordinator` | `AppContainer` / Auth feature / `CoachModel` wiring |
| **State builder** | Pure(ish) dashboard assembly | `TodayPresentationBuilder`, `JourneyDashboardBuilder` | Stateless; called from models |
| **Presenter / handler** | UI-adjacent formatting | `CoachPendingConfirmationPresenter` | Application/UseCases/Coach |

### Call chain examples

**Log food (Coach):**
```
CoachView → CoachModel → CoachSendFlowCoordinator
  → CoachRouteDecider / CoachAIRouteHandler
  → CoachPendingConfirmationCoordinator (if pending)
  → CoachMutationExecutor → FitnessActionCenter → FoodLogService
  → SwiftDataStore + AccountLocalMutationTracker → (debounced) AccountSyncCoordinator
```

### 3.1 Coach feature DI (`AppContainer+FeatureFactories.swift`)

| Factory | Returns | Constructs |
|---------|---------|------------|
| `makeCoachServices()` | `CoachServices` | `actionCenter`, log readers, health/HI providers, profile reader, training store |
| `makeCoachDependencies(healthIntelligenceAnalyticsCoordinator:)` | `CoachDependencies` | `CoachContextPacketV2Builder`, `aiService`, transcript/timeline stores, correction memory, analytics |
| `makeCoachModel(...)` | `CoachModel` | `CoachModel(services:dependencies:)` → `CoachDependencies.assemble` |

**Assembly (`CoachDependencies.assemble`):** builds `CoachMutationExecutor`, `CoachAIRouteHandler`, `CoachRouteDecider`, `CoachMealPhotoAnalyzer`, and feature coordinators. Any `CoachDependencies` field can be overridden in tests.

**Test pattern:** `CoachRoutingIntegrationTestSupport.makeCoach(services:dependencies:)` or legacy `CoachModel(...)` convenience init.

**Legacy log food chain (unchanged semantics):**
```
CoachModel → CoachMutationExecutor → FitnessActionCenter → FoodLogService
```

**Sign-in restore:**
```
AuthGateCoordinator → AccountRestoreCoordinator → AccountInitialRestoreService
  → AccountSyncPuller → SwiftData → AppRefreshCenter
```

**Read Today dashboard:**
```
TodayModel.load → FoodLogService / DailyLogService (protocols) → TodayPresentationBuilder
```

---

## 5. Dependency Table (major types)

| Dependency | Constructed where | Used by | Testable? | Mock / fake |
|------------|-------------------|---------|-----------|-------------|
| `SwiftDataStore` | `AppContainer` | All `*LogService` | Yes (`inMemory`) | In-memory container |
| `AuthManager` | `AppContainer` | Auth gate, sync UID | Partial | Test auth helpers |
| `FitnessActionCenter` | `AppContainer` | Coach, Today, onboarding | Yes | Test support |
| `AccountSyncCoordinator` | `AppContainer` | Lifecycle, restore, deletion | Yes | `AccountSyncCoordinatorTests` |
| `Firestore.firestore()` | Lazy in cloud stores | Profile, account data | Inject `accountDataRemoteStore` | `InMemoryAccountDataRemoteStore` |
| `LLMClient` | `AppContainer` | `AIService` | Yes | `MockLLMClient` |
| `HealthDataRepository` | `AppContainer` | HI engines, sync | Yes | Mock readers in tests |
| `ThemeStore` | `AppContainer` | Root theme modifier | Yes | `ThemeStoreTests` |
| `*AnalyticsLogging` | `AppContainer` | Feature models | Yes | `CapturingAnalyticsLoggers` |
| `NoOpCloudUserProfileStore` | When `inMemory` | Profile bootstrap tests | Yes | Built-in |
| `NoOpAccountRealtimeChangeListener` | When `inMemory` | Cross-device tests | Yes | Built-in |

---

## 6. Direct Singleton / Global Usage (audit)

| Location | API | Risk | Recommendation |
|----------|-----|------|----------------|
| `MainTabView` | `UserDefaults.standard` (tab persistence) | Medium | Inject tab store |
| `FormaSwiftDataMigrationGate` | `UserDefaults.standard` | Low | Document |
| `UIApplication.shared` | Settings / Health URLs | Low | Expected |
| `Firestore.firestore()` | Lazy in cloud clients | Medium | Factory injection (P1) |

**No app-owned singleton service locator** for domain logic (**Confirmed**).

---

## 7. Preview and Test Wiring

| Context | Pattern |
|---------|---------|
| SwiftUI `#Preview` | Often `AppContainer(inMemory: true)` or stub providers (`StubTrainingIntegrationProvider`) |
| Unit tests | `AppContainer(inMemory: true, …)` + capturing loggers |
| Integration tests | Full container; `InMemoryAccountDataRemoteStore` or mocks via init param |
| Flag tests | `FormaAbTest.testOverride`, `HealthIntelligenceFeatureFlags.testOverride` |

---

## 8. Backend DI (Functions)

| Module | Role |
|--------|------|
| `functions/src/index.ts` | HTTP entry, route dispatch |
| `openAIAPIKey` | Firebase secret |
| `accountDeletion/*` | Separate handler + service |

No shared DI container — module-level imports.

---

## 9. Revision History

| Date | Change |
|------|--------|
| 2026-07-05 | Coach DI: `makeCoachServices`, `makeCoachDependencies`, `CoachDependencies.assemble`; coordinator call chain |
| 2026-07-05 | Renamed construction factories to `build*Dependencies()`; grouped feature factories by tab |
| 2026-07-04 | Initial DI map for PRDX v1 |
