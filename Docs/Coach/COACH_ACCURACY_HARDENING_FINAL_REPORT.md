# Coach Accuracy Hardening Sprint — Final Verification Report

> **Note:** For **Trust Hardening v1** (calorie ranges, assumptions, photo trust policy, regression matrix), see the successor doc: [COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md](./COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md).

**Date:** 2026-07-04  
**Baseline branch:** `main` @ `91b7e3e`  
**Consolidation branch:** `cursor/coach-accuracy-production-hardening-194c`  
**Consolidation PR:** [#103](https://github.com/isaacchua0309/FitnessCoach/pull/103) (draft)  
**Schema version:** `CoachContextPacketV2.meta.schemaVersion == 2`

**Related docs:**
- [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md)
- [COACH_CONTEXT_PACKET_V2.md](./COACH_CONTEXT_PACKET_V2.md)
- [COACH_TIMELINE_V2_MIGRATION.md](./COACH_TIMELINE_V2_MIGRATION.md)
- [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) — PR #101 (manual QA)
- [COACH_ACCURACY_HARDENING_IMPLEMENTATION.md](./COACH_ACCURACY_HARDENING_IMPLEMENTATION.md) — PR #102 (architecture)

---

## 1. Sprint summary

The Coach Accuracy Hardening Sprint extends Coach Timeline Context v2 with production-safe accuracy improvements across routing, food estimation, health context, timeline transport, persistence, backend validation, and observability.

**Goals achieved:**

| Goal | Outcome |
|------|---------|
| Single AI transport contract | `CoachContextPacketV2` is the only active Coach AI transport; legacy `AIContext` is deprecated |
| Nutrition truth from log services | Food/water/weight mutations go through repositories; timeline is audit/context only |
| Advice vs log separation | Classifier + confidence gate route advice to non-mutating handlers |
| Compound / local food accuracy | Multi-component validation, decomposition, Singapore fixture pack |
| Health Intelligence in Coach context | Default-on via `FormaAbTestSnapshot.allEnabled` when engines + coach context enabled |
| Safe degradation | Partial packet assembly, `.degraded` generation mode, 24 KB compaction |
| Edit/delete target resolution | Timeline + `linkedEntryId` resolver; unsafe meal-type delete fallback removed |
| Privacy-safe telemetry | Production `CoachAccuracy` OSLog category; redacted debug summaries |
| Automated contract coverage | 333 Firebase Jest tests; targeted iOS XCTest suites (not run in cloud agent) |

**Sprint delivery model:**

- **On `main`:** Timeline v2, packet builder, HI flags, classifier hardening, compaction, validator, SwiftData V5/V6, daily status, backend v2 validation, prompt rules.
- **In PR #103:** Meal photo hardening, observability, edit/delete resolver, compound food + Singapore fixtures, debug redaction fix.

---

## 2. Files changed

### 2.1 Consolidation delta (PR #103 vs `main`)

**51 files changed · +7,403 / −189 lines**

| Area | Key files |
|------|-----------|
| **Edit/delete** | `CoachEntryReferenceResolver.swift`, `CoachMutationExecutor.swift`, `CoachAIRouteHandler.swift`, `CoachResponseBuilder.swift` |
| **Photo** | `CoachMealImageAIRequestBuilder.swift`, `MealImageAnalysisMapper.swift`, `CoachMealPhotoContextV2Tests.swift`, `mealImageAnalysis.ts` |
| **Observability** | `CoachAccuracyObservability.swift`, `coachContextPacketV2.ts`, `gatewayGuardrails.ts`, `index.ts` |
| **Compound food (iOS)** | `FoodCompoundDishDetector.swift`, `FoodEstimateResponseValidator.swift`, `NutritionSanityValidator.swift`, `FoodLogDraftNutritionCompleter.swift` |
| **Compound food (backend)** | `foodCompoundDish.ts`, `foodEstimateExtraction.ts`, `foodLoggingGoldenCases.ts` |
| **Singapore fixtures** | `Docs/Coach/Fixtures/singapore_food_estimation_cases.json`, `SingaporeFoodEstimationFixtureTests.swift`, `singaporeFoodEstimationFixture.test.ts` |
| **Context transport** | `CoachContextPacketV2.swift` (redacted debug labels), `CoachContextPacketV2Builder.swift`, `AIService.swift`, `CoachModel.swift` |
| **Classifier trace** | `CoachIntentConfidenceGate.swift`, `CoachRouteDecider.swift`, `CoachRouteDebugLogger.swift` |

### 2.2 Sprint baseline on `main` (pre-#103)

| Area | Key files |
|------|-----------|
| **Packet v2** | `CoachContextPacketV2.swift`, `CoachContextPacketV2Builder.swift`, `CoachContextCorrectnessValidator.swift` |
| **Timeline** | `CoachTimelineStore.swift`, `CoachTimelineBackfillService.swift`, `CoachTimelineCompactionPolicy.swift`, `AppContainer.swift` |
| **HI** | `FormaAbTest.swift`, `HealthIntelligenceFeatureFlags.swift`, `CoachHealthIntelligenceContextBuilder.swift` |
| **Classifier** | `CoachRouteDecider.swift`, `CoachIntentConfidenceGate.swift`, `CoachIntentRouter.swift`, `LocalNoAPIGuard.swift` |
| **Daily status** | `CoachDailyStatusBuilder.swift`, `CoachResponseBuilder.swift` |
| **Persistence** | `FormaModelMigration.swift` (V5 timeline, V6 transcript), `CoachChatTranscriptPersistenceTests.swift` |
| **Backend** | `coachContextPacketV2.ts`, `coachContextPromptRules.ts`, `gatewayGuardrails.ts`, `index.ts` |
| **DEBUG diagnostics** | `PipelineDiagnosticsView.swift`, `CoachAIRequestContextLogging.swift` |

---

## 3. Health Intelligence result

**Status: PASS (code + unit tests); manual HealthKit QA pending**

| Requirement | Verification |
|-------------|--------------|
| Default-on when safe | `FormaAbTestSnapshot.allEnabled` sets `coachContextEnabled = true`; `HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence` returns true under defaults |
| Failure degrades packet, not send flow | Builder catches per-source read errors; HI section omitted on failure; `missingData` flags set; `generationMode` may become `.degraded` |
| HealthKit denied ≠ no workout | `resolveWorkoutsToday`: `.accessDenied`/`.unavailable` → `workoutsToday = nil` (not `0`) |
| Steps missing ≠ 0 steps | `stepsMissing` set only when `stepsResult.value == nil`; explicit `0` is valid |
| Workout unknown ≠ no workout | `trainingWorkouts=unknown` in redacted debug when permission denied/unavailable; `0` when available with no workouts |

**Tests:** `HealthIntelligenceFeatureFlagsTests` (11 methods), `CoachContextPacketV2BuilderTests`, `CoachMealPhotoContextV2Tests`, `CoachContextCorrectnessValidatorTests`.

---

## 4. Classifier hardening result

**Status: PASS**

| Requirement | Verification |
|-------------|--------------|
| Advice questions do not create food logs | Backend `classifyCoachIntentPromptRules()` + iOS `CoachRouteDecider` route advice to `*_meal_advice` / nutrition query handlers |
| Explicit consumption still logs | `log_food` / `log_workout` exempt from confidence clarify loop (`CoachIntentConfidenceGate`) |
| Ambiguous food references clarify | Clarification routes in `CoachRouteDecider`; resolver prompts in `CoachResponseBuilder` |
| Confidence gate prevents risky mutation | Low-confidence non-log intents → `confidence_clarify`; mutations require confirmation pipeline |

**Tests:** `CoachRoutingTests` (32 methods), `NutritionEstimateIntentRoutingTests`, `CoachInputHardeningTests`, `coachIntentSanitizer.test.ts`, prompt rules tests.

---

## 5. Compound food estimation result

**Status: PASS (automated); manual compound QA pending**

| Requirement | Verification |
|-------------|--------------|
| Compound meals decomposed | `FoodCompoundDishDetector` (iOS), `foodCompoundDish.ts` (backend), golden cases |
| Component totals sum correctly | `validateFoodExtraction` rejects mismatched totals; `normalizeFoodExtraction` repairs before mapping |
| Low confidence requires confirmation | `requiresConfirmation: true` in extraction schema; pending confirmation UI |
| Invalid JSON safely handled | Gateway validation + error categories; iOS `FoodEstimateResponseValidator` |

**Tests:**

| Suite | Tests |
|-------|-------|
| `foodEstimateExtraction.test.ts` | 7 |
| `foodCompoundDish.test.ts` | 8 |
| `foodLoggingGolden.test.ts` | 36 |
| `FoodCompoundDishDetectorTests.swift` | 5 |
| `FoodLoggingCompoundGoldenTests.swift` | 5 |
| `CoachFoodLoggingRegressionTests.swift` | 11 |

---

## 6. Singapore food fixture result

**Status: PASS (fixture integrity + range validation)**

| Item | Value |
|------|-------|
| Fixture file | `Docs/Coach/Fixtures/singapore_food_estimation_cases.json` |
| Case count | **50** |
| iOS tests | `SingaporeFoodEstimationFixtureTests.swift` (8 methods) — shape, uniqueness, reference meal ranges, compound prompt alignment |
| Backend tests | `singaporeFoodEstimationFixture.test.ts` (**206** parameterized assertions) |

Fixtures cover local/SG dishes (e.g. chicken rice, nasi lemak patterns) with calorie/macro ranges and confirmation requirements.

---

## 7. Context compaction result

**Status: PASS**

| Requirement | Verification |
|-------------|--------------|
| 24 KB transport limit | `CoachContextPacketV2Limits.defaultMaxEncodedBytes = 24_576` |
| Confirmed mutation/photo events protected | `CoachContextPacketV2SizeCompactor.protectedTimelineEventIDs` preserves food/water/weight/photo/workout events |
| Pending/rejected excluded from totals | Builder filters non-confirmed events; validator rule `pendingRejectedNotInTotals` |
| Context size observable | `CoachAccuracyObservabilityLogFormatter.sizeBucket()` + `compactionOccurred` flag |

**Tests:** `CoachContextPacketV2Tests`, `CoachContextPacketV2BuilderTests` (27 methods), `CoachContextCorrectnessValidatorTests`, `coachContextPacketV2.test.ts`.

---

## 8. SwiftData migration result

**Status: PASS (lightweight migration plan confirmed)**

| Version | Addition |
|---------|----------|
| V5 | `CoachTimelineEventEntity` |
| V6 | `CoachChatTranscriptMessageEntity` |

All stage transitions use `MigrationStage.lightweight` in `FormaModelMigration.swift`.

**Tests:** `CoachChatTranscriptPersistenceTests` (12 methods), `CoachTimelineStoreTests`, `CoachTimelineHardeningTests` (7 methods), timeline backfill idempotency covered in builder/store tests.

**Manual QA:** Section 6 of manual checklist (device upgrade paths) — **not executed in cloud agent**.

---

## 9. iOS/backend contract test result

**Status: PASS (Firebase); iOS BLOCKED in cloud agent**

| Suite | Tests | Scope |
|-------|-------|-------|
| `aiGateway.contract.test.ts` | 22 | Gateway route smoke + v2 context embedding |
| `coachContextPacketV2.test.ts` | 15 | Schema validation, sanitization, prompt embedding filters |
| `gatewayGuardrails.test.ts` | 8 | Auth, context parsing, error shaping |
| `nutritionSchema.test.ts` | 1 | Nullable nutrition estimate schema |
| `FormaAIBackendClientTests.swift` | 14 | iOS client encoding (not run in cloud) |
| `CoachV2ResponseHandlingTests.swift` | 11 | iOS v2 response decode (not run in cloud) |

Backend contract tests confirm: v2 schema acceptance, rejected/failed timeline filtering, privacy-safe log field extraction, malformed context → clear gateway errors.

---

## 10. Prompt snapshot result

**Status: PASS**

`coachContextPromptRules.test.ts` (8 tests) verifies presence of critical rule strings across endpoints:

- Shared v2 context rules (`coachContextV2Rules`)
- HealthKit availability rules (`coachContextHealthRules`)
- Classify intent rules (no chat-history nutrition copy, `linkedEntryId`)
- Estimate food rules (multi-component, no collapsed meals)
- Meal advice, edit/delete, daily review, meal image rules

Meal image rules include visible-food-only and required-context behavior (`analyzeMealImagePromptRules`).

---

## 11. Debug inspector result

**Status: PASS (redaction); DEBUG-only surfaces documented**

| Surface | Behavior |
|---------|----------|
| `redactedDebugDescription()` | Counts/modes only — no food names, chat text, or tokens; distinguishes `stepsToday=missing/0/unknown` and `trainingWorkouts=unknown/0` |
| `CoachAccuracyObservability` | Production-safe field buckets; DEBUG merges `contextSummary` from redacted description |
| `CoachAIRequestContextLogging` | Logs `packet.redactedDebugDescription()`, not raw JSON |
| `CoachContextCorrectnessValidator` | Validator logs use redacted packet summary |
| `PipelineDiagnosticsView` | **DEBUG-only** pipeline trace viewer; Release privacy QA must not expect raw user text in OSLog |

**Tests:** `CoachAccuracyObservabilityTests` (6), `CoachContextPacketV2Tests` (redaction + missing/zero labels), `CoachImageAnalysisDebugLogFormatterTests`.

---

## 12. Fallback packet result

**Status: PASS**

There is no separate minimal packet type. Fallback is expressed through:

- `generationMode: .degraded` when read failures, HealthKit denied/unavailable, or daily log load fails
- Partial sections still sent with `schemaVersion = 2`
- `missingData` booleans populated
- Local commands (water, weight, status) remain usable without gateway
- `CoachContextObservabilitySnapshot.fallbackPacketUsed` true when degraded

**Tests:** `CoachContextPacketV2BuilderTests`, degraded encoding test in `CoachContextPacketV2Tests`.

---

## 13. Deterministic status result

**Status: PASS**

`CoachDailyStatusBuilder` produces timeline-aware local status for progress/summary questions without a gateway call. Steps and training respect `missingData` — denied/unavailable signals become `nil`, not fabricated zeros.

**Tests:** `CoachDailyStatusBuilderTests` (8 methods), routing tests for local status handlers.

---

## 14. Edit/delete hardening result

**Status: PASS**

| Change | Detail |
|--------|--------|
| `CoachEntryReferenceResolver` | Resolves targets via explicit IDs, UUID selectors, meal-name match, confirmed timeline events |
| `linkedEntryId` required for delete | Unsafe meal-type delete fallback removed from `CoachMutationExecutor` |
| Supersedes links preserved | Edit/delete mutations record `supersedesEventId` via timeline lookup |
| Clarification on ambiguity | `CoachResponseBuilder.entryReferenceClarification()` |

**Tests:** `CoachEntryReferenceResolverTests` (11 methods), `CoachV2ResponseHandlingTests`, mutation timeline tests.

---

## 15. Photo hardening result

**Status: PASS (automated backend + iOS unit tests); device camera QA pending**

| Requirement | Verification |
|-------------|--------------|
| Context v2 required | `parseCoachContextForPrompt(body.context, {required: true})` in `mealImageAnalysis.ts` and gateway |
| Visible-food-only prompt | `analyzeMealImagePromptRules()` — no inference from chat history alone |
| No image bytes in timeline | Photo events store metadata; analysis pipeline uses session linking |
| Session linking | `CoachMealImageAIRequestBuilder` + `CoachMealPhotoContextV2Tests` |

**Tests:** `mealImageAnalysis.test.ts` (17), `CoachMealPhotoContextV2Tests` (12), `CoachMealImageAIRequestBuilderTests` (6).

---

## 16. Observability/privacy result

**Status: PASS**

Production telemetry via `CoachAccuracy` OSLog category:

| Event | Fields (examples) |
|-------|-------------------|
| `context_generated` | `contextSchemaVersion`, `contextGenerationMode`, `contextSizeBucket`, `timelineEventCount`, `healthIntelligencePresent`, `compactionOccurred`, `fallbackPacketUsed` |
| `route_selected` | `routeSelected`, `routeSource`, `classifierIntent`, `classifierConfidence`, `messageLength` |
| `endpoint_called` | `endpoint`, `responseValidationSuccess`, `backendErrorCategory`, `durationMs` |
| `mutation_executed` | `mutationKind`, `mutationSuccess`, `backendErrorCategory` |

**Never logged:** raw user text, food names, auth tokens, image bytes, full context JSON.

Backend: `coachContextLogFields()` + `gatewayErrorCategory()` in gateway completion/failure logs.

**Tests:** `CoachAccuracyObservabilityTests`, extended `CoachImageAnalysisDebugLogFormatterTests`, `coachContextPacketV2.test.ts` log field tests.

---

## 17. Test results

### Firebase (verified 2026-07-04, PR #103 branch)

```
cd functions && npm run build   ✅ PASS
cd functions && npm test        ✅ 333 tests PASS (11 suites)
```

| Suite | Tests |
|-------|-------|
| `singaporeFoodEstimationFixture.test.ts` | 206 |
| `foodLoggingGolden.test.ts` | 36 |
| `aiGateway.contract.test.ts` | 22 |
| `mealImageAnalysis.test.ts` | 17 |
| `coachContextPacketV2.test.ts` | 15 |
| `foodCompoundDish.test.ts` | 8 |
| `coachContextPromptRules.test.ts` | 8 |
| `foodEstimateExtraction.test.ts` | 7 |
| `gatewayGuardrails.test.ts` | 8 |
| `coachIntentSanitizer.test.ts` | 5 |
| `nutritionSchema.test.ts` | 1 |

### iOS (not run — no Xcode in cloud agent)

Targeted Coach suites ready for CI/local verification (**166** test methods across 14 suites listed in §2.1/§9):

```
xcodebuild -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 16" test
```

Priority classes: `CoachEntryReferenceResolverTests`, `CoachMealPhotoContextV2Tests`, `CoachAccuracyObservabilityTests`, `SingaporeFoodEstimationFixtureTests`, `FoodLoggingCompoundGoldenTests`, `CoachContextPacketV2BuilderTests`, `CoachRoutingTests`.

---

## 18. Build results

| Target | Command | Result |
|--------|---------|--------|
| Firebase Functions | `cd functions && npm run build` | ✅ **PASS** |
| Firebase Tests | `cd functions && npm test` | ✅ **PASS** (333/333) |
| iOS App | `xcodebuild -scheme "Fitness Coach" -destination "platform=iOS Simulator,name=iPhone 16" build` | ⚠️ **BLOCKED** — Xcode not available in cloud agent |
| iOS Tests | `xcodebuild ... test` | ⚠️ **BLOCKED** — requires local macOS CI |

---

## 19. Manual QA checklist status

**Document:** [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) (PR #101 — 75 unique case IDs across 12 sections + release checklist)

| Section | Cases | Automated coverage | Manual status |
|---------|-------|-------------------|---------------|
| 1. Health Intelligence default-on | HI-01…HI-06 | Partial (unit tests) | **Pending** |
| 2. Classifier advice-vs-log | CL-01…CL-08 | Partial (`CoachRoutingTests`) | **Pending** |
| 3. Compound food estimation | FD-01…FD-08 | Strong (golden + compound) | **Pending** |
| 4. Singapore food | SG-01…SG-06 | Strong (50-case fixtures) | **Pending** |
| 5. Context compaction | CP-01…CP-06 | Partial (unit tests) | **Pending** |
| 6. SwiftData migration | SD-01…SD-05 | Partial (unit tests) | **Pending** |
| 7. Photo context | PH-01…PH-08 | Partial (unit tests) | **Pending** |
| 8. Edit/delete reference | ED-01…ED-08 | Strong (resolver tests) | **Pending** |
| 9. Local deterministic status | LS-01…LS-06 | Partial (builder tests) | **Pending** |
| 10. Backend unavailable / auth | BE-01…BE-06 | Partial (gateway tests) | **Pending** |
| 11. Privacy / logging | PR-01…PR-08 | Partial (observability tests) | **Pending — requires Release build** |
| 12. Regression | RG-01…RG-06 | Partial | **Pending** |

**Release readiness checklist:** Not signed off — awaiting iOS CI green + manual QA pass on physical device (HealthKit, camera).

---

## 20. Remaining risks

| Risk | Severity | Mitigation path |
|------|----------|-----------------|
| iOS build/tests not verified in cloud agent | **High** | Run `xcodebuild` in macOS CI before merge |
| Manual QA (75 cases) not executed | **High** | Execute PR #101 checklist on device + Release build |
| LLM non-determinism on edge phrasing | Medium | Expand intent regression fixtures; monitor `route_selected` + `backendErrorCategory` |
| Compaction under extreme chat volume | Medium | Monitor `contextSizeBucket` >24k rate; tune protected-event policy if needed |
| Singapore fixtures validate ranges, not live model output | Medium | Periodic live API sampling against fixture prompts |
| DEBUG pipeline traces may show user text | Low | Release QA must confirm `PipelineDiagnosticsView` / verbose traces absent |
| Legacy env keys documented but not wired | Low | Document `FormaAbTest` as sole runtime toggle; remove stale env docs in follow-up |
| Open PR fragmentation (#98–#102) | Low | Merge #103 consolidation to supersede overlapping branches |

---

## 21. Recommended next sprint

1. **Merge gate:** Land PR #103 after macOS CI green on iOS build + full test suite.
2. **Manual QA execution:** Run all 75 cases in `COACH_ACCURACY_HARDENING_QA.md`; sign release checklist.
3. **Intent regression harness:** Promote durable classifier fixture suite (100+ cases) into CI on every PR touching routing.
4. **Live model eval:** Sample Singapore + compound prompts against production gateway; track component-count and confirmation rates.
5. **Observability dashboard:** Aggregate `CoachAccuracy` + Firebase gateway logs into release metrics (route distribution, error categories, context size buckets).
6. **Context inspector (optional):** If needed, merge DEBUG-only packet inspector from `cursor/coach-context-inspector-194c` with redaction parity tests.
7. **Documentation cleanup:** Merge PR #101 (QA) and PR #102 (architecture) alongside #103; align QA doc HI default note with `FormaAbTest.allEnabled`.

---

## Current Production Truth

After merge of PR #103 onto `main`:

### CoachContextPacketV2 is default

- All Coach AI gateway calls transport `CoachContextPacketV2` (`schemaVersion = 2`).
- Legacy `AIContext` struct remains deprecated; not used in active Coach flow.
- Backend validates and sanitizes via `parseCoachContextForPrompt` / `coachContextPacketV2.ts`.

### Health Intelligence default behavior

- `FormaAbTest.resolved` → `FormaAbTestSnapshot.allEnabled` when no test override.
- `coachContextEnabled = true` → `HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence == true`.
- HI loads into packet when snapshot composition succeeds; failures omit section and set `missingData` / `.degraded` without blocking Coach send.
- Steps: `0` is valid; missing only when value unavailable. Workouts: `0` = none today; `nil` = denied/unavailable.

### Timeline persistence status

- SwiftData V5: `CoachTimelineEventEntity` persisted via `SwiftDataCoachTimelineStore`.
- Timeline is audit/context layer — not nutrition source of truth.
- Backfill via `CoachTimelineBackfillService` (idempotent).
- Confirmed events protected during packet compaction; pending/rejected/failed excluded from totals and backend prompt embedding.
- Edit/delete mutations preserve supersedes links.

### Chat persistence status

- SwiftData V6: `CoachChatTranscriptMessageEntity` for transcript persistence.
- Recent chat included in v2 packet (`recentChatMessages` + transient `currentUserMessage`).
- Chat text is conversational continuity only — confirmed timeline + log services are factual.

### Backend v2 validation status

- All Coach endpoints accept v2 context; photo analysis **requires** context.
- Malformed context returns structured gateway errors with `backendErrorCategory`.
- Production logs use redacted field maps only.
- **333** automated backend tests passing.

### Remaining risks

- iOS CI + 75-case manual QA not yet signed off.
- LLM edge-case routing requires ongoing fixture expansion and production monitoring.
- Release privacy verification (no raw user content in OSLog) requires physical Release build QA.

---

*Report generated from code inspection and automated test runs on `cursor/coach-accuracy-production-hardening-194c`. iOS verification deferred to macOS CI/local execution.*
