# Coach Accuracy Hardening Sprint — Post-v2 Audit

**Generated:** 2026-07-04  
**Scope:** Audit only — no production code changes in this step.  
**Baseline doc:** [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md) (pre-v2 architecture reference)  
**Post-v2 reference:** [COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md](./COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md), [COACH_CONTEXT_PACKET_V2.md](./COACH_CONTEXT_PACKET_V2.md)

---

## Executive summary

Coach Timeline Context v2 is **in production** when AI is enabled: `CoachContextPacketV2` replaces legacy `AIContext`, timeline events are persisted, photo analysis sends full v2 context, and the gateway validates `meta.schemaVersion == 2`.

This audit confirms the **12 known post-v2 risks** against current source and tests. Most context/timeline gaps from the pre-v2 packet doc are **partially or fully addressed**; the remaining risks cluster around **feature-flagged Health Intelligence**, **classifier routing brittleness**, **model-dependent food estimation**, **payload compaction**, **migration/contract test depth**, and **operational/debug tooling**.

| Severity | Count | Themes |
|----------|-------|--------|
| **Critical** | 2 | Classifier misroute → wrong endpoint; no emergency context fallback on total build failure |
| **High** | 4 | HI default off; compound dish model quality; compaction drops events; weak iOS↔gateway contract tests |
| **Medium** | 4 | SwiftData migration coverage; prompt substring tests; HealthKit denied QA; photo without HI when flag off |
| **Low** | 2 | No context inspector UI; weight undo unsupported (documented) |

---

## Risk register (confirmed current state)

### 1. Health Intelligence Coach context is wired but default off

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — wired, default off** |
| **Severity** | High (accuracy impact when off; safe rollout when off) |

**Current state**

- `CoachContextPacketV2Builder` loads HI when `loadHealthIntelligence()` returns true (default: `HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence`).
- Production default: `FORMA_HEALTH_INTELLIGENCE_COACH_CONTEXT_ENABLED` → **`false`** (`HealthIntelligenceFeatureFlags.Defaults.coachContextEnabled`).
- Gate: `shouldCoachLoadHealthIntelligence = healthIntelligenceEnginesEnabled && healthIntelligenceCoachContextEnabled` (engines default **on**, coach context default **off**).
- When off: `makeHealthIntelligence()` returns `nil`; packet still includes training/steps/workouts from `HealthActivityQueryService` and `missingData` flags.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift` | Defaults and env keys |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | `makeHealthIntelligence`, `loadHealthIntelligence` injection |
| `Fitness Coach/Application/StateBuilders/Coach/CoachHealthIntelligenceContextBuilder.swift` | Snapshot → `CoachHealthIntelligenceContext` |
| `Fitness Coach/App/AppContainer.swift` | Wires builder + `healthIntelligenceLoadEnabled` closure into `CoachModel` |

**Tests covering**

| Test | Coverage |
|------|----------|
| `HealthIntelligenceFeatureFlagsTests` | Default coach context off; env override on |
| `HealthIntelligenceCompositionTests` | `shouldCoachLoadHealthIntelligence == false` at defaults |
| `CoachContextPacketV2BuilderTests.testIncludesHealthIntelligenceWhenSnapshotAvailable` | HI included when flag **explicitly** true in test harness |
| `CoachAIHealthIntelligenceIntegrationTests.testResolverSkipsSnapshotWhenHealthIntelligenceDisabled` | Resolver skips snapshot load when disabled |

**Gaps**

- No production integration test asserting **default-flag** packet has `healthIntelligence == nil` end-to-end through `AppContainer.makeCoachModel()`.
- No sprint metric for accuracy delta when coach HI flag is enabled.

---

### 2. Classifier can still misroute advice as food logging

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — intent drives route; misclassification still possible** |
| **Severity** | Critical |

**Current state**

- `CoachIntentRouter`: `.logFood` **always** → `.ai(.estimateFood)` regardless of classifier `action` draft quality.
- Mitigations exist but do **not** re-classify:
  - `CoachIntentConfidenceGate` strips spurious `action` on advice/lookup intents (`mealDecision`, `nutritionAdvice`, etc.).
  - Backend `sanitizeCoachIntentResult` drops `log_food` actions without populated `foodDraft`.
- **Gap:** High-confidence `log_food` on advisory phrasing (e.g. “should I log pizza tonight?”) still routes to `estimate-food`.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachRouteDecider.swift` | Guard → classify → confidence gate → router |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentRouter.swift` | Intent → route mapping |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentConfidenceGate.swift` | Confidence + action stripping |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CheapLLMIntentClassifier.swift` | Gateway classify call |
| `functions/src/coachIntentSanitizer.ts` | Server-side action sanitization |
| `functions/src/index.ts` | Classifier prompt/instructions |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachRoutingTests.testMealAdviceRoutesToCheapTier` | Correct `mealDecision` → meal advice (stubbed classifier) |
| `CoachInputHardeningTests.testHighConfidenceMealAdviceStillRoutes` | Advice intent routing |
| `CoachInputHardeningTests.testMediumConfidenceCalorieLookupWithSpuriousActionRoutesToMealAdvice` | Spurious `log_food` action stripped on lookup intent |
| `CoachInputHardeningTests.testVagueFoodStillUsesClassifier` | “log chicken rice” hits classifier |
| `coachIntentSanitizer.test.ts` | Drops empty `log_food` on `general_conversation` |
| `NutritionEstimateIntentRoutingTests.testLogFoodStillRoutesToEstimateFood` | By design: `logFood` → estimate |

