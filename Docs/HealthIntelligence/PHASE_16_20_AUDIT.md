# Health Intelligence — Phase 16–20 Pre-Implementation Audit

Read-only audit of the current Apple Health Intelligence implementation in Forma (Fitness Coach) before starting Phase 16–20.

**Audit date:** July 2026  
**Prior docs:** [PHASE_1_5_IMPLEMENTATION.md](./PHASE_1_5_IMPLEMENTATION.md) · [PHASE_6_10_IMPLEMENTATION.md](./PHASE_6_10_IMPLEMENTATION.md) · [PHASE_11_15_UI_INTEGRATION.md](./PHASE_11_15_UI_INTEGRATION.md)

**Scope:** Architecture, data plane, permissions, UI wiring, backend/privacy, tests, and production risks. **No code changes** in this audit.

---

## Architecture summary

Forma uses a **layered, local-first** Health Intelligence stack:

```
Apple HealthKit (device-only)
        │
        ▼
HealthKitManager + HealthSampleNormalizer
        │
        ▼
HealthDataRepository ──► LocalHealthCacheStore (disk + memory, user-scoped)
        │
        ├── HealthSyncService (background refresh, 90-day retention)
        │
        ▼
HealthIntelligenceContextBuilder
        │
        ▼
HealthIntelligenceEngine ──► HealthIntelligenceSnapshot (canonical contract)
        │
        ├── HealthIntelligenceSnapshotService (cache-first load)
        │
        ▼
Presentation Builders ──► Today / Journey / Plan UI (presentation state only)
        │
        └── CoachHealthIntelligenceContext ──► AIContext ──► AI gateway (optional, flag-gated)
```

**Design rules enforced in code:**

| Rule | Status |
|------|--------|
| Single HealthKit boundary | ✅ `Fitness Coach/Health/HealthKit/` + `Infrastructure/Health/` |
| UI never imports HealthKit | ✅ Zero `import HealthKit` under `Features/` |
| Raw HK samples never persisted | ✅ Documented in `HealthDataRepository.swift` |
| Health cache local-only | ✅ `Application Support/Forma/HealthCache/{uid}/` |
| Feature-flagged rollout | ✅ UI/coach/weekly review **off** by default; engines/sync **on** |

**Parallel legacy path:** Training Insights uses a narrower workout/steps integration (`HealthTrainingService`, `TrainingInsightsStore`) that predates full HI. Onboarding and Settings connect through this path, not `HealthPermissionService` directly.

---

## 1. Current Health Intelligence architecture

### Layer inventory

| Layer | Responsibility | Key path |
|-------|----------------|----------|
| **HealthKit I/O** | Fetch, authorize, map HK types | `Health/HealthKit/HealthKitManager.swift`, `+Fetching.swift`, `HealthKitReadTypeRegistry.swift`, `HealthKitSampleMapper.swift` |
| **Permissions** | HI signal authorization orchestration | `Health/Permissions/HealthPermissionService.swift`, `HealthPermissionCopy.swift`, `Health/Models/HealthPermissionStatus.swift` |
| **Repository** | Cache-first normalized reads | `Health/Repository/HealthDataRepository.swift`, `HealthDataAvailability.swift` |
| **Cache** | Day bundles, aggregates, snapshots, reviews | `Health/Cache/LocalHealthCacheStore.swift`, `HealthCacheStore.swift`, `HealthCachePolicy.swift`, `AuthUIDCache.swift` |
| **Sync** | Scheduled/bulk refresh | `Health/Sync/HealthSyncService.swift`, `HealthSyncStateStore.swift` |
| **Context** | Single-pass input assembly | `Health/Intelligence/HealthIntelligenceContextBuilder.swift` |
| **Engines** | Pure scoring (Phase 6–10) | `Health/Intelligence/*Engine.swift`, `HealthIntelligenceEngine.swift` |
| **Snapshot service** | Compose + cache snapshots | `Health/Intelligence/HealthIntelligenceSnapshotService.swift` |
| **Weekly review** | Cache-first review generation | `Health/Intelligence/WeeklyReviewService.swift` |
| **Feature flags** | Rollout gates | `Health/HealthIntelligenceFeatureFlags.swift` |
| **Presentation** | Snapshot → UI state | `Application/StateBuilders/{Today,Journey,Plan,Coach}/*` |
| **UI components** | SwiftUI cards/sections | `Features/{Today,Journey,Plan}/Components/HealthIntelligence/` |
| **Analytics** | Bucketed, privacy-safe events | `Features/HealthIntelligence/HealthIntelligenceAnalyticsCoordinator.swift` |
| **DI** | Wiring | `App/AppContainer.swift`, `App/MainTabView.swift` |

