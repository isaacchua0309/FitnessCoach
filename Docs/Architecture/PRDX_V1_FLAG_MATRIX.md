# PRDX v1 Flag Matrix

**Last updated:** 2026-07-05  
**Related:** [FeatureFlagRegistry.md](./FeatureFlagRegistry.md), [PHASE_20_RELEASE_READINESS.md](../HealthIntelligence/PHASE_20_RELEASE_READINESS.md)  
**Code:** `Fitness Coach/Configuration/FormaAbTest.swift`, `FormaAbTest.resolvedSnapshot(for:)`, `FormaAbTestSnapshot.production`  
**Tests:** `FormaAbTestResolvedSnapshotTests`, `FormaAbTestProductionSnapshotTests`, `FormaAbTestProductionCriticalFlagsTests`

---

## Purpose

This matrix ends the **silent** contradiction between what the app does today and what we document for App Store ship intent.

| Layer | What it means today |
|-------|---------------------|
| **Runtime (DEBUG and Release)** | `FormaAbTest.snapshot()` resolves to `FormaAbTestSnapshot.allEnabled` when `testOverride == nil`. All gates that differ in production intent are **on** at runtime. |
| **Production intent** | `FormaAbTest.resolvedSnapshot(for: .productionIntent)` → `FormaAbTestSnapshot.production`. Documented ship defaults and guarded by tests. **Not** what Release builds use today. |
| **PRDX v1 scope** | Make runtime vs intent **explicit and testable**. **Does not** flip Release behavior to production intent. |

**Important:** A Release build is **not** production-safe merely because this matrix exists. Until the runtime resolver is deliberately switched, Release behaves like `allEnabled`, not `productionIntent`.

There is **no Firebase Remote Config** in this repo.

---

## Snapshot policy

Resolved via `FormaAbTest.resolvedSnapshot(for:)` unless `FormaAbTest.testOverride` is set (live app/tests use `FormaAbTest.snapshot()`, which honors `testOverride` first).

| Environment | Resolved snapshot | Reason | Behavior change in PRDX v1? |
|-------------|-------------------|--------|----------------------------|
| **DEBUG** | `allEnabled` | Internal/dev builds keep full surface area for engineering and QA. | **No** |
| **Release** | `allEnabled` | PRDX v1 intentionally defers wiring `production` until explicit product QA sign-off. | **No** |
| **Tests** | `allEnabled` (via `.test` resolver, or live `snapshot()` with `testOverride == nil`) | Default unit/integration tests match current app runtime. Override with `FormaAbTest.testOverride` for isolated cases. | **No** |
| **productionIntent** | `production` | Documented App Store-safe defaults from PHASE_20 / registry; queried explicitly in tests and checklists. | **No** — not the default runtime path |

```swift
// Runtime (unchanged PRDX v1)
FormaAbTest.snapshot() // → allEnabled in DEBUG & Release when testOverride == nil

// Production intent (tests / checklists only)
FormaAbTest.resolvedSnapshot(for: .productionIntent) // → FormaAbTestSnapshot.production
```

---

## Flag matrix — `FormaAbTest`

Runtime column = `FormaAbTestSnapshot.allEnabled` (live app today).  
Production intent column = `FormaAbTestSnapshot.production` / `resolvedSnapshot(for: .productionIntent)`.

### Health Intelligence

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `foundationEnabled` | `true` | `true` | Health Intelligence | `FormaAbTest.HealthIntelligence`; PHASE_20 foundation **ON** |
| `enginesEnabled` | `true` | `true` | Health Intelligence | PHASE_20 engines **ON** |
| `uiEnabled` | `true` | `false` | Health Intelligence | PHASE_20 UI **OFF**; runtime shows HI sections |
| `coachContextEnabled` | `true` | `true` | Health Intelligence | Code snapshot **ON**; PHASE_20 table lists coach context **OFF** — reconcile docs before ship |
| `weeklyReviewEnabled` | `true` | `false` | Health Intelligence | PHASE_20 weekly review **OFF** |
| `syncEnabled` | `true` | `true` | Health Intelligence | PHASE_20 local sync **ON** |
| `remoteSummarySyncEnabled` | `true` | `false` | Health Intelligence | PHASE_20 remote sync **OFF** (+ user consent gate) |
| `repositoryReadRoutingEnabled` | `true` | `true` | Health Intelligence | PHASE_20 repository reads **ON** |
| `pipelineAnalyticsEnabled` | `true` | `false` | Health Intelligence | Code snapshot **OFF**; PHASE_20 table lists pipeline analytics **ON** — reconcile before ship |
| `todayDebugFetchEnabled` | `true` | `false` | Health Intelligence | Internal debug fetch; production intent off |
| `journeyDebugFetchEnabled` | `true` | `false` | Health Intelligence | Internal debug fetch; production intent off |
| `planDebugFetchEnabled` | `true` | `false` | Health Intelligence | Internal debug fetch; production intent off |