**Gaps**

- **No test** for high-confidence **`log_food` misclassification** on advisory user text (golden transcript gap).
- No secondary intent validator or lexical “advisory question” guard after classify.
- Classifier prompt adherence tested via **substring** only (see risk 7).

---

### 3. Compound dish estimation still depends heavily on model quality

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — local guard blocks; API path is model-dependent** |
| **Severity** | High |

**Current state**

- `LocalNutritionEstimator.isBlockedCompoundFood` blocks patterns including `"chicken rice"`, `"fried rice"`, `"bowl of"`, etc.
- Blocked compounds → `LocalNoAPIGuard` passes to classifier → `log_food` → **`estimate-food`** (always re-estimates; classifier food draft not used as SSOT).
- v2 context helps (structured meals, timeline, `recentMealsStructured`) but does not constrain extraction geometry.
- Backend validates **shape** of extraction JSON (`foodEstimateExtraction`, golden fixtures); not live LLM accuracy.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/UseCases/Coach/Pipeline/LocalNutritionEstimator.swift` | Compound block list |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/LocalNoAPIGuard.swift` | Routes blocked food to classifier |
| `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift` | `estimateFood` orchestration |
| `functions/src/foodEstimateExtraction.ts` | Extraction schema + validation |
| `functions/test/fixtures/foodLoggingGoldenCases.ts` | Golden extractions (incl. `case2_chicken_and_rice`) |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachRoutingTests.testVagueFoodRoutesToEstimateFood` | “log chicken rice” → estimate (stub `logFood`) |
| `CoachInputHardeningTests.testVagueFoodStillUsesClassifier` | Local guard does not short-circuit compound |
| `foodLoggingGolden.test.ts` | Validator + mapping for structured golden extractions |
| `CoachFoodLoggingRegressionTests` | Regression harness (not vague-compound LLM eval) |

**Gaps**

- No golden case for **minimal prompt** `"chicken rice"` / `"log chicken rice"` without explicit grams.
- No iOS integration test asserting component count / calorie bands for compound logs.
- Classifier + estimate double-call still adds variance (classifier draft discarded for `log_food`).

---

### 4. Context compaction may drop useful older events on busy days

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — multi-layer limits; older non-protected events at risk** |
| **Severity** | High |

**Current state**

- Timeline selection cap: `CoachContextPacketV2Builder.defaultTimelineEventLimit = 20`.
- Transport clamp: `CoachContextPacketV2Limits` (gateway sanitizes to 20; iOS clamp 40 pre-send).
- `CoachContextPacketV2SizeCompactor`: if encoded size > 24 KB, drops **low-value** timeline events (system refresh, steps updated, etc.), truncates assistant chat, then assistant timeline summaries.
- **Protected:** today’s confirmed food/water/weight, pending confirmation, photo pipeline events, workout/steps (by type).
- **At risk:** older-day `userMessage` / `assistantMessage` timeline events, clarification history, non-today mutations when today is “busy” (> `sparseTodayEventThreshold = 4` events skips cross-day backfill priority).

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | Selection limit, sparse-day logic |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` (`CoachContextPacketV2TimelineSelector`) | Priority selection |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` (`CoachContextPacketV2SizeCompactor`) | Byte-limit eviction |
| `Fitness Coach/Domain/CoachTimeline/CoachTimelineCompactionPolicy.swift` | Persisted store compaction (separate from AI export) |
| `functions/src/coachContextPacketV2.ts` | Gateway array clamps |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachContextPacketV2BuilderTests.testPacketFitsWithinDefaultByteLimit` | Count caps after build |
| `CoachContextPacketV2BuilderTests.testFoodMemoryKeepsContextWithinByteLimit` | Compaction under load |
| `CoachContextPacketV2BuilderTests.testTimelineSelectorPrefersTodayConfirmedMutations` | Food kept over system refresh at limit=1 |
| `CoachContextPacketV2Tests` | Encoding size helpers |
| `coachContextPacketV2.test.ts` | Gateway sanitization / protected events |