### Sub-engine pipeline (inside `HealthIntelligenceEngine`)

Order of composition per snapshot:

1. Training load → 2. Workout → 3. Recovery → 4. Activity → 5. Adaptive nutrition → 6. Next best action → 7. Weekly review (mode-gated) → 8. Plan confidence

Each section uses isolated fallbacks; engine failures degrade sections rather than throwing.

### Compose modes

| Mode | Use |
|------|-----|
| `.today` | Today tab, Coach, Plan snapshot load |
| `.preview` | Journey recovery timeline historical days |
| `.weeklyReview` | Weekly review generation |

---

## 2. Existing HealthKit permission flow

### Two permission stacks (critical finding)

| Stack | Entry | Scope | Used by |
|-------|-------|-------|---------|
| **Training integration** | `HealthTrainingService` → `SystemHealthKitTrainingAuthorization` | Workout read (narrow) | Onboarding, Settings → Apple Health, Training Insights, `TrainingInsightsStore` |
| **HI permission service** | `HealthPermissionService` → `HealthKitManager.requestAuthorization()` | Full HI signal set (steps, energy, exercise, workouts, RHR, HRV, sleep, body mass) | Injected into `HealthSyncService`; availability via `HealthDataRepository` |

**Onboarding and Settings do not call `HealthPermissionService.requestPermissions()` directly.** They call `TrainingInsightsStore.connectAppleHealth()`, which triggers training auth and then `healthSyncStateStore.syncInitialHealthData()`.

### Permission flow (user-visible)

```
Onboarding Apple Health step
  → OnboardingAppleHealthCoordinator.requestPermission()
  → TrainingInsightsStore.connectAppleHealth()
  → SystemHealthKitTrainingAuthorization.requestReadAuthorization()
  → HealthKitManager.requestAuthorization(toShare: [], read: readTypes)
  → On success: HealthSyncStateStore.syncInitialHealthData()
```

### Required HI read signals

From `HealthKitReadTypeRegistry`: step count, active energy, exercise time, workouts, resting heart rate, HRV (SDNN), sleep analysis, body mass. **Write types: empty set.**

### Permission copy gap

`Health/Permissions/HealthPermissionCopy.swift` header states copy is **“not wired to UI yet.”** Onboarding/Settings use `FormaProductCopy` instead. Risk of drift from Info.plist `NSHealthShareUsageDescription`.

### Surfaces where permission state appears

| Surface | What user sees |
|---------|----------------|
| **Training Insights** | `TrainingInsightsGateView` — connect / denied / open Health app |
| **Settings → Apple Health** | `AppleHealthIntegrationView` — connected/disconnected, last sync, trust copy |
| **Onboarding** | `OnboardingAppleHealthStepView` + privacy/benefit cards |
| **HI UI (when enabled)** | Lifecycle banners via `HealthIntelligencePresentationStateMapper` — connect, partial, limited estimate |
| **Today NBA** | Connect-health destination → opens Training Insights sheet |

---

## 3. HealthDataRepository / cache / sync

### HealthDataRepository

**File:** `Fitness Coach/Health/Repository/HealthDataRepository.swift`  
**Protocol:** `HealthDataRepositorying`

| Reads | Writes |
|-------|--------|
| HealthKit via `HealthKitManaging` | Local cache only (`HealthCacheStore`) |
| Cached day bundles when fresh | Normalized domain models only |

Explicit policy: **raw `HKSample` objects are fetched, normalized, and discarded — never persisted.**

### Local cache

**Primary:** `LocalHealthCacheStore` (L1 memory + L2 JSON on disk)  
**Root:** `Application Support/Forma/HealthCache/{userID}/`

