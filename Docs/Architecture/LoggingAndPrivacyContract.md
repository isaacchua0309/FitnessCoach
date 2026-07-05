# Logging and Privacy Contract

**Last updated:** 2026-07-04  
**Related:** [FeatureFlagRegistry.md](./FeatureFlagRegistry.md), [AppArchitectureOverview.md](./AppArchitectureOverview.md)  
**Implementation:** `Fitness Coach/Infrastructure/Diagnostics/FormaLogRedactor.swift`, `LogRedactor.swift`, `PrivacySafeLogValue.swift`  
**Release allowlist:** [ReleaseLoggingAllowlist.md](./ReleaseLoggingAllowlist.md)

---

## 1. Purpose

Define what the app may log, where, and which data classes must never appear in **Release** logs or analytics. All new diagnostics must use `FormaLogRedactor` / `LogRedactor` or `PrivacySafeLogValue`.

---

## 2. Logging Layers

| Layer | Technology | Release behavior today |
|-------|------------|----------------------|
| **Product analytics** | `*AnalyticsLogging` protocols | **NoOp** in Release (`AppContainer` `#else`) |
| **Diagnostics / trace** | `OSLog` / `Logger` | Mostly `#if DEBUG`; sync/restore DEBUG-gated |
| **Coach pipeline trace** | `FormaPipelineTracer` | **DEBUG-only** entire type |
| **Coach accuracy observability** | `CoachAccuracyObservabilityLogger` | Metadata only; fields sanitized via `LogRedactor` |
| **Health / sync** | `HealthSyncLogger`, `AccountSyncLogger`, etc. | Release logs counts/categories only |
| **AI client** | `FormaAIBackendClient` | Partial DEBUG request logging; gateway errors redacted |

**Firebase Analytics SDK:** Present in SPM; **no Swift references** in domain code. Analytics are not persisted to a production backend today.

---

## 3. Logger Inventory

### Analytics loggers (`Infrastructure/Diagnostics/`)

| Logger | Protocol | DEBUG | Release |
|--------|----------|-------|---------|
| `OSLogTodayAnalyticsLogger` | `TodayAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogJourneyAnalyticsLogger` | `JourneyAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogPlanAnalyticsLogger` | `PlanAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogOnboardingAnalyticsLogger` | `OnboardingAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogSettingsAnalyticsLogger` | `SettingsAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogThemeAnalyticsLogger` | `ThemeAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogPublicEntryAnalyticsLogger` | `PublicEntryAnalyticsLogging` | Active + redacted | NoOp |
| `OSLogHealthIntelligenceAnalyticsLogger` | `HealthIntelligenceAnalyticsLogging` | Active + redacted | NoOp |

DEBUG analytics traces call `LogRedactor.emitOSLogTrace` before writing to OSLog.

### Debug / diagnostics loggers

| Logger | Sensitive data risk | Release guard |
|--------|---------------------|---------------|
| `CoachFoodEstimateDebugLogger` | **High** — food names, calories, macros | `#if DEBUG` emit only |
| `FormaPipelineTracer` | **High** — user messages, HTTP metadata | `#if DEBUG` type; OSLog fields sanitized |
| `CoachImageAnalysisDebugLogger` | Medium — image pipeline | `#if DEBUG` |
| `CoachAccuracyObservability` | Medium — context metadata | Release-safe counts; `LogRedactor.sanitizeLogFields` |
| `AccountSyncLogger` | Medium — UIDs, mutation metadata | DEBUG-gated; `LogRedactor` |
| `AccountRestoreLogger` | Medium — restore phases | DEBUG-gated; `LogRedactor` |
| `AccountDeletionCoordinatorLogger` | Medium — deletion steps | **Release** — hashed UID + status only |
| `CrossDeviceSyncLogger` | Medium — sync counts | DEBUG-gated; `LogRedactor` |
| `HealthSyncLogger` | Low — signal categories | Release — no raw HK samples or error bodies |
| `HealthSummarySyncDebugLogger` | Medium — payload counts | Release — counts only |
| `HealthDataRepositoryLogger` | Low | Error description DEBUG-only |
| `ProfileBootstrapDebugLogger` | Low–medium | `LogRedactor` on all fields |