**Gaps**

- **No test** simulating >20 mixed events on a busy day asserting **which** older user/clarification events are dropped.
- No test for `SizeCompactor` removing non-protected **userMessage** events under byte pressure.
- Implementation doc acknowledges: “Very chatty days may lose older timeline events” — still open.

---

### 5. SwiftData migration coverage for timeline/chat entities is incomplete

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — schema stages exist; migration test coverage thin** |
| **Severity** | Medium |

**Current state**

- `FormaSchemaV5`: adds `CoachTimelineEventEntity`.
- `FormaSchemaV6`: adds `CoachChatTranscriptMessageEntity`.
- `FormaMigrationPlan`: lightweight stages V1→…→V6 (no custom migration hooks).
- Runtime container: `FormaModelContainer` uses `FormaSchemaV6` + `FormaMigrationPlan`.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift` | Versioned schemas + stages |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelContainer.swift` | Container factory |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachTimelineEventEntity.swift` | Timeline persistence |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Entities/CoachChatTranscriptMessageEntity.swift` | Chat persistence |
| `Docs/Coach/COACH_TIMELINE_V2_MIGRATION.md` | Rollout notes |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachChatTranscriptPersistenceTests.testSchemaV6ContainerInitializesWithTranscriptEntity` | Fresh V6 in-memory insert/fetch |
| `CoachTimelinePersistenceTests` | Entity encode/decode round trip |
| `CoachTimelineStoreTests` | Store CRUD with in-memory container |
| `CoachChatTranscriptPersistenceTests` | Transcript store integration |

**Gaps**

- **No test** migrating a on-disk (or seeded) **V4/V5 store** with existing food logs → V6 with timeline + transcript entities preserved.
- No lightweight migration failure/recovery test (corrupt timeline row handling is tested at codec level, not migration stage level).
- Legacy `ChatMessageEntity` (V1) dropped from schema — no explicit migration test for deprecated chat table.

---

### 6. iOS-to-Firebase v2 contract tests are weak or missing

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — partial coverage; no round-trip schema lock** |
| **Severity** | High |

**Current state**

- **iOS `FormaAIBackendClientTests`:** HTTP plumbing (URLs, headers, timeouts, error mapping). Uses `CoachContextPacketV2.test` fixture but does **not** assert encoded request body matches gateway parser expectations.
- **Firebase `aiGateway.contract.test.ts`:** Mock HTTP integration per route with `minimalCoachContextV2` / `workoutAwareCoachContextV2` fixtures; asserts response **shape** (`intentResult`, `foodLogDrafts`, etc.), not full prompt/context fidelity.
- **Firebase `coachContextPacketV2.test.ts`:** Validates/sanitizes fixture packets (stronger than iOS client tests).

**Files involved**

| Path | Role |
|------|------|
| `Fitness CoachTests/FormaAIBackendClientTests.swift` | Client HTTP contract |
| `Fitness CoachTests/TestingSupport/CoachContextPacketV2TestFixtures.swift` | `CoachContextPacketV2.test` |
| `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift` | JSON encode + POST |
| `functions/test/aiGateway.contract.test.ts` | Gateway route smoke tests |
| `functions/test/coachContextPacketV2.test.ts` | v2 validate/parse |
| `functions/test/fixtures/coachContextPacketV2.ts` | TS fixtures |

**Tests covering**

| Test | Coverage |
|------|----------|
| `FormaAIBackendClientTests.testAllGatewayEndpointPathsIncludeV1AIPrefix` | Paths only |
| `CoachContextPacketV2Tests.testEncodesFullPacketRoundTrip` | iOS Codable round-trip |
| `CoachMealPhotoContextV2Tests` | Photo request includes v2 context JSON |
| `aiGateway.contract.test.ts` | End-to-end handler smoke with minimal v2 context |

**Gaps**

- No **shared golden JSON** consumed by both Swift and TypeScript test suites.
- No test decoding iOS-encoded packet in TS `validateCoachContextPacketV2` (cross-language contract).
- No CI assertion that iOS `CoachContextPacketV2.schemaVersion` matches `COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION` in functions.

---

### 7. Backend prompt tests may only check substrings instead of snapshots

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — substring `toContain` only** |
| **Severity** | Medium |

**Current state**

- `functions/test/coachContextPromptRules.test.ts` asserts rule **fragments** appear in exported rule strings (e.g. “Structured context is the source of truth”, “healthKitDenied”).
- No snapshot files, no hash lock, no test that assembled OpenAI request payloads include rules in stable order.
- iOS `AIPromptBuilder.swift` is reference-only; backend `coachContextPromptRules.ts` + `index.ts` are authoritative.

**Files involved**

| Path | Role |
|------|------|
| `functions/src/coachContextPromptRules.ts` | Shared v2 prompt rules |
| `functions/src/index.ts` | Task instructions assembly |
| `functions/test/coachContextPromptRules.test.ts` | Substring tests |

**Tests covering**

| Test | Coverage |
|------|----------|
| `coachContextPromptRules.test.ts` (8 cases) | Key phrases per endpoint rule bundle |

**Gaps**

- Prompt refactors can pass tests while materially changing model behavior.
- No snapshot of full `classifyCoachIntent` / `estimateFood` instruction blocks.
- No test linking `parseCoachContextForPrompt` output format to prompt examples.

---

### 8. No emergency fallback if CoachContextPacketV2 generation fails

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — degraded mode exists; no emergency minimal packet on hard failure** |
| **Severity** | Critical |

**Current state**

- `CoachContextPacketV2Builder.makeContext` is **non-throwing**; partial read failures increment `readFailures` and set `generationMode: .degraded`.
- `CoachContextCorrectnessValidator.validateAndCorrect` fixes inconsistencies before return.
- `CoachModel.prepareContextPacket` returns `nil` only when `contextPacketBuilder == nil` (AI disabled/miswired) → user sees `backendUnavailableResponse` — **not** a minimal v2 packet.
- `CoachContextPacketV2Builder()` with nil dependencies returns `.preview` packet (`testNilDependenciesDoNotCrash`) — usable as **test** stub, **not** wired as production fallback.
- No `try/catch` around builder with fallback to `CoachContextPacketV2.emergency(...)` factory.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | Build + degraded mode |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextCorrectnessValidator.swift` | Pre-send validation |
| `Fitness Coach/Features/Coach/Model/CoachModel.swift` | `prepareContextPacket`, `processCoachMessage` guard |
| `Fitness Coach/Infrastructure/AI/CoachContextPacketV2+Review.swift` | Review-scoped degraded packet (daily review only) |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachContextPacketV2BuilderTests.testNilDependenciesDoNotCrash` | Preview packet with empty deps |
| `CoachContextDegradedModeTests.testHealthKitDeniedSetsDegradedGenerationMode` | Degraded flag on HK denial |
| `CoachTimelineHardeningTests` (degraded section) | Same |

**Gaps**

- No production **`emergency`/`fallback` generation mode** with guaranteed `meta.schemaVersion: 2` + `currentUserMessage` + minimal `missingData`.
- No test that Coach still classifies/advises when SwiftData throws on all log reads (simulated).
- Uncaught runtime fault in builder would still fail the send path (no isolation).

---

### 9. No developer-facing context packet inspector or debug screen

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — logging only** |
| **Severity** | Low (dev velocity / QA friction) |

**Current state**

- `CoachContextPacketV2.redactedDebugDescription(maxLength:)` — truncated, redacted string for logs.
- `CoachAIRequestContextLogging` / `FormaPipelineTracer` — debug/trace pipelines.
- Settings has `DebugAuthDiagnosticsView` only — **no** Coach context inspector UI.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift` | `redactedDebugDescription` |
| `Fitness Coach/Infrastructure/AI/CoachAIRequestContextLogging.swift` | Request logging |
| `Fitness Coach/Infrastructure/Diagnostics/FormaPipelineTracer.swift` | Trace events |
| `Fitness Coach/Features/Settings/UI/DebugAuthDiagnosticsView.swift` | Unrelated debug UI |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachContextPacketV2Tests` | Redacted description format |

**Gaps**

- No DEBUG screen to view last packet (timeline count, missingData, generationMode, byte size).
- No export/share for QA repro (redacted JSON file).

---

### 10. Weight undo is unsupported

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — explicit user-facing message** |
| **Severity** | Low (known limitation) |

**Current state**

- `CoachMutationExecutor.executeUndo(.weight)` and `.last` when last mutation was weight return: *“Weight undo is not available yet. Log the corrected weight instead.”*
- Food/water undo implemented via `FitnessActionCenter` + `CoachMutationHistory`.
- Timeline records `undoPerformed` for food/water only.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/UseCases/Coach/CoachMutationExecutor.swift` | `executeUndo`, `executeUndoLastMutation` |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachMutationHistory.swift` | In-memory undo stack |
| `Fitness Coach/Application/UseCases/FitnessActionCenter.swift` | Food/water undo APIs (no weight undo) |

**Tests covering**

| Test | Coverage |
|------|----------|
| — | **None** asserting weight undo message or behavior |

**Gaps**

- No unit test for weight undo path.
- No timeline event distinguishing “weight correction requested” vs successful undo.
- Accuracy impact: model may assume undo worked if user says “undo my weight”.

---

### 11. HealthKit denied/no workout distinction needs stronger QA

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — flags implemented; E2E/manual QA weak** |
| **Severity** | Medium |

**Current state**

- v2 improved semantics:
  - Confirmed zero workouts: `training.workoutsToday == 0`, empty `workouts[]`.
  - Permission denied: `training.workoutsToday == nil`, `missingData.healthKitDenied`, `workoutPermissionDeniedOrUnavailable`, `generationMode: .degraded`.
- `CoachHealthGuidanceFormatter` / response builders use HI availability for copy.
- Manual QA checklist in `COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md` §Manual QA — items **unchecked** in doc.

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | `readWorkouts`, `makeMissingData` |
| `Fitness Coach/Application/StateBuilders/Coach/CoachHealthContextStatusResolver.swift` | Status resolution |
| `Fitness Coach/Application/Queries/HealthActivityQueryService.swift` | HK read + empty fallback |
| `functions/src/coachContextPromptRules.ts` | `coachContextHealthRules()` |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachContextPacketV2BuilderTests.testPermissionDeniedPopulatesGranularMissingDataFlags` | nil vs 0 distinction |
| `CoachContextPacketV2BuilderTests.testNoWorkoutDistinctFromUnknownWhenPossible` | 0 vs denied |
| `CoachContextDegradedModeTests` | Degraded on denial |
| `coachContextPromptRules.test.ts` | healthKitDenied rule substring |