| Stored artifact | Path pattern |
|-----------------|--------------|
| Daily bundle | `{uid}/days/{yyyy-MM-dd}.json` |
| Workout/sleep/heart/body mass indexes | `{uid}/workouts.json`, etc. |
| Recovery summary | `{uid}/recovery/{yyyy-MM-dd}.json` |
| Intelligence snapshot | `{uid}/snapshots/{yyyy-MM-dd}.json` |
| Weekly review | `{uid}/weekly-reviews/{yyyy-MM-dd}.json` |
| Metadata | `{uid}/metadata.json` |

**Freshness (`HealthCachePolicy`):** today 15 min; historical 24 h; retention 90 days.

### User scoping

| Mechanism | Detail |
|-----------|--------|
| Provider | `AuthUIDCache` implements `HealthCacheUserProviding` |
| UID source | Firebase auth UID via `AppContainer.syncHealthCacheUserID()` |
| Fallback | `"anonymous"` when no UID |
| Isolation | Per-user subdirectory; tested in `LocalHealthCacheStoreTests.testUserScopedDirectoriesAreIsolated` |

**Note:** Health cache uses **Firebase UID**, not SwiftData profile `ownerUID` / Today `sessionUID`. Those identifiers appear elsewhere but not in `Fitness Coach/Health/`.

### HealthSyncService

**File:** `Fitness Coach/Health/Sync/HealthSyncService.swift` (actor)

| Trigger | Days | Callers |
|---------|------|---------|
| Initial connect | 90 | Onboarding connect, `TrainingInsightsStore` |
| Today / day change | 1 | `AppContainer` refresh handler, foreground |
| App foreground | 1 | Throttled 15 min — `MainTabView` |
| Manual | N | `syncLastNDays` |

Sync gates on `repository.getHealthDataAvailability()` (not direct `permissionService` calls). Injects `HealthPermissionService` but availability drives success/failure.

**Published state:** `HealthSyncStateStore` → `@Published state` for SwiftUI (not widely surfaced in HI cards today).

---

## 4. HealthIntelligenceSnapshot composition

### Service behavior

**File:** `Fitness Coach/Health/Intelligence/HealthIntelligenceSnapshotService.swift`

```swift
// Cache-first: returns cached snapshot without freshness check
if let cached = cacheStore.intelligenceSnapshot(for: day) { return cached }
// Miss: compose via engine, store, return
```

| Method | Behavior |
|--------|----------|
| `loadTodaySnapshot` | Cache hit → return immediately; miss → `engine.composeSnapshot(mode: .today)` → store |
| `refreshTodaySnapshot` | Load + **verify/log only** — does **not** force recomposition |

### Engine

**File:** `Fitness Coach/Health/Intelligence/HealthIntelligenceEngine.swift`  
**Protocol:** `HealthIntelligenceEngineing`

- Non-throwing composition with per-section fallbacks
- Availability can short-circuit NBA to connect-health before NBA engine runs
- Weekly review included on week-end days in `.today` mode when flag enabled

### Known composition gap (Phase 16–20 priority)

**Snapshot cache has no TTL.** Day metric bundles refresh on sync with freshness policy, but composed `HealthIntelligenceSnapshot` entries are **not invalidated** when underlying health data changes. After first compose, today's snapshot can remain stale until manual cache clear or day rollover.

Journey historical timeline bypasses snapshot service and calls `engine.composeSnapshot(mode: .preview)` directly (up to 7–14 composes on cache miss).

---

## 5. UI wiring by surface

### Feature flag defaults

| Flag | Default | Effect |
|------|---------|--------|
| `FORMA_HEALTH_INTELLIGENCE_UI_ENABLED` | `false` | HI sections hidden |
| `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` | `false` | Coach AI skips HI block |
| `FORMA_HEALTH_INTELLIGENCE_WEEKLY_REVIEW_ENABLED` | `false` | No review generation |
| `FORMA_HEALTH_INTELLIGENCE_ENGINES_ENABLED` | `true` | Snapshot composition runs |
| `FORMA_HEALTH_INTELLIGENCE_SYNC_ENABLED` | `true` | Background HK sync runs |

