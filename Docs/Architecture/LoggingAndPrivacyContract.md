# Logging and Privacy Contract

**Last updated:** 2026-07-04  
**Related:** [FeatureFlagRegistry.md](./FeatureFlagRegistry.md), [AppArchitectureOverview.md](./AppArchitectureOverview.md)

---

## 1. Purpose

Define what the app may log, where, and which data classes must never appear in **Release** logs or analytics. This contract supports PRDX v1 logging redaction work (`FormaLogRedactor` — planned).

---

## 2. Logging Layers

| Layer | Technology | Release behavior today |
|-------|------------|------------------------|
| **Product analytics** | `*AnalyticsLogging` protocols | **NoOp** in Release (`AppContainer` `#else`) |
| **Diagnostics / trace** | `OSLog` / `Logger` | Mostly `#if DEBUG`; some subsystem loggers gated by flag |
| **Coach pipeline trace** | `FormaPipelineTracer` | **DEBUG-only** entire type |
| **Health / sync** | `AccountSyncLogger`, `HealthSyncLogger`, etc. | DEBUG-gated emit |
| **AI client** | `FormaAIBackendClient` | Partial DEBUG request logging |

**Firebase Analytics SDK:** Present in SPM; **no Swift references** in domain code (**Confirmed**). Analytics are not persisted to a production backend today.

---

## 3. Logger Inventory

### Analytics loggers (`Infrastructure/Diagnostics/`)

| Logger | Protocol | DEBUG | Release |
|--------|----------|-------|---------|
| `OSLogTodayAnalyticsLogger` | `TodayAnalyticsLogging` | Active | NoOp |
| `OSLogJourneyAnalyticsLogger` | `JourneyAnalyticsLogging` | Active | NoOp |
| `OSLogPlanAnalyticsLogger` | `PlanAnalyticsLogging` | Active | NoOp |
| `OSLogOnboardingAnalyticsLogger` | `OnboardingAnalyticsLogging` | Active | NoOp |
| `OSLogSettingsAnalyticsLogger` | `SettingsAnalyticsLogging` | Active | NoOp |
| `OSLogThemeAnalyticsLogger` | `ThemeAnalyticsLogging` | Active | NoOp |
| `OSLogPublicEntryAnalyticsLogger` | `PublicEntryAnalyticsLogging` | Active | NoOp |
| `OSLogHealthIntelligenceAnalyticsLogger` | `HealthIntelligenceAnalyticsLogging` | Active | NoOp |
| `OSLogCoachAnalyticsLogger` | `CoachAnalyticsLogging` | In Domain file | Limited / NoOp |

### Debug / diagnostics loggers

| Logger | Sensitive data risk | Release guard |
|--------|---------------------|---------------|
| `CoachFoodEstimateDebugLogger` | **High** — food names, calories, macros, user text | `#if DEBUG` emit |
| `FormaPipelineTracer` | **High** — user messages, HTTP metadata | `#if DEBUG` type |
| `CoachImageAnalysisDebugLogger` | Medium — image pipeline | `#if DEBUG` |
| `CoachImageProcessingLogger` | Medium | `#if DEBUG` |
| `AccountSyncLogger` | Medium — UIDs, mutation metadata | `#if DEBUG` |
| `AccountRestoreLogger` | Medium — restore phases | `#if DEBUG` |
| `AccountDeletionCoordinatorLogger` | Medium — deletion steps | Audit — may log in Release |
| `AuthSignInDebugLogger` | Medium | `#if DEBUG` |
| `ProfileBootstrapDebugLogger` | Low–medium | `#if DEBUG` |
| `TodayHydrationDebugLogger` | Low | `#if DEBUG` |
| `HealthDataRepositoryLogger` | Low — no raw HK samples | `#if DEBUG` |
| `HealthSummarySyncDebugLogger` | Medium — payload summaries | `#if DEBUG` |
| `CrossDeviceSyncLogger` | Medium | `#if DEBUG` |
| `CoachAccuracyObservability` | Medium | `#if DEBUG` |

---

## 4. Prohibited in Release Logs

The following **must not** appear in Release `Logger` / `print` / OSLog output:

