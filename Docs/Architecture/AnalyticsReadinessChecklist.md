# Analytics Readiness Checklist

**Last updated:** 2026-07-04  
**Related:** [LoggingAndPrivacyContract.md](./LoggingAndPrivacyContract.md), [FeatureFlagRegistry.md](./FeatureFlagRegistry.md)  
**Implementation:** `Fitness Coach/Infrastructure/Diagnostics/AnalyticsLoggingSupport.swift`

---

## 1. Purpose

This checklist documents Forma’s **typed analytics contracts**, current **Release behavior** (NoOp sinks), privacy rules, and what remains before wiring a **production analytics backend**.

**Explicit non-goal:** Firebase Analytics is **not integrated** in domain code today. Do not add Firebase Analytics SDK calls without an explicit product decision.

---

## 2. Architecture

```
Feature coordinator / model
        ↓
Domain *AnalyticsLogging protocol (typed event + properties)
        ↓
AppContainer-injected sink
   ├── DEBUG: OSLog*AnalyticsLogger → LogRedactor.emitOSLogTrace
   └── Release: NoOp*AnalyticsLogger (intentional — events dropped)
```

**Coach accuracy observability** (`CoachAccuracyObservabilityLogger`) is separate from product analytics — metadata-only OSLog in Release. See Logging contract.

---

## 3. Protocol Registry

| Protocol | Event enum | Properties | Context builder | OSLog sink | NoOp sink | AppContainer property |
|----------|------------|------------|-----------------|------------|-----------|----------------------|
| `TodayAnalyticsLogging` | `TodayAnalyticsEvent` | `TodayAnalyticsProperties` | `TodayAnalyticsContextBuilder` | `OSLogTodayAnalyticsLogger` | `NoOpTodayAnalyticsLogger` | `todayAnalyticsLogger` |
| `JourneyAnalyticsLogging` | `JourneyAnalyticsEvent` | `JourneyAnalyticsProperties` | `JourneyAnalyticsContextBuilder` | `OSLogJourneyAnalyticsLogger` | `NoOpJourneyAnalyticsLogger` | `journeyAnalyticsLogger` |
| `PlanAnalyticsLogging` | `PlanAnalyticsEvent` | `PlanAnalyticsProperties` | `PlanAnalyticsContextBuilder` | `OSLogPlanAnalyticsLogger` | `NoOpPlanAnalyticsLogger` | `planAnalyticsLogger` |
| `OnboardingAnalyticsLogging` | `OnboardingAnalyticsEvent` | `OnboardingAnalyticsProperties` | `OnboardingAnalyticsContextBuilder` | `OSLogOnboardingAnalyticsLogger` | `NoOpOnboardingAnalyticsLogger` | `onboardingAnalyticsLogger` |
| `SettingsAnalyticsLogging` | `SettingsAnalyticsEvent` | `SettingsAnalyticsProperties` | `SettingsAnalyticsContextBuilder` | `OSLogSettingsAnalyticsLogger` | `NoOpSettingsAnalyticsLogger` | `settingsAnalyticsLogger` |
| `HealthIntelligenceAnalyticsLogging` | `HealthIntelligenceAnalyticsEvent` | `HealthIntelligenceAnalyticsProperties` | `HealthIntelligenceAnalyticsContextBuilder` | `OSLogHealthIntelligenceAnalyticsLogger` | `NoOpHealthIntelligenceAnalyticsLogger` | `healthIntelligenceAnalyticsLogger` |
| `PublicEntryAnalyticsLogging` | `PublicEntryAnalyticsEvent` | `PublicEntryAnalyticsProperties` | `PublicEntryAnalyticsContextBuilder` | `OSLogPublicEntryAnalyticsLogger` | `NoOpPublicEntryAnalyticsLogger` | `publicEntryAnalyticsLogger` |
| `ThemeAnalyticsLogging` | `ThemeAnalyticsEvent` | `ThemeAnalyticsProperties` | `ThemeAnalyticsProperties` factories | `OSLogThemeAnalyticsLogger` | `NoOpThemeAnalyticsLogger` | `themeAnalyticsLogger` |
| `CoachAnalyticsLogging` | `CoachAnalyticsEvent` | `CoachAnalyticsProperties` | inline at call sites | `OSLogCoachAnalyticsLogger` (DEBUG) | `NoOpCoachAnalyticsLogger` | not container-wired* |

\* Coach nutrition card events use `NoOpCoachAnalyticsLogger` / DEBUG `OSLogCoachAnalyticsLogger` at injection sites. Coach route/context accuracy uses `CoachAccuracyObservabilityLogger`.

---

## 4. Release Behavior (intentional)

| Build | Default sink | Events persisted? | User impact |
|-------|--------------|-------------------|-------------|
| **DEBUG** | `OSLog*` (gated by `FormaAbTest.Diagnostics.*AnalyticsTrace`) | OSLog only | None |
| **Release** | `NoOp*` | **No** | None |

**This is intentional** until a production sink ships. Release NoOp means:
- Call sites may log freely without network I/O
- No PII leaves the device via product analytics today
- Coordinators must not assume analytics side effects