### Today

| Item | Path |
|------|------|
| Model | `Features/Today/Model/TodayModel.swift` |
| Published state | `healthIntelligenceSectionState: TodayHealthIntelligenceSectionState?` |
| Load | Parallel with training in `loadDashboard()` |
| Inputs | Snapshot service, `healthDataRepository` availability, nutrition progress, `TodayActivityContext.trainingIntegration` |
| Builder | `TodayHealthIntelligencePresentationBuilder` |
| UI | `TodayHealthIntelligenceSection` → Recovery, Daily Mission, NBA, Workout, Adaptive Nutrition |
| Composition | `TodayReadOnlyCompositionPolicy` hides legacy NBA/activity when HI visible |
| View wiring | `TodayView` → `TodayReadOnlyView` when `HealthIntelligenceFeatureFlags.isUIEnabled` |

### Coach

| Item | Path |
|------|------|
| Model | `Features/Coach/Model/CoachModel.swift` |
| Resolver | `CoachAIActivityContextResolver` |
| Context builder | `CoachHealthIntelligenceContextBuilder` |
| AI injection | `AIContext.healthIntelligence` via `CoachAIContextBuilder` / `AIPromptBuilder` |
| Policy | `CoachCompositionPolicy` suppresses legacy workout duplication |
| UI | No dedicated HI SwiftUI section; context is prompt-only |

### Journey

| Item | Path |
|------|------|
| Model | `Features/Journey/Model/JourneyModel.swift` |
| Loader | `JourneyHealthIntelligenceSectionLoader` (snapshot, recovery days, workouts, weekly review, availability) |
| Builder | `JourneyHealthIntelligencePresentationBuilder` |
| UI | `JourneyHealthIntelligenceSection` — weekly review, timeline, workout history, milestones, progress |
| Requires | `healthActivityQuery` + `healthDataRepository`; else minimal fallback |
| Composition | `JourneyDashboardCompositionPolicy` hides legacy insights when HI visible |

### Plan

| Item | Path |
|------|------|
| Model | `Features/Plan/Model/PlanModel.swift` |
| Loader | `PlanHealthIntelligenceSectionLoader.loadSection` → `PlanHealthIntelligenceLoadResult` |
| Builder | `PlanHealthIntelligencePresentationBuilder` |
| UI | `PlanHealthIntelligenceSection` — confidence, assumptions, data quality, missing-data actions |
| Strategy/targets | **Existing** `PlanMissionControlHeroSection` + daily targets **above** HI section (unchanged) |
| Composition | `PlanDashboardCompositionPolicy` hides legacy Apple Health confidence when HI visible |

**Plan gap:** Does **not** use `HealthIntelligencePresentationStateMapper` for lifecycle banners; uses custom `PlanHealthConnectionState` and data-quality logic instead.

---

## 6. Firebase / backend health-related code

### Explicit answers

| Question | Answer | Evidence |
|----------|--------|----------|
| Normalized health summaries uploaded to Firestore? | **No** | Grep: zero health types in `*Cloud*`, `*Firestore*` stores |
| Raw HealthKit samples stored remotely? | **No** | Repository never persists HK samples; no remote health store |
| Summarized health sent to any backend? | **Conditionally yes** | `CoachHealthIntelligenceContext` embedded in `AIContext` → `FormaAIBackendClient` when `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED=1` (**default off**) |
| Firebase used in health module? | **UID scoping only** | `AuthUIDCache` — not upload |

### Cloud code (non-health)

| File | Purpose |
|------|---------|
| `Infrastructure/Cloud/FirestoreCloudUserProfileStore.swift` | User profile documents only |
| `Data/Repositories/ProfileCloudSyncStore.swift` | Profile sync |
| `Infrastructure/AI/FormaAIBackendClient.swift` | AI gateway (may include sanitized HI context) |
| `Infrastructure/AI/AIContext.swift` | `healthIntelligence: CoachHealthIntelligenceContext?` |

### What can leave device when Coach context flag is on

From `CoachHealthIntelligenceContext` (sanitized): recovery status/score (gated), steps, workout summary text, training load label, nutrition advice strings, missing signal **names**, NBA title/reason. **Explicitly excludes** raw HRV/RHR values.