**Gaps**

- No **`CoachModel` E2E** test with denied HK → meal advice copy does not claim “no workout today”.
- No simulator UI test / manual QA sign-off recorded.
- Repository read routing off vs on + denied permission matrix incomplete.

---

### 12. Photo v2 context works, but Health Intelligence may be absent when flag off

| Field | Detail |
|-------|--------|
| **Status** | **CONFIRMED — v2 packet attached; HI section omitted by default** |
| **Severity** | Medium |

**Current state**

- **Fixed vs pre-v2:** `CoachMealImageAIRequestBuilder.buildAnalysisRequest` attaches full `CoachContextPacketV2` (including `today`, `training`, timeline, structured meals).
- `CoachMealPhotoAnalyzer.performAnalysis` builds context via same `CoachContextPacketV2Builder` (no separate legacy path).
- With default flags: photo context includes HealthKit-derived training/steps but **`healthIntelligence: nil`** (same as text chat).
- `CoachAIActivityContextResolver` is used in `CoachModel` for text path activity hints; photo analyzer calls builder directly (HI still gated inside builder by flag).

**Files involved**

| Path | Role |
|------|------|
| `Fitness Coach/Application/UseCases/Coach/CoachMealPhotoAnalyzer.swift` | Context build + analyze |
| `Fitness Coach/Application/UseCases/Coach/CoachMealImageAIRequestBuilder.swift` | Request with `context` |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | Shared builder |
| `functions/src/mealImageAnalysis.ts` | Server-side image + context handling |

