# Feature Flag Registry

**Last updated:** 2026-07-05  
**Sources of truth:** `Fitness Coach/Configuration/FormaAbTest.swift`, `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`, `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`

**PRDX v1 matrix (runtime vs production intent):** [PRDX_V1_FLAG_MATRIX.md](./PRDX_V1_FLAG_MATRIX.md)

**Tests:** `FormaAbTestResolvedSnapshotTests`, `FormaAbTestProductionSnapshotTests`, `FormaAbTestProductionCriticalFlagsTests`, `AppContainerAccountDataRemoteStoreWiringTests`, `HealthIntelligenceFeatureFlagsTests`, `SettingsPrivacyDataTests`

---

## 1. Overview

| Registry | Type | Runtime resolver |
|----------|------|------------------|
| `FormaAbTest` | `FormaAbTestSnapshot` | `testOverride ?? resolvedSnapshot(for: .debug \| .release)` → `allEnabled` in PRDX v1 |
| `AccountPersistenceFeatureFlags` | `static let` constants | Compile-time |
| `HealthIntelligenceFeatureFlags` | Facade over `FormaAbTest` | `AbTestHealthIntelligenceFeatureFlags` |

See [PRDX_V1_FLAG_MATRIX.md](./PRDX_V1_FLAG_MATRIX.md) for the full runtime vs production-intent table.

**There is no Firebase Remote Config** in this repo.

### Runtime vs production intent

| Snapshot | Purpose | Used at runtime today? |
|----------|---------|------------------------|
| `FormaAbTestSnapshot.allEnabled` | Internal/dev — all gates on | **Yes** — default for app and most tests |
| `FormaAbTestSnapshot.production` | App Store safe defaults | **No** — documented ship intent + production-critical tests only |