---

## 7. Privacy / settings screens

| Screen | File | Health relevance |
|--------|------|------------------|
| Settings hub | `Features/Settings/SettingsRootView.swift` | Integrations → Apple Health; Privacy & Data → policy |
| Apple Health settings | `Features/Settings/UI/AppleHealthIntegrationView.swift` | Connection status, trust copy, last sync, connect/open Health |
| Presentation | `Features/Settings/Model/AppleHealthSettingsPresentationBuilder.swift` | Builds settings state from `TrainingInsightsStore` |
| Privacy policy | `Features/Settings/UI/SettingsLegalDocumentView.swift` | External policy viewer |
| HI diagnostics | `Features/Settings/UI/HealthIntelligenceDiagnosticsView.swift` | **DEBUG only** — snapshot verify, safe console log |
| Onboarding Apple Health | `Features/Onboarding/UI/OnboardingAppleHealthStepView.swift` | Permission + privacy cards |
| Coordinator | `Application/UseCases/Onboarding/OnboardingAppleHealthCoordinator.swift` | Connect + initial sync |

### Gaps

| Gap | Detail |
|-----|--------|
| `HealthPermissionCopy` unwired | Detailed per-signal copy exists but not used in production UI |
| Export/delete health data | `SettingsDeleteDataActionHandler` — health cache deletion not clearly wired (`TODO` in settings data deletion) |
| Legal URLs | `FormaLegalCopy` — TODO before App Store |
| Production diagnostics hidden | `SettingsProductionVisibility` hides HI diagnostics in release |

---

## 8. Empty states / fallback states

### Shared lifecycle mapper

**Files:** `Health/Models/HealthIntelligencePresentationLifecycle.swift`, `HealthIntelligencePresentationStateMapper.swift`

| Lifecycle | Typical UX |
|-----------|------------|
| `loading` | Skeleton/redacted cards |
| `ready` | Full HI content |
| `noHealthPermission` | Connect Apple Health CTA |
| `partialHealthPermission` | Manage permissions message |
| `noHealthDataYet` | Building data / continue logging |
| `limitedEstimate` | Limited estimate label; ask Coach |
| `syncFailed` | Safe error copy |
| `unavailableOnDevice` | Health not available |

**Used by:** Today and Journey presentation builders. **Not used by:** Plan builder.

### Per-model failure behavior

| Model | On snapshot/loader failure | Tab dashboard |
|-------|---------------------------|---------------|
| TodayModel | `fallbackHealthIntelligenceSection(snapshot: nil)` | Stays `.loaded` |
| JourneyModel | `fallbackHealthIntelligenceSection` | Stays `.loaded` |
| PlanModel | `fallbackPlanHealthIntelligenceSection` | Stays `.loaded` |
| CoachModel | Resolver → legacy activity query, `healthIntelligence: nil` | Coach usable |

**Invariant tested:** Snapshot failure must not crash or block tab root load (`HealthIntelligencePhase11SnapshotFailureIntegrationTests`).

### UI crash risk with missing health data

**Low.** HI SwiftUI views consume optional presentation state; builders return empty/unknown sections rather than force-unwrapping snapshot fields. Force unwraps appear only in `#Preview` blocks, not production paths.

---

## 9. Existing tests

### Test file inventory (~40 HI-focused files)