**Tests covering**

| Test | Coverage |
|------|----------|
| `CoachMealPhotoContextV2Tests` | schemaVersion 2, today macros, steps, workouts, structured meals in photo request |
| `analyzeMealImagePromptRules` (substring) | “Do not infer hidden foods from context” |

**Gaps**

- No `CoachMealPhotoContextV2Tests` case with **`loadHealthIntelligence: false`** asserting `healthIntelligence == nil` on wire.
- No test that photo advice quality fields (recovery, next best action) absent when flag off.

---

## Cross-cutting improvements since pre-v2 packet

These items from [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md) are **addressed in v2** (reduces severity of original audit):

| Pre-v2 gap | v2 status |
|------------|-----------|
| No event timeline | `CoachTimelineStore` + `timeline.recentEvents` |
| 5 chat turns only | Up to 12 `recentChatMessages` + persisted transcript |
| Photo omits AI context | Full v2 on `analyze-meal-image` |
| No pending vs confirmed | Pending bar events; rejected excluded from context |
| Steps/workout 0 vs denied conflated | `missingData` + nil vs 0 semantics |
| Chat in-memory only | `SwiftDataCoachChatTranscriptStore` |
| `commonFoods` empty | Populated by `CoachContextFoodMemoryBuilder` |

---

## Recommended implementation order