---

## 4. Prohibited in Release Logs

The following **must not** appear in Release `Logger` / `print` / OSLog output:

| Class | Examples |
|-------|----------|
| **Food content** | Meal names, ingredient lists, per-item calories/macros |
| **Body metrics** | Raw weight values, goal weight (use buckets via `LogRedactor.weightBucketKg`) |
| **User-generated text** | Coach chat messages, daily review narrative, onboarding free text |
| **Images** | Base64, JPEG bytes, file paths to meal photos |
| **Auth secrets** | ID tokens, refresh tokens, Bearer headers, API keys |
| **Full Firebase UID** | Use `LogRedactor.hashedUID` or `LogRedactor.redactUID` |
| **Firestore document bodies** | Full nutrition payloads |
| **HealthKit raw samples** | Heart rate series, HRV raw, location |
| **Email addresses** | Redacted by `LogRedactor.redactSecrets` |

**Allowed in Release (metadata only):**

- Sync phase enums (upload started, restore completed)
- Error categories without payload bodies (`errorCategory`, `errorDomain` + `errorCode`)
- Feature flag state (boolean)
- Network error codes (not response bodies)
- Aggregated counts (e.g. `pulledFoodEntries=3`, `mutationCount=3`)
- Durations, buckets, status enums, event names

---

## 5. Redaction Rules (`FormaLogRedactor` + `LogRedactor`)

### Core text redaction (`FormaLogRedactor`)

| API | Purpose |
|-----|---------|
| `hashedUID(_:)` | 8-char SHA-256 prefix for correlation |
| `redactUID(_:)` | Suffix-only UID (`***suffix`) |
| `redactSecrets(in:)` / `redact(_:)` | Bearer/JWT/base64/email/URL-query/UID paths in free text → `[REDACTED]` |
| `redactURLQueryValues(in:)` | Query parameter values only; preserves names and host |
| `containsObviousSecrets(_:)` | Predicate for domain validators |
| `truncate(_:maxLength:)` | Length cap with ellipsis |

### Field / JSON / OSLog policies (`LogRedactor`)

| API | Purpose |
|-----|---------|
| `redactSensitiveJSONFields(_:)` | JSON field redaction → `"<redacted>"` |
| `sanitizeLogFields(_:options:)` | Drop/strip sensitive keys and values |
| `calorieBucket(_:)` / `weightBucketKg(_:)` | Production-safe numeric buckets |
| `safeErrorFields(from:includeDescription:)` | NSError domain/code; description DEBUG-only |
| `emitOSLogTrace(prefix:logger:message:fields:)` | Sanitized OSLog line for DEBUG traces |

Delegates identifier and free-text redaction to `FormaLogRedactor`.

### Typed safe values (`PrivacySafeLogValue`)

Use `PrivacySafeLogFields.make` / `.sanitized` when building production log dictionaries from typed values (counts, categories, uid hashes).

### Field key policy

`LogRedactor.isSensitiveFieldKey` blocks keys containing sensitive tokens (`name`, `message`, `calorie`, etc.) **except** aggregate sync/restore metrics (`pulled*`, `*Restored`, `*Fetched`, `*Count`).

### UID logging

| Context | Rule |
|---------|------|
| Sync/restore/deletion diagnostics | `uidHash` via `LogRedactor.hashedUID` |
| Profile bootstrap / auth DEBUG | `LogRedactor.redactUID` |
| Analytics | No UID in event properties unless hashed |
| DEBUG pipeline inspector UI | Full message visible in-memory only; OSLog uses `userMessageLength` |

### JSON redaction patterns