| Category | Files | Coverage |
|----------|-------|----------|
| **Phase 11–15 E2E** | `HealthIntelligencePhase11IntegrationTests.swift` (+ support) | 28 scenarios: flags, full/partial/no data, denied, failure, theme, refresh, weekly review cache |
| **Engines / pipeline** | `HealthIntelligenceEngineTests`, `PipelineIntegrationTests`, `ContextBuilderTests`, `ProductionHardeningTests` | Composition, degradation, partial auth |
| **Snapshot / cache** | `HealthIntelligenceSnapshotVerifierTests`, `LocalHealthCacheStoreTests` | Safe diagnostics, user isolation, pruning |
| **Feature flags** | `HealthIntelligenceFeatureFlagsTests`, `HealthIntelligenceCompositionTests` | Defaults, env keys, AppContainer wiring |
| **Lifecycle mapper** | `HealthIntelligencePresentationStateMapperTests` | All lifecycle states, shared CTAs |
| **Today** | Presentation builder, model, composition tests | Cards, sanitization, legacy hiding |
| **Journey** | Presentation builder, section loader, model, dashboard tests | Timeline, milestones, weekly review cache |
| **Plan** | Presentation builder, section loader, model, dashboard tests | Confidence, partial permissions, signals |
| **Coach** | Context builder, context tests, AI integration, composition, workout-aware | Prompt safety, awareness gating, fallback |
| **Analytics** | `HealthIntelligenceAnalyticsLoggingTests` | Bucketed properties, banned raw keys |
| **Infrastructure** | `HealthSyncServiceTests`, `HealthDataRepositoryTests`, `HealthPermissionRegistryTests` | Sync, repository, permissions |
| **Settings / onboarding** | `AppleHealthSettingsPresentationBuilderTests`, `OnboardingAppleHealthTests` | Settings and onboarding Apple Health |

**Gap:** No automated Dynamic Type snapshot suite dedicated to HI cards at `accessibility3+`. Previews use `.accessibility2` in section previews only.

---

## 10. Production risks before release

### Risk table

| ID | Risk | Severity | Current mitigation | Phase 16–20 action |
|----|------|----------|-------------------|-------------------|
| R1 | **Snapshot cache staleness** — composed snapshot not invalidated after sync | **Critical** | Day bundles refresh; snapshot does not | Add TTL or invalidate snapshots on sync complete |
| R2 | **Dual permission models** — training “connected” ≠ HI “ready” | **High** | Lifecycle mapper shows partial/limited | Unify connect flow or align training gate with HI permission service |
| R3 | **Engines/sync on, UI off** — background HK reads without visible HI | **High** | Feature flags | Document App Store privacy narrative; consider sync gate on UI or explicit consent |
| R4 | **Coach stale context** — cached snapshot drives AI until awareness suppressed | **High** | Awareness gate; flag default off | Force refresh on Coach open; snapshot invalidation (R1) |
| R5 | **HI connect CTA → Training Insights** — not full permission management | **Medium** | Training gate handles workout auth | Route partial-permission CTAs to signal-specific guidance |
| R6 | **Legacy `workoutCaloriesBurned` on DailyLog** — `max()` merge inflates calories | **Medium** | HI uses snapshot separately | Migration or ignore legacy field when HK connected |
| R7 | **Plan lifecycle divergence** — no shared mapper | **Medium** | Custom connection states | Align Plan with `HealthIntelligencePresentationStateMapper` |
| R8 | **`HealthPermissionCopy` unwired** | **Medium** | FormaProductCopy used elsewhere | Wire copy or consolidate |
| R9 | **Health data not in account deletion flow** | **Medium** | Local cache only | Wire cache wipe into Settings delete/sign-out |
| R10 | **`syncPhase` rarely passed to presentation context** | **Low** | Explicit error paths exist | Surface sync state in models for `syncFailed` lifecycle |
| R11 | **Journey timeline compose cost** | **Low** | Cache for recovery/snapshots | Warm cache; batch preview composes |
| R12 | **Dynamic Type at extreme sizes** | **Low** | `healthIntelligenceMultilineText()`, previews | Device QA + optional snapshot tests |
| R13 | **Legacy + HI duplicate sections** | **Low** | Composition policies | Remove legacy after rollout (Phase 11–15 doc) |
| R14 | **XCTest harness stability** | **Medium** | Documented in TESTING.md | Verify Full plan green on Mac before release |

---

## Specific audit questions — answers