### Production sink TODO

When product approves a backend (Firebase Analytics, Amplitude, internal gateway, etc.):

1. Implement `Production*AnalyticsLogger` adapters behind each protocol
2. Wire in `AppContainer` `#else` branch (keep NoOp as fallback behind flag)
3. Map typed properties → vendor schema (snake_case keys)
4. Add opt-in consent gate if required (App Store / GDPR)
5. Extend `AnalyticsInfrastructureTests` with adapter contract tests
6. Update App Store privacy nutrition labels

**Do not** enable Firebase Analytics in this repo without completing the above.

---

## 5. Event Naming Convention

| Rule | Example |
|------|---------|
| Format | `{domain}_{action}` snake_case |
| Domain prefix | `today_`, `journey_`, `plan_`, `onboarding_`, `settings_`, `health_intelligence_`, `public_`, `theme_` |
| Past tense for completions | `today_log_meal_saved`, `onboarding_completed` |
| View events | `*_viewed` |

All `*AnalyticsEvent` raw values must pass `AnalyticsLoggingSupport.isValidEventName`.

---

## 6. Property Privacy Rules

### Allowed

- Enums / status strings (`protein_status`, `recovery_status`)
- Buckets (`progress_percent_bucket`, `water_amount_bucket`, `confidence_bucket`)
- Booleans (`has_meal_logged`, `health_connected`)
- Counts (`missing_signal_count`, `unlocked_milestone_count`)
- Durations (`sync_duration_ms`)
- Theme palette IDs (`ocean_blue` — not user content)

### Never include

- Food names, meal text, review narrative
- Raw weight kg/lb values
- Coach user messages
- UIDs, email, tokens
- HealthKit sample values, workout titles
- Firestore / JSON payloads

### Sanitization

All sinks should call `properties.privacySafeParameters()` (via `AnalyticsLoggingSupport`) before emission. OSLog DEBUG traces also pass through `LogRedactor.emitOSLogTrace`.

### Parameter key convention

| Status | Convention |
|--------|------------|
| **Preferred** | snake_case (`day_stage`, `row_type`) |
| **Legacy** | camelCase in Onboarding, Coach, Theme (`durationMs`, `confidenceLevel`) — do not add new camelCase keys |

---

## 7. AppContainer Wiring

```swift
#if DEBUG
  OSLog*AnalyticsLogger()  // per domain
#else
  NoOp*AnalyticsLogger()    // intentional Release default
#endif
```

Factory methods:
- `makeSettingsAnalyticsCoordinator()` → `settingsAnalyticsLogger`
- `makeHealthIntelligenceAnalyticsCoordinator()` → `healthIntelligenceAnalyticsLogger`
- `makeJourneyAnalyticsCoordinator()` → `journeyAnalyticsLogger`
- Onboarding tracker / Today model / Plan model receive loggers at construction

Inject test doubles via `AppContainer(inMemory: true, todayAnalyticsLogger: CapturingTodayAnalyticsLogger(), ...)`.

---

## 8. Test Support

| Fake logger | Location |
|-------------|----------|
| `CapturingTodayAnalyticsLogger` | `Fitness CoachTests/TestingSupport/CapturingAnalyticsLoggers.swift` |
| `CapturingJourneyAnalyticsLogger` | same |
| `CapturingPlanAnalyticsLogger` | same |
| `CapturingOnboardingAnalyticsLogger` | same |
| `CapturingSettingsAnalyticsLogger` | same |
| `CapturingHealthIntelligenceAnalyticsLogger` | same |
| `CapturingPublicEntryAnalyticsLogger` | same |
| `CapturingThemeAnalyticsLogger` | same |
| `CapturingCoachAnalyticsLogger` | same |

### Automated tests

| Test class | Covers |
|------------|--------|
| `AnalyticsInfrastructureTests` | AppContainer sink selection, NoOp safety, event naming, privacy |
| `TodayAnalyticsTests` | Today buckets |
| `JourneyAnalyticsLoggingTests` | Journey buckets |
| `HealthIntelligenceAnalyticsLoggingTests` | HI privacy |
| `SettingsAnalyticsTests` | Settings rows |
| `FormaAbTestProductionCriticalFlagsTests` | AppContainer default logger types |

---

## 9. Pre-Ship Checklist

- [ ] All `*AnalyticsEvent` names follow `{domain}_{action}` snake_case
- [ ] Property bags contain buckets/booleans/counts only (no raw health/food/text)
- [ ] `AnalyticsInfrastructureTests` pass
- [ ] `LogRedactorTests` pass
- [ ] Release builds use `NoOp*` unless production sink explicitly wired
- [ ] Production sink adapter reviewed for PII
- [ ] User consent / privacy label updated (when sink enabled)
- [ ] `FormaAbTest.Diagnostics.*AnalyticsTrace` false in `FormaAbTestSnapshot.production`

---

## 10. Revision History

| Date | Change |
|------|--------|
| 2026-07-04 | Initial analytics readiness checklist |
| 2026-07-04 | Added `AnalyticsLoggingSupport`, fixed Plan OSLog sink, wired HI logger in AppContainer |