**Derived loaders (not separate flags):** `shouldTodayModelLoad`, `shouldCoachLoad`, `shouldJourneyModelLoad`, `shouldPlanModelLoad` — computed from flags above via `FormaAbTest.HealthIntelligence`.

### Coach

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `aiCommandParsingEnabled` | `true` | `true` | Coach | Shipped AI routing |
| `mealPhotoPipelineReady` | `true` | `true` | Coach | Shipped photo pipeline |
| `pipelineTraceEnabled` | `true` | `false` | Coach | Privacy — no pipeline trace in ship intent |
| `pipelineTraceVerbose` | `true` | `false` | Coach | Privacy — verbose trace off |
| `imageAnalysisDebugLog` | `true` | `false` | Coach | Privacy — image pipeline logs off |
| `foodEstimateDebugLog` | `true` | `false` | Coach | Privacy — food estimate logs off |

### Today

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `scanFoodEnabled` | `true` | `true` | Today | Food scan entry |

### Theme

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `shipsLightAndSystemAppearance` | `true` | `false` | Design system | `AppThemeShippingPolicy`; light QA gate |
| `supportsIncreasedContrastPaletteVariants` | `true` | `false` | Design system | Not implemented — no-op today |
| `supportsReduceTransparencyCompositing` | `true` | `false` | Design system | Not implemented — no-op today |

### Settings

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `dataDeletionEnabled` | `true` | `true` | Settings / privacy | `SettingsDataDeletionCapability` |
| `shipsInAppLegalWithoutPublishedURL` | `true` | `false` | Settings / privacy | Legal rows hidden without published URLs |
| `developerSectionVisible` | `true` | `false` | Settings / privacy | Developer tools hidden in ship intent |

**Export (not `FormaAbTest`):** `AccountDataExportPolicy.accountDataExportEnabled` — compile-time `false` at runtime and in ship intent. See compile-time table below.

### Auth

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `supportsAnonymousSignIn` | `true` | `false` | Auth | `AuthCapabilities` |
| `requiresSignInBeforeOnboarding` | `true` | `true` | Auth | `WelcomeOnboardingHandoffPolicy` |
| `preservesLocalUserDataOnSignOut` | `true` | `true` | Auth | Phase 1 local retention |
| `clearsCloudSyncMetadataOnSignOut` | `true` | `true` | Auth | Sign-out hygiene |

### Build

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `internalBuildEnabled` | `true` | `false` | Platform | Internal-only surfaces |
| `includesDeveloperTools` | `true` | `false` | Platform | Developer tools in build |

### Diagnostics (trace flags)

| Flag | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------|---------------|-------------------------|----------------|------------------------|
| `todayAnalyticsTrace` | `true` | `false` | Platform / diagnostics | OSLog trace gate; Release analytics sink is `NoOp*` regardless |
| `journeyAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `onboardingAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `settingsAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `themeAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `publicEntryAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `healthIntelligenceAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `weeklyProgressAnalyticsTrace` | `true` | `false` | Platform / diagnostics | |
| `healthTrainingTrace` | `true` | `false` | Platform / diagnostics | |
| `profileBootstrapTrace` | `true` | `false` | Platform / diagnostics | |
| `authSignInTrace` | `true` | `false` | Platform / diagnostics | |
| `todayHydrationTrace` | `true` | `false` | Platform / diagnostics | |
| `accountSyncTrace` | `true` | `false` | Platform / diagnostics | |
| `accountRestoreTrace` | `true` | `false` | Platform / diagnostics | |

**Analytics sink (not a flag):** `AnalyticsLoggerFactory` — DEBUG → `OSLog*`; Release → `NoOp*`. See [AnalyticsReadinessChecklist.md](./AnalyticsReadinessChecklist.md).

---

## Flag matrix — compile-time gates