| Question | Answer |
|----------|--------|
| **Normalized health summaries uploaded anywhere?** | **Firestore: No.** **AI gateway: Yes, conditionally** — sanitized `CoachHealthIntelligenceContext` when coach context flag enabled (default **off**). |
| **Raw HealthKit samples stored remotely?** | **No.** |
| **HealthKit data cached locally only?** | **Yes** — `LocalHealthCacheStore` on device. |
| **User ID scoping for cache?** | **Yes** — Firebase UID via `AuthUIDCache`; `"anonymous"` fallback; per-user directory. |
| **Apple Health permission states clearly surfaced?** | **Partially** — Training Insights + Settings show connection; HI lifecycle banners when UI enabled; **no unified per-signal settings UI** using `HealthPermissionCopy`. |
| **Partial permission states handled?** | **Yes** in engines/mapper/UI — `partialHealthPermission`, `limitedEstimate`, Plan partial CTAs; **confusing** when training shows “connected” but HI shows partial. |
| **UI crash if health data missing?** | **No** — fallbacks and optional state; tested in integration suite. |
| **Coach stale or missing health context?** | **Yes, possible** — cache-first snapshot; missing → silent legacy fallback; awareness can suppress context while snapshot loads. |
| **HealthKit reads from UI?** | **No** — Features layer uses abstractions only. |
| **Manual workout fields conflict with Apple Health?** | **Yes, potential** — `DailyLog.workoutCaloriesBurned` merged via `max()` with HK calories; journey metrics count legacy field as workout day; HI workout card uses snapshot not DailyLog. |

---

## File inventory

### Health module (`Fitness Coach/Health/` — ~78 files)

```
Health/
├── HealthKit/           HealthKitManager, fetching, registry, mapper
├── Permissions/         HealthPermissionService, copy, logger
├── Repository/          HealthDataRepository, availability
├── Cache/               LocalHealthCacheStore, policy, records, AuthUIDCache
├── Sync/                HealthSyncService, state store
├── Intelligence/        Engine, context builder, snapshot service, sub-engines, weekly review
├── Models/              Snapshot, summaries, lifecycle mapper, permission status
└── HealthIntelligenceFeatureFlags.swift
```

### Infrastructure health (`Fitness Coach/Infrastructure/Health/` — ~15 files)

Training integration: `HealthTrainingService`, `SystemHealthKitWorkoutReader`, `HealthTrainingDebugLogger`, etc.

### Presentation + UI (~35 files)

```
Application/StateBuilders/
├── Today/TodayHealthIntelligencePresentationBuilder.swift
├── Journey/JourneyHealthIntelligencePresentationBuilder.swift
├── Journey/JourneyHealthIntelligenceSectionLoader.swift
├── Plan/PlanHealthIntelligencePresentationBuilder.swift
├── Plan/PlanHealthIntelligenceSectionLoader.swift
└── Coach/CoachHealthIntelligenceContextBuilder.swift, CoachAIActivityContextResolver.swift

Features/
├── Today/Components/HealthIntelligence/     (7 components)
├── Journey/Components/HealthIntelligence/   (8 components)
├── Plan/Components/HealthIntelligence/      (6 components)
├── Journey/Components/WeeklyReview/         (5 components)
└── HealthIntelligence/HealthIntelligenceAnalyticsCoordinator.swift

Features/{Today,Journey,Plan}/Model/         Presentation state structs
Features/Coach/Model/CoachHealthIntelligenceContext.swift
```

### Settings / onboarding (~15 files)

`AppleHealthIntegrationView`, `OnboardingAppleHealthStepView`, coordinators, presentation builders.

### Tests (~40 files)

See Section 9.

### Documentation

| Doc | Status |
|-----|--------|
| `PHASE_1_5_*` | Data plane |
| `PHASE_6_10_*` | Engines |
| `PHASE_11_15_UI_INTEGRATION.md` | UI integration |
| **`PHASE_16_20_AUDIT.md`** | This audit (pre-implementation) |

---

## Recommended implementation order for Phase 16–20

Proposed phasing based on audit findings (titles are recommendations — not yet implemented):

### Phase 16 — Data freshness & cache coherence (addresses R1, R4)

1. Snapshot invalidation policy — invalidate or TTL `intelligenceSnapshot` when sync completes or day bundles refresh
2. `refreshTodaySnapshot` — optional force-recompose API for pull-to-refresh and Coach open
3. Wire invalidation from `HealthSyncService` success path
4. Tests: stale workout mid-day, sync-then-refresh snapshot content changes

### Phase 17 — Permission UX unification (addresses R2, R5, R8)