Priority balances **user-facing accuracy impact**, **failure safety**, and **testability**. No production code in this sprint step — order for subsequent PRs:

| Phase | Item | Risks | Rationale |
|-------|------|-------|-----------|
| **0** | Emergency/minimal v2 packet + CoachModel fallback | 8 | Prevents total AI outage; unlocks safe degradation |
| **1** | Classifier hardening: advisory disambiguation + golden misroute tests | 2 | Highest accuracy bug class; contained routing change |
| **1** | Cross-language v2 contract golden JSON (Swift encode → TS validate) | 6 | Stabilizes all downstream work |
| **2** | Compaction policy: protect clarification/user events; busy-day tests | 4 | Directly affects multi-turn accuracy |
| **2** | Compound food: prompt + validator tightening; vague “chicken rice” golden | 3 | High-frequency user input |
| **3** | Enable coach HI flag in staging + A/B metrics; photo path parity tests | 1, 12 | Flag already wired — measure before default on |
| **3** | SwiftData V4→V6 migration integration test | 5 | Release safety for existing users |
| **4** | Prompt snapshot tests (functions) | 7 | Cheap regression lock |
| **4** | HealthKit denied E2E CoachModel tests + QA sign-off | 11 | Closes semantics loop |
| **5** | DEBUG context packet inspector | 9 | Accelerates remaining tuning |
| **5** | Weight undo or explicit “correction flow” + tests | 10 | Lower urgency; UX/accuracy edge case |

---

## Expected files to modify (implementation sprint)

### iOS