| Class | Examples |
|-------|----------|
| **Food content** | Meal names, ingredient lists, per-item calories/macros |
| **Body metrics** | Weight values, goal weight (prefer deltas or buckets if needed) |
| **User-generated text** | Coach chat messages, daily review narrative, onboarding free text |
| **Images** | Base64, JPEG bytes, file paths to meal photos |
| **Auth secrets** | ID tokens, refresh tokens, Bearer headers, API keys |
| **Full Firebase UID** | Prefer truncated hash or `uid.prefix(8)` if identifier needed |
| **Firestore document bodies** | Full nutrition payloads |
| **HealthKit raw samples** | Heart rate series, HRV raw, location |

**Allowed in Release (metadata only):**

- Sync phase enums (upload started, restore completed)
- Error categories without payload bodies
- Feature flag state (boolean)
- Network error codes (not response bodies)
- Aggregated counts (e.g. `mutationCount=3`)

---

## 5. Redaction Rules

### Existing implementation (DEBUG only)

`CoachContextPacketV2DebugRedactor` (`Features/Settings/Model/`) — patterns:

| Pattern | Replacement |
|---------|-------------|
| Bearer tokens | Redacted |
| JWT (`eyJ…`) | Redacted |
| `api_key` / `token` / `secret` / `password` assignments | Redacted |
| Base64 blobs ≥120 chars | Redacted |
| Chat text / timeline summaries | Truncated (80–120 chars) + secret pass |

### Planned shared utility (PRDX P0)

`FormaLogRedactor` should centralize:

```text
redactSecrets(in: String) -> String
truncate(_ string: String, maxLength: Int) -> String
redactUID(_ uid: String) -> String          // e.g. first 8 chars + "…"
redactNutritionSummary(calories:protein:…)  // bucketed or omitted
```

### UID logging

| Context | Rule |
|---------|------|
| Sync/restore diagnostics | `redactUID` or omit |
| Analytics | No UID in event properties unless hashed |
| DEBUG inspector | Full UID allowed in DEBUG builds only |

---

## 6. AI Gateway Privacy

| Data | Leaves device? | Persisted server-side? |
|------|----------------|----------------------|
| `CoachContextPacketV2` JSON | Yes — HTTPS + Bearer token | **No** (stateless gateway) |
| Meal image base64 | Yes — meal analysis endpoint | **No** |
| User chat text | Yes — classify/parse endpoints | **No** |

**Client responsibility:** `CoachContextPacketV2.clampedForTransport()` before encode.

---

## 7. Analytics Privacy

### Current state

- Events defined per domain protocol (`Domain/*/AnalyticsLogging.swift`)
- DEBUG: OSLog subsystem logging
- Release: **dropped** (NoOp)

### Property rules (when production sink ships)

| Allowed | Disallowed |
|---------|------------|
| Screen names, funnel step enums | Food names, meal text |
| Error codes | Weight values |
| Flag states | Full UID |
| Aggregated buckets (`calorie_band`) | Free-text coach messages |
| `schemaVersion` ints | Firestore payloads |

### Consent

- Health summary **remote** sync requires explicit user consent (`HealthSummarySyncConsentStore`) — separate from analytics.
- App Store privacy nutrition labels must cover analytics when sink enabled (**Unknown** — legal review).

---

## 8. Environment Gating

| Mechanism | Controls |
|-----------|----------|
| `#if DEBUG` | Entire debug loggers, pipeline tracer, context inspector |
| `FormaAbTest.Coach.pipelineTraceEnabled` | In-DEBUG tracer verbosity |
| `FormaAbTest.Coach.foodEstimateDebugLog` | Food estimate debug logger |
| `FormaAbTest.Diagnostics.*Trace` | Per-domain analytics trace to OSLog |
| `FormaAbTest.Build.internalBuildEnabled` | Internal tooling (future) |

**Rule:** New loggers must default **off** in Release or behind `#if DEBUG`.

---

## 9. Release Audit Checklist (PRDX)

Before merging logging changes:

- [ ] `rg 'Logger\(' Fitness Coach/` — every hit reviewed for `#if DEBUG` or redaction
- [ ] No `print(` with user data in Release paths
- [ ] Coach food estimate logger never compiled into Release emit paths
- [ ] `FormaPipelineTracer` not linked in Release
- [ ] Account deletion logs contain no PII bodies
- [ ] Add `ReleaseLoggingGuardTests` allowlist for approved Release log sites

---

## 10. Incident Response

If PII is logged in Release:

1. Revert offending commit or hotfix guard with `#if DEBUG`
2. Rotate keys only if tokens were exposed (rare in local OSLog)
3. Update this contract + allowlist test

---

## 11. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial logging and privacy contract for PRDX v1 |