| Pattern | Replacement |
|---------|-------------|
| Bearer tokens | `<redacted>` |
| `base64`, `imageJPEGBase64` | `<redacted>` |
| `message`, `text`, `name`, `summary`, `review` | `<redacted>` |
| `context`, `payload`, `document` objects | `<redacted>` |
| `email`, `token`, `password` | `<redacted>` |

`CoachImageAnalysisDebugLogFormatter`, `CoachAccuracyObservabilityLogFormatter`, and `FormaPipelineTracer` delegate JSON redaction to `LogRedactor`.

---

## 6. AI Gateway Privacy

| Data | Leaves device? | Persisted server-side? |
|------|----------------|----------------------|
| `CoachContextPacketV2` JSON | Yes — HTTPS + Bearer token | **No** (stateless gateway) |
| Meal image base64 | Yes — meal analysis endpoint | **No** |
| User chat text | Yes — classify/parse endpoints | **No** |

**Client responsibility:** `CoachContextPacketV2.clampedForTransport()` before encode. DEBUG inspection uses `CoachContextPacketV2DebugRedactor` + `LogRedactor`.

---

## 7. Analytics Privacy

**See also:** [AnalyticsReadinessChecklist.md](./AnalyticsReadinessChecklist.md) — full protocol registry and production sink TODO.

### Current state

- Events defined per domain protocol (`Domain/*/AnalyticsLogging.swift`)
- DEBUG: OSLog subsystem logging through `LogRedactor.emitOSLogTrace`
- Release: **dropped** (NoOp)

### Property rules (when production sink ships)

| Allowed | Disallowed |
|---------|------------|
| Screen names, funnel step enums | Food names, meal text |
| Error codes | Raw weight values |
| Flag states | Full UID |
| Aggregated buckets (`calorie_band`) | Free-text coach messages |
| `schemaVersion` ints | Firestore payloads |

---

## 8. Environment Gating

| Mechanism | Controls |
|-----------|----------|
| `#if DEBUG` | Entire debug loggers, pipeline tracer, food estimate logger |
| `FormaAbTest.Coach.pipelineTraceEnabled` | In-DEBUG tracer verbosity |
| `FormaAbTest.Coach.foodEstimateDebugLog` | Food estimate debug logger |
| `FormaAbTest.Diagnostics.*Trace` | Per-domain analytics trace to OSLog |
| `LogRedactor.sanitizeLogFields` | Final guard on structured log fields |

**Rule:** New loggers must default **off** in Release or sanitize through `LogRedactor`.

---

## 9. Release Audit Checklist

Before merging logging changes:

- [ ] `rg 'Logger\(' Fitness Coach/` — every hit reviewed for `#if DEBUG` or `LogRedactor`
- [ ] No `print(` with user data in Release paths
- [ ] Coach food estimate logger never compiled into Release emit paths
- [ ] `FormaPipelineTracer` not linked in Release
- [ ] Account deletion logs use `uidHash` only
- [ ] `LogRedactorTests` pass
- [ ] `CoachAccuracyObservabilityTests` / `CoachImageAnalysisDebugLogFormatterTests` pass

---

## 10. Tests

| Test class | Covers |
|------------|--------|
| `LogRedactorTests` | UID hashing, JSON/secret redaction, field sanitization, buckets |
| `CoachAccuracyObservabilityTests` | Production log lines, JSON redaction |
| `CoachImageAnalysisDebugLogFormatterTests` | Image pipeline field omission |
| `AccountSyncLoggerTests` | Hashed UID stability |

---

## 11. Incident Response

If PII is logged in Release:

1. Revert offending commit or hotfix guard with `#if DEBUG` + `LogRedactor`
2. Rotate keys only if tokens were exposed (rare in local OSLog)
3. Update this contract and add regression test in `LogRedactorTests`

---

## 12. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial logging and privacy contract for PRDX v1 |
| 2026-07-04 | Added `LogRedactor`, `PrivacySafeLogValue`, centralized redaction across loggers |