**Known contradiction (documented, not silent):** `allEnabled` sets HI UI, weekly review, remote sync, and debug traces to `true`, while `production` sets several to `false`. Runtime behavior remains `allEnabled` until an explicit release pass wires `production`. Full diff: [PRDX_V1_FLAG_MATRIX.md](./PRDX_V1_FLAG_MATRIX.md#runtime-vs-production-intent--flags-that-differ-today).

### Column legend

| Column | Meaning |
|--------|---------|
| **Owner** | Team/domain responsible |
| **Runtime default** | Value when `testOverride == nil` (`allEnabled`) |
| **Production default** | Value in `FormaAbTestSnapshot.production` or compile-time constant |
| **Rollout** | `shipped` / `internal` / `off` / `compile-time` |
| **Removable?** | Safe to delete from codebase when true and no references remain |
| **Risk if disabled** | User-facing or ops impact |

---

## 2. FormaAbTest — Health Intelligence

**Owner:** Health Intelligence platform  
**Facade:** `HealthIntelligenceFeatureFlags`

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `foundationEnabled` | true | true | shipped | No | All HI wiring off |
| `enginesEnabled` | true | true | shipped | No | No snapshot/review composition |
| `uiEnabled` | true | **false** | internal | No | HI sections hidden on Today/Journey/Plan |
| `coachContextEnabled` | true | true | shipped | No | Coach omits HI from context packets |
| `weeklyReviewEnabled` | true | **false** | internal | No | No `WeeklyReviewCard` on Journey |
| `syncEnabled` | true | true | shipped | No | Local HK cache sync stops |
| `remoteSummarySyncEnabled` | true | **false** | off | No | No Firestore health upload |
| `repositoryReadRoutingEnabled` | true | true | shipped | No | HI read routing breaks |
| `pipelineAnalyticsEnabled` | true | false | internal | No | HI pipeline analytics events stop |
| `todayDebugFetchEnabled` | true | false | internal | Yes* | No HI load in Today when UI off |
| `journeyDebugFetchEnabled` | true | false | internal | Yes* | No HI load in Journey when UI off |
| `planDebugFetchEnabled` | true | false | internal | Yes* | No HI load in Plan when UI off |

\* Removable only after UI ship decision and debug-fetch paths deleted.

**Derived loaders:**

| Property | Formula |
|----------|---------|
| `shouldTodayModelLoad` | `enginesEnabled && (uiEnabled \|\| todayDebugFetchEnabled)` |
| `shouldCoachLoad` | `enginesEnabled && coachContextEnabled` |
| `shouldJourneyModelLoad` | `enginesEnabled && (uiEnabled \|\| journeyDebugFetchEnabled)` |
| `shouldPlanModelLoad` | `enginesEnabled && (uiEnabled \|\| planDebugFetchEnabled)` |

**Legacy env keys (documentation only):** `FORMA_HEALTH_INTELLIGENCE_*` — listed in `EnvironmentKey` enum; resolver uses `FormaAbTest`, not process env.

---

## 3. FormaAbTest — Coach

**Owner:** Coach platform  
**Do not change defaults without Coach regression suite.**

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `aiCommandParsingEnabled` | true | true | shipped | No | AI routing off |
| `mealPhotoPipelineReady` | true | true | shipped | No | Photo scan pipeline off |
| `pipelineTraceEnabled` | true | false | internal | No | No pipeline trace (privacy win) |
| `pipelineTraceVerbose` | true | false | internal | No | Verbose trace off |
| `imageAnalysisDebugLog` | true | false | internal | No | Image pipeline logs off |
| `foodEstimateDebugLog` | true | false | internal | No | Food names/calories logs off |

---

## 4. FormaAbTest — Today

**Owner:** Today platform

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `scanFoodEnabled` | true | true | shipped | No | Food scan entry hidden |

---

## 5. FormaAbTest — Theme

**Owner:** Design system  
**Wiring:** `AppThemeShippingPolicy`, `ThemeAccessibilityAdaptationPolicy`

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `shipsLightAndSystemAppearance` | true | **false** | internal | No | Settings coerces to dark-only |
| `supportsIncreasedContrastPaletteVariants` | true | false | off | No | Not implemented — no-op today |
| `supportsReduceTransparencyCompositing` | true | false | off | No | Not implemented — no-op today |

---

## 6. FormaAbTest — Settings

**Owner:** Settings / privacy platform  
**Wiring:** `SettingsFeatureAvailability`, `SettingsDataDeletionCapability`, `AccountDataExportPolicy`

| Flag / capability | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|-------------------|-----------------|-------------------|---------|------------|------------------|
| ~~`dataExportEnabled`~~ | — | — | — | **Removed** | Was unused — export uses `AccountDataExportPolicy.isEnabled` |
| `dataDeletionEnabled` | true | true | shipped | No | Delete account/local rows hidden |
| `shipsInAppLegalWithoutPublishedURL` | true | false | internal | No | Legal rows hidden without URLs |
| `developerSectionVisible` | true | **false** | internal | No | Developer tools hidden |

**Export (not FormaAbTest):** `AccountDataExportPolicy.isEnabled` — compile-time `false`. `SettingsDataExportCapability.isImplemented` reads this policy.

---

## 7. FormaAbTest — Auth

**Owner:** Auth platform  
**Wiring:** `AuthCapabilities`, `AppRouteResolver`, `WelcomeOnboardingHandoffPolicy`

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `supportsAnonymousSignIn` | true | **false** | off | No | Anonymous auth path off |
| `requiresSignInBeforeOnboarding` | true | true | shipped | No | Onboarding before sign-in breaks |
| `preservesLocalUserDataOnSignOut` | true | true | shipped | No | Sign-out wipes local data |
| `clearsCloudSyncMetadataOnSignOut` | true | true | shipped | No | Stale sync metadata after sign-out |

---

## 8. FormaAbTest — Build

**Owner:** Platform

| Flag | Runtime default | Production default | Rollout | Removable? | Risk if disabled |
|------|-----------------|-------------------|---------|------------|------------------|
| `internalBuildEnabled` | true | **false** | internal | No | Internal-only surfaces |
| `includesDeveloperTools` | true | **false** | internal | No | Developer tools in build |

---

## 9. FormaAbTest — Diagnostics (trace flags)

**Owner:** Platform / diagnostics  
**Wiring:** `FormaAbTest.Diagnostics.*` + per-domain `*AnalyticsTrace` gates

| Flag | Runtime default | Production default | Rollout | Risk if disabled |
|------|-----------------|-------------------|---------|------------------|
| `todayAnalyticsTrace` | true | false | internal | No OSLog today analytics trace |
| `journeyAnalyticsTrace` | true | false | internal | No journey trace |
| `onboardingAnalyticsTrace` | true | false | internal | No onboarding trace |
| `settingsAnalyticsTrace` | true | false | internal | No settings trace |
| `themeAnalyticsTrace` | true | false | internal | No theme trace |
| `publicEntryAnalyticsTrace` | true | false | internal | No welcome/auth trace |
| `healthIntelligenceAnalyticsTrace` | true | false | internal | No HI trace |
| `healthTrainingTrace` | true | false | internal | No health training trace |
| `profileBootstrapTrace` | true | false | internal | No profile bootstrap trace |
| `authSignInTrace` | true | false | internal | No auth trace |
| `todayHydrationTrace` | true | false | internal | No hydration gate trace |
| `accountSyncTrace` | true | false | internal | No sync trace |
| `accountRestoreTrace` | true | false | internal | No restore trace |

**Analytics logger selection (not a flag):** `AppContainer` uses `OSLog*AnalyticsLogger` in `#if DEBUG` and `NoOp*AnalyticsLogger` in Release. See [LoggingAndPrivacyContract.md](./LoggingAndPrivacyContract.md).

---

## 10. AccountPersistenceFeatureFlags (compile-time)

**Owner:** Account persistence platform  
**Do not change without account persistence regression suite.**

| Flag | Value | Production default | Rollout | Removable? | Risk if disabled |
|------|-------|-------------------|---------|------------|------------------|
| `cloudSchemaEnabled` | **true** | true | shipped | No | No cloud DTOs / Firestore client |
| `syncEngineEnabled` | **true** | true | shipped | No | No `AccountSyncCoordinator` |
| `uploadPendingMutationsEnabled` | **true** | true | shipped | No | Outbox never drains |
| `pullRecentDataEnabled` | **false** | false | off | No | No bounded 90d foreground pull |
| `restoreOnLoginEnabled` | **true** | true | shipped | No | No restore UX on sign-in |
| `foregroundCrossDeviceRefreshEnabled` | **true** | true | shipped | No | Stale data on app active |
| `realtimeCrossDeviceSyncEnabled` | **true** | true | shipped | No | Delayed cross-device hints |
| `manualRefreshEnabled` | **true** | true | shipped | No | Pull-to-refresh sync no-ops |

**Exposed via** `FormaAbTest.AccountPersistence.*` (read-through).

---

## 11. Removed flags

| Flag | Removed | Reason |
|------|---------|--------|
| `FormaAbTest.Settings.dataExportEnabled` | 2026-07-04 | Zero call sites; export gated by `AccountDataExportPolicy` |

---

## 12. Test Overrides

```swift
// Unit tests — reset in tearDown
FormaAbTest.testOverride = FormaAbTestSnapshot(/* mutated */)
HealthIntelligenceFeatureFlags.testOverride = TestHealthIntelligenceFeatureFlags(...)
```

**Production-critical tests:** `FormaAbTestProductionCriticalFlagsTests`  
**Runtime default tests:** `HealthIntelligenceFeatureFlagsTests.testDefaultsAreAllEnabled`  
**Account persistence:** `AppContainerAccountDataRemoteStoreWiringTests.testPhase3SyncFlagsMatchRolloutPolicy`

---

## 13. Production Expectations (ship checklist)

Before App Store release, verify or wire `FormaAbTestSnapshot.production`:

- [ ] HI UI off unless product explicitly ships (`uiEnabled = false`)
- [ ] HI weekly review off (`weeklyReviewEnabled = false`)
- [ ] Health remote sync off by default + consent UX (`remoteSummarySyncEnabled = false`)
- [ ] Coach debug logs and pipeline trace off in Release
- [ ] Developer section hidden (`developerSectionVisible = false`)
- [ ] Light/system appearance gated (`shipsLightAndSystemAppearance = false`) until matrix QA
- [ ] Account persistence flags unchanged unless ops approves
- [ ] Analytics production sink: `NoOp*AnalyticsLogger` in Release (see Logging contract)
- [ ] Wire runtime resolver to `production` snapshot (explicit release decision)

---

## 14. Revision History

| Date | Change |
|------|--------|
| 2026-07-05 | Linked [PRDX_V1_FLAG_MATRIX.md](./PRDX_V1_FLAG_MATRIX.md); documented `resolvedSnapshot(for:)` |
| 2026-07-04 | Initial registry for PRDX v1 |
| 2026-07-04 | Added `FormaAbTestSnapshot.production`, per-flag metadata, removed `dataExportEnabled`, production-critical tests |
