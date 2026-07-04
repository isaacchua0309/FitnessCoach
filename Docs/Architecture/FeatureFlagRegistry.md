# Feature Flag Registry

**Last updated:** 2026-07-04  
**Sources of truth:** `Fitness Coach/Configuration/FormaAbTest.swift`, `Fitness Coach/Infrastructure/Cloud/AccountPersistenceFeatureFlags.swift`, `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift`

---

## 1. Overview

| Registry | Type | Runtime resolver |
|----------|------|------------------|
| `FormaAbTest` | `FormaAbTestSnapshot` | `testOverride ?? .allEnabled` |
| `AccountPersistenceFeatureFlags` | `static let` constants | Compile-time |
| `HealthIntelligenceFeatureFlags` | Facade over `FormaAbTest` | `AbTestHealthIntelligenceFeatureFlags` |

**There is no Firebase Remote Config** in this repo (**Confirmed**).

### Runtime vs production intent

| Snapshot | Purpose | Used at runtime today? |
|----------|---------|----------------------|
| `FormaAbTestSnapshot.allEnabled` | Internal/dev — all gates on | **Yes** — default for app and tests |
| Production intent (documented) | App Store safe defaults | **Documented** in HI header + `PHASE_20_RELEASE_READINESS.md`; **not a separate struct yet** (PRDX P0) |

**Known contradiction:** `allEnabled` sets HI UI, weekly review, remote sync, and debug traces to `true`, while Health Intelligence release docs specify several as `false`. Treat **runtime behavior** as `allEnabled` until a `production` snapshot is wired (**Confirmed**).

---

## 2. FormaAbTest — Health Intelligence

| Flag | `allEnabled` | Production intent | Used? | User-visible when on |
|------|--------------|-------------------|-------|----------------------|
| `foundationEnabled` | true | true | Yes | Master HI switch |
| `enginesEnabled` | true | true | Yes | Background engines |
| `uiEnabled` | true | **false** | Yes | HI sections on Today/Journey/Plan |
| `coachContextEnabled` | true | true | Yes | HI in Coach context packet |
| `weeklyReviewEnabled` | true | **false** | Yes | HI `WeeklyReviewCard` on Journey |
| `syncEnabled` | true | true | Yes | Local HK cache sync |
| `remoteSummarySyncEnabled` | true | **false** | Yes | Firestore health upload (also needs consent) |
| `repositoryReadRoutingEnabled` | true | true | Yes | HI read routing |
| `pipelineAnalyticsEnabled` | true | false | Yes | HI pipeline analytics events |
| `todayDebugFetchEnabled` | true | false | Yes | Load HI in Today when UI off |
| `journeyDebugFetchEnabled` | true | false | Yes | Load HI in Journey when UI off |
| `planDebugFetchEnabled` | true | false | Yes | Load HI in Plan when UI off |

**Derived loaders:**

| Property | Formula |
|----------|---------|
| `shouldTodayModelLoad` | `enginesEnabled && (uiEnabled \|\| todayDebugFetchEnabled)` |
| `shouldCoachLoad` | `enginesEnabled && coachContextEnabled` |
| `shouldJourneyModelLoad` | `enginesEnabled && (uiEnabled \|\| journeyDebugFetchEnabled)` |
| `shouldPlanModelLoad` | `enginesEnabled && (uiEnabled \|\| planDebugFetchEnabled)` |

**Facade:** `HealthIntelligenceFeatureFlags` — see `Health/HealthIntelligenceFeatureFlags.swift`.

**Legacy env keys (documentation only):** `FORMA_HEALTH_INTELLIGENCE_*` — listed in `EnvironmentKey` enum; resolver uses `FormaAbTest`, not process env, unless separately wired.

---

## 3. FormaAbTest — Coach

| Flag | `allEnabled` | Production intent | Risk |
|------|--------------|-------------------|------|
| `aiCommandParsingEnabled` | true | true | AI routing |
| `mealPhotoPipelineReady` | true | true | Photo pipeline |
| `pipelineTraceEnabled` | true | **false** | DEBUG tracer; logs user messages |
| `pipelineTraceVerbose` | true | **false** | Verbose trace |
| `imageAnalysisDebugLog` | true | **false** | Image pipeline logs |
| `foodEstimateDebugLog` | true | **false** | Food names/calories in logs |

---

## 4. FormaAbTest — Today

| Flag | `allEnabled` | Production intent |
|------|--------------|-------------------|
| `scanFoodEnabled` | true | true (product) |

---

## 5. FormaAbTest — Theme