| File | Likely change |
|------|----------------|
| `Fitness Coach/Features/Coach/Model/CoachModel.swift` | Emergency context fallback wiring |
| `Fitness Coach/Application/StateBuilders/Coach/CoachContextPacketV2Builder.swift` | Emergency factory, compaction priorities |
| `Fitness Coach/Infrastructure/AI/CoachContextPacketV2.swift` | `emergency` builder, generation mode |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachRouteDecider.swift` | Post-classify advisory guard |
| `Fitness Coach/Application/UseCases/Coach/Pipeline/CoachIntentConfidenceGate.swift` | Stronger misroute thresholds |
| `Fitness Coach/Application/UseCases/Coach/CoachMutationExecutor.swift` | Weight undo or correction messaging |
| `Fitness Coach/Health/HealthIntelligenceFeatureFlags.swift` | Staged default for coach context (if product approves) |
| `Fitness Coach/Infrastructure/Persistence/SwiftData/Store/FormaModelMigration.swift` | Custom migration if lightweight insufficient |
| `Fitness Coach/Features/Settings/UI/*` or new `CoachDebug/*` | Context inspector (DEBUG) |

### Firebase

| File | Likely change |
|------|----------------|
| `functions/src/index.ts` | Classifier/estimate prompt tweaks |
| `functions/src/coachContextPromptRules.ts` | Rule updates + snapshot stability |
| `functions/src/coachIntentSanitizer.ts` | Intent/advice boundary sanitization |
| `functions/src/foodEstimateExtraction.ts` | Compound portion rules |

### Tests & fixtures

| File | Likely change |
|------|----------------|
| `Fitness CoachTests/FormaAIBackendClientTests.swift` | Encode + schema assertions |
| `Fitness CoachTests/CoachRoutingTests.swift` | Misroute golden cases |
| `Fitness CoachTests/CoachContextPacketV2BuilderTests.swift` | Busy-day compaction, HI flag off photo parity |
| `functions/test/fixtures/coachContextPacketV2.ts` + new Swift mirror | Shared contract golden |
| `functions/test/coachContextPromptRules.test.ts` | Snapshot/hash tests |
| New `FormaModelMigrationTests.swift` | V4→V6 migration |

### Docs

| File | Likely change |
|------|----------------|
| `Docs/Coach/COACH_TIMELINE_CONTEXT_V2_QA.md` | Check off HK denied scenarios |
| `Docs/Coach/COACH_CONTEXT_PACKET_V2.md` | Emergency packet shape |

---

## Build and test commands

### iOS (macOS / Xcode)

```bash
open "Fitness Coach.xcodeproj"

# Build
xcodebuild -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build

# Full unit tests
xcodebuild -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  test

# Fast core plan (referenced in migration doc)
xcodebuild test -scheme "Fitness Coach" -testPlan Fast-Core \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

**Coach accuracy–relevant test classes**

```bash
# Run individually in Xcode test navigator, or:
xcodebuild test -scheme "Fitness Coach" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -only-testing:Fitness\ CoachTests/CoachContextPacketV2BuilderTests \
  -only-testing:Fitness\ CoachTests/CoachContextPacketV2Tests \
  -only-testing:Fitness\ CoachTests/CoachTimelineHardeningTests \
  -only-testing:Fitness\ CoachTests/CoachRoutingTests \
  -only-testing:Fitness\ CoachTests/CoachInputHardeningTests \
  -only-testing:Fitness\ CoachTests/CoachMealPhotoContextV2Tests \
  -only-testing:Fitness\ CoachTests/FormaAIBackendClientTests \
  -only-testing:Fitness\ CoachTests/CoachAIHealthIntelligenceIntegrationTests
```

### Firebase functions

```bash
cd functions && npm run build && npm test
```

**Coach accuracy–relevant suites:** `coachContextPacketV2.test.ts`, `coachContextPromptRules.test.ts`, `aiGateway.contract.test.ts`, `coachIntentSanitizer.test.ts`, `foodLoggingGolden.test.ts`

### Manual QA

Use [COACH_TIMELINE_CONTEXT_V2_QA.md](./COACH_TIMELINE_CONTEXT_V2_QA.md) (40 scenarios), prioritizing:

- HealthKit denied vs zero steps/workouts
- Busy-day multi-turn reference (“that lunch”, “same as breakfast”)
- Compound log (“log chicken rice”) + advice (“should I eat…”) routing
- Photo meal with HI flag off/on comparison

---

## Summary verdict

| # | Risk | Confirmed? | Severity | Ready to implement? |
|---|------|------------|----------|---------------------|
| 1 | HI wired, default off | Yes | High | Enable + measure (flag flip) |
| 2 | Classifier misroute to food log | Yes | Critical | Yes — routing + tests |
| 3 | Compound dish model-dependent | Yes | High | Yes — prompts + goldens |
| 4 | Compaction drops older events | Yes | High | Yes — policy + tests |
| 5 | Migration coverage incomplete | Yes | Medium | Yes — integration tests |
| 6 | Weak iOS↔Firebase contract tests | Yes | High | Yes — shared fixtures |
| 7 | Prompt substring-only tests | Yes | Medium | Yes — snapshots |
| 8 | No emergency context fallback | Yes | Critical | Yes — builder + CoachModel |
| 9 | No context inspector | Yes | Low | Yes — DEBUG UI |
| 10 | Weight undo unsupported | Yes | Low | Product decision |
| 11 | HK denied QA gap | Yes | Medium | Yes — E2E + QA sign-off |
| 12 | Photo v2 without HI when flag off | Yes | Medium | Flag + parity tests |

**Next step:** Implement Phase 0–1 from the recommended order in focused PRs; do not change production Coach UI until context/routing hardening tests are in place (per v2 architecture guidance).

---

*Audit complete. No production code modified.*