1. Single user-facing permission story — align Training Insights connect with `HealthPermissionService` signal set
2. Wire `HealthPermissionCopy` (or merge into `FormaProductCopy`) for onboarding, Settings, HI CTAs
3. Partial-permission destination — signal-level guidance instead of only Training Insights gate
4. Surface `HealthDataAvailability` per-signal status in Settings → Apple Health
5. Tests: connect workouts-only → partial lifecycle; full connect → ready

### Phase 18 — Privacy, data lifecycle & account hygiene (addresses R3, R9)

1. Health cache wipe on sign-out / account deletion
2. Settings copy audit vs Info.plist usage description
3. Optional: user-visible “health data stored on device” disclosure
4. Review sync-enabled-by-default against App Store privacy questionnaire
5. Tests: UID change clears cache; delete account removes `HealthCache/{uid}/`

### Phase 19 — Production rollout & legacy cleanup (addresses R6, R13, R7)

1. Legacy section removal (Today NBA/activity, Plan confidence) after flag-on bake period
2. Legacy `workoutCaloriesBurned` policy — zero or ignore when HK connected
3. Align Plan presentation with shared lifecycle mapper
4. Pass `syncPhase` from `HealthSyncStateStore` into presentation context
5. Remote config for HI flags (replace env-only toggles)

### Phase 20 — Coach hardening & observability (addresses R4, R11, R12)

1. Coach snapshot refresh on thread open / message send when stale
2. Pass `trainingLoad` into `CoachHealthIntelligenceContextBuilder` (currently defaults `.unknown`)
3. Production-safe sync status indicator (optional, non-technical)
4. Dynamic Type QA pass + optional snapshot tests for HI cards
5. Journey timeline cache warming to reduce preview compose burst

---

## Files likely needing changes (Phase 16–20)

| Area | Files |
|------|-------|
| **Snapshot freshness** | `HealthIntelligenceSnapshotService.swift`, `LocalHealthCacheStore.swift`, `HealthCachePolicy.swift`, `HealthSyncService.swift` |
| **Permissions** | `HealthPermissionService.swift`, `HealthPermissionCopy.swift`, `OnboardingAppleHealthCoordinator.swift`, `AppleHealthIntegrationView.swift`, `TrainingInsightsStore.swift`, `TodayActionCoordinator.swift` |
| **Privacy / deletion** | `LocalHealthCacheStore.swift`, `SettingsDeleteDataActionHandler.swift`, `AuthManager` sign-out path, `AppContainer.syncHealthCacheUserID()` |
| **Presentation** | `HealthIntelligencePresentationStateMapper.swift`, `PlanHealthIntelligencePresentationBuilder.swift`, `{Today,Journey,Plan}Model.swift` |
| **Coach** | `CoachAIActivityContextResolver.swift`, `CoachModel.swift`, `CoachHealthIntelligenceContextBuilder.swift` |
| **Legacy workout** | `TodayModel.swift`, `DailyReviewSummaryBuilder.swift`, `JourneyLogMetrics.swift`, migration if needed |
| **Flags / rollout** | `HealthIntelligenceFeatureFlags.swift`, remote config module (new) |
| **Tests** | New freshness/permission/deletion integration tests; extend Phase 11 harness |
| **Docs** | `PHASE_16_20_IMPLEMENTATION.md` (future), update `PHASE_11_15_UI_INTEGRATION.md` after legacy removal |

---

## Appendix: Quick reference — who reads what

| Consumer | Reads from | HealthKit direct? |
|----------|-----------|-------------------|
| TodayModel | Snapshot service + repository availability | No |
| JourneyModel | Section loader → snapshot, engine, cache, weekly review | No |
| PlanModel | Section loader → snapshot, baseline, availability | No |
| CoachModel | Snapshot service → context builder | No |
| HealthActivityQueryService | Repository (when flag on) or legacy readers | No (via repo) |
| HealthSyncService | Repository | No |
| TrainingInsightsStore | HealthTrainingService | Yes (narrow) |
| SwiftUI HI components | Presentation state only | No |

---

*This audit is read-only. No production code was modified. Use alongside [PHASE_11_15_UI_INTEGRATION.md](./PHASE_11_15_UI_INTEGRATION.md) rollout checklist before enabling flags in production.*