| Flag | `allEnabled` | Production intent | Notes |
|------|--------------|-------------------|-------|
| `shipsLightAndSystemAppearance` | true | **false** until QA | `AppThemeShippingPolicy` coerces to dark when false |
| `supportsIncreasedContrastPaletteVariants` | true | false | Not implemented — TODO in `ThemeAccessibilityAdaptationPolicy` |
| `supportsReduceTransparencyCompositing` | true | false | Not implemented |

---

## 6. FormaAbTest — Settings

| Flag | `allEnabled` | Production intent | Actual wiring |
|------|--------------|-------------------|---------------|
| `dataExportEnabled` | true | false | **Unused in UI** — `SettingsDataExportCapability` uses `AccountDataExportPolicy.isEnabled` (false) |
| `dataDeletionEnabled` | true | true | `SettingsDataDeletionCapability.isImplemented` |
| `shipsInAppLegalWithoutPublishedURL` | true | TBD | Legal TODOs in `FormaLegalCopy` |
| `developerSectionVisible` | true | **false** | Settings developer tools |

---

## 7. FormaAbTest — Auth

| Flag | `allEnabled` | Production intent |
|------|--------------|-------------------|
| `supportsAnonymousSignIn` | true | false (likely) |
| `requiresSignInBeforeOnboarding` | true | true |
| `preservesLocalUserDataOnSignOut` | true | true (Phase 1) |
| `clearsCloudSyncMetadataOnSignOut` | true | true |

---

## 8. FormaAbTest — Build

| Flag | `allEnabled` | Production intent |
|------|--------------|-------------------|
| `internalBuildEnabled` | true | **false** |
| `includesDeveloperTools` | true | **false** |

---

## 9. FormaAbTest — Diagnostics (trace flags)

All `*Trace` flags default **true** in `allEnabled`. Production intent: **false** in Release (trace to OSLog only when enabled).

| Flag | Domain |
|------|--------|
| `todayAnalyticsTrace` | Today analytics |
| `journeyAnalyticsTrace` | Journey analytics |
| `onboardingAnalyticsTrace` | Onboarding |
| `settingsAnalyticsTrace` | Settings |
| `themeAnalyticsTrace` | Theme |
| `publicEntryAnalyticsTrace` | Welcome/auth |
| `healthIntelligenceAnalyticsTrace` | HI |
| `healthTrainingTrace` | Health training |
| `profileBootstrapTrace` | Profile bootstrap |
| `authSignInTrace` | Auth |
| `todayHydrationTrace` | Today hydration gate |
| `accountSyncTrace` | Account sync |
| `accountRestoreTrace` | Account restore |

---

## 10. AccountPersistenceFeatureFlags (compile-time)

**Do not change without account persistence regression suite.**

| Flag | Value | Phase | Effect |
|------|-------|-------|--------|
| `cloudSchemaEnabled` | **true** | 2 | Cloud DTOs + Firestore client available |
| `syncEngineEnabled` | **true** | 3 | `AccountSyncCoordinator` orchestration |
| `uploadPendingMutationsEnabled` | **true** | 3 | Drain outbox on sync runs |
| `pullRecentDataEnabled` | **false** | 3 | Bounded foreground pull (90d) — **off** |
| `restoreOnLoginEnabled` | **true** | 4 | Blocking restore UX on sign-in |
| `foregroundCrossDeviceRefreshEnabled` | **true** | 5 | Foreground incremental refresh |
| `realtimeCrossDeviceSyncEnabled` | **true** | 5 | Firestore realtime hints |
| `manualRefreshEnabled` | **true** | 5 | Pull-to-refresh sync |

**Exposed via** `FormaAbTest.AccountPersistence.*` (read-through).

---

## 11. Test Overrides

```swift
// Unit tests — reset in tearDown
FormaAbTest.testOverride = FormaAbTestSnapshot(/* mutated */)
HealthIntelligenceFeatureFlags.testOverride = TestHealthIntelligenceFeatureFlags(...)
```

**Tests asserting current runtime:** `HealthIntelligenceFeatureFlagsTests.testDefaultsAreAllEnabled`.

---

## 12. Production Expectations (ship checklist)

Before App Store release, verify or wire:

- [ ] HI UI off unless product explicitly ships (`uiEnabled = false`)
- [ ] HI weekly review off (`weeklyReviewEnabled = false`) — Weekly Progress sprint may change
- [ ] Health remote sync off by default + consent UX (`remoteSummarySyncEnabled = false`)
- [ ] Coach debug logs and pipeline trace off in Release
- [ ] Developer section hidden (`developerSectionVisible = false`)
- [ ] Light/system appearance gated (`shipsLightAndSystemAppearance = false`) until matrix QA
- [ ] Account persistence flags unchanged unless ops approves
- [ ] Analytics production sink opt-in (separate from flags — see [LoggingAndPrivacyContract.md](./LoggingAndPrivacyContract.md))

---

## 13. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial registry for PRDX v1 |