These are **not** in `FormaAbTestSnapshot`. Runtime and production intent are the same constant unless code is changed and redeployed.

### `AccountPersistenceFeatureFlags`

Read-through: `FormaAbTest.AccountPersistence.*`. Owner: **Account persistence platform**.

| Flag | Runtime value | Production intent value | Source of truth / note |
|------|---------------|-------------------------|------------------------|
| `cloudSchemaEnabled` | `true` | `true` | Cloud DTOs / Firestore client |
| `syncEngineEnabled` | `true` | `true` | `AccountSyncCoordinator` |
| `uploadPendingMutationsEnabled` | `true` | `true` | Outbox upload |
| `pullRecentDataEnabled` | `false` | `false` | Bounded 90d pull — intentionally off |
| `restoreOnLoginEnabled` | `true` | `true` | Restore UX on sign-in |
| `foregroundCrossDeviceRefreshEnabled` | `true` | `true` | Foreground cross-device refresh |
| `realtimeCrossDeviceSyncEnabled` | `true` | `true` | Realtime listeners |
| `manualRefreshEnabled` | `true` | `true` | Pull-to-refresh sync |

PRDX v1: **do not change** these without account persistence regression suite (phases 1–6).

### `AccountDataExportPolicy`

| Capability | Runtime value | Production intent value | Owner / domain | Source of truth / note |
|------------|---------------|-------------------------|----------------|------------------------|
| `accountDataExportEnabled` | `false` | `false` | Settings / privacy | Export UI not shipped; `SettingsDataExportCapability` |

---

## Runtime vs production intent — flags that differ today

When `testOverride == nil`, Release uses the **Runtime** column, not production intent.

| Flag | Runtime | Production intent | User-visible impact while Release uses `allEnabled` |
|------|---------|-------------------|-----------------------------------------------------|
| `uiEnabled` | `true` | `false` | HI sections visible on Today/Journey/Plan |
| `weeklyReviewEnabled` | `true` | `false` | Weekly review card/generation enabled |
| `remoteSummarySyncEnabled` | `true` | `false` | Remote health upload allowed when consent permits |
| `pipelineAnalyticsEnabled` | `true` | `false` | HI pipeline analytics events enabled |
| `*DebugFetchEnabled` (×3) | `true` | `false` | Debug HI fetch paths on |
| Coach `*DebugLog` / `pipelineTrace*` | `true` | `false` | Debug logging/tracing enabled where gated |
| `developerSectionVisible` | `true` | `false` | Developer section visible when build flags allow |
| `internalBuildEnabled` / `includesDeveloperTools` | `true` | `false` | Internal surfaces enabled |
| `shipsLightAndSystemAppearance` | `true` | `false` | Light/system appearance available |
| `supportsAnonymousSignIn` | `true` | `false` | Anonymous auth path available |
| All `*AnalyticsTrace` / `*Trace` diagnostics | `true` | `false` | DEBUG OSLog traces on when flags true |

---

## Rules for future changes

1. **Any new `FormaAbTest` flag** must be added to:
   - `FormaAbTestSnapshot` (`allEnabled` and `production`)
   - This matrix
   - [FeatureFlagRegistry.md](./FeatureFlagRegistry.md)
   - `FormaAbTestProductionSnapshotTests.expectedFormaAbTestSnapshotPropertyCount`

2. **Any `productionIntent` value change** requires:
   - Update `FormaAbTestSnapshot.production`
   - Update this matrix and registry
   - Update `FormaAbTestProductionSnapshotTests` (and PHASE_20 tables if applicable)
   - Product/privacy review when user-facing

3. **Release must not flip** from `allEnabled` to `productionIntent` without:
   - Explicit product QA sign-off
   - Device QA matrix (PHASE_19 / PHASE_20 checklists)
   - A dedicated PR that changes `FormaAbTest.resolvedSnapshot(for:)` Release branch — **out of scope for PRDX v1**

4. **Flag deletion** requires:
   - `rg` / IDE reference search across app and tests
   - Test run (`Fast-Core` minimum)
   - Removal from this matrix and registry
   - Documented justification in PR

5. **Do not** document runtime as production-safe while Release resolves `allEnabled`. Use **production intent** language for ship checklists only.

---

## Revision history

| Date | Change |
|------|--------|
| 2026-07-05 | Initial PRDX v1 flag matrix; documents `resolvedSnapshot(for:)` policy |
