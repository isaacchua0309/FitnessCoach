# Coach Accuracy Hardening Sprint — Implementation Summary

**Status:** Engineering summary (2026-07-04)  
**Baseline:** [COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md](./COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md)  
**Architecture reference:** [COACH_FULL_CONTEXT_PACKET.md](./COACH_FULL_CONTEXT_PACKET.md)  
**Manual QA:** [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md)

---

## 1. Executive summary

The Accuracy Hardening Sprint builds on Coach Timeline Context v2 to improve **routing correctness**, **compound food estimation**, **deterministic local status**, **edit/delete target resolution**, **Health Intelligence rollout defaults**, and **backend/iOS contract coverage** — without changing the core boundary that SwiftData nutrition logs remain authoritative and the timeline is an audit/context layer.

**CONFIRMED on `main` (2026-07-04):**

- **`FormaAbTest`** is the single source of truth for feature gates; production defaults use `FormaAbTestSnapshot.allEnabled`, which enables HI foundation, engines, UI, **Coach context**, sync, and Coach AI parsing.
- **`CoachIntentConfidenceGate`** no longer blocks `log_food` / `log_workout` at medium/low confidence — those intents defer to dedicated AI + confirmation pipelines.
- **Backend food extraction** validates multi-component meals and rejects collapsed single-component responses when the user lists multiple ingredients.
- **Gateway hardening** adds auth smoke script coverage, nutrition estimate schema fixes, and expanded Jest tests.
- **Local compound guard** (`LocalNutritionEstimator.blockedCompoundPatterns`) forces AI estimation for dishes like `chicken rice` and `nasi lemak`.
- **`CoachEntryReferenceResolver`** enriches edit/delete actions with `linkedEntryId` from explicit IDs, UUID selectors, meal-name matches, and confirmed timeline events.
- **`CoachDailyStatusBuilder`** produces timeline-aware deterministic status without a gateway call.
- **Context compaction** (`CoachContextPacketV2SizeCompactor`) enforces the 24 KB transport limit with protected mutation/photo event types.

**PARTIAL / in-flight (not confirmed merged to `main` at time of writing):**

- Production **`CoachAccuracyObservability`** OSLog category (open PR).
- Dedicated **`CoachEntryReferenceResolverTests`** suite (open PR).
- Expanded meal-photo prompt hardening beyond existing `analyzeMealImagePromptRules()` (open PR).

---

## 2. What changed

| Area | Primary files | Outcome |
|------|---------------|---------|
| Feature gates | `FormaAbTest.swift`, `HealthIntelligenceFeatureFlags.swift` | Centralized defaults; HI Coach context enabled in `allEnabled` snapshot |
| Classifier routing | `CoachIntentConfidenceGate.swift`, `CoachRouteDecider.swift` | `log_food` reaches `estimate-food`; advice intents stay non-mutating |
| Local guard | `LocalCommandParser.swift`, `LocalNutritionEstimator.swift` | Volume strings like `300ml milk` no longer misroute to water |
| Compound food (backend) | `foodEstimateExtraction.ts`, `index.ts` | Component validation, repair retry, golden fixtures |
| Compound food (iOS) | `CoachRoutingTests.swift`, `CoachFoodLoggingRegressionTests.swift` | Regression coverage for `log chicken rice` → `ai_estimate_food` |
| Nutrition endpoints | `index.ts`, `FoodDraft.swift`, `FoodLogDraft.swift` | Strict nullable schema; `mealType` `"null"` normalization |
| Entry resolution | `CoachAIResponseContextAdapter.swift`, `CoachAIRouteHandler.swift` | `enrichAction` before edit/delete confirmation |
| Daily status | `CoachDailyStatusBuilder.swift`, `CoachResponseBuilder.swift` | Local `.status` / `daily_summary` without API |
| Context transport | `CoachContextPacketV2Builder.swift`, `CoachContextPacketV2SizeCompactor` | Degraded mode + byte-limit compaction |
| SwiftData | `FormaModelMigration.swift` | V5 timeline entity, V6 transcript entity (lightweight) |
| Backend contract tests | `coachContextPacketV2.test.ts`, `gatewayGuardrails.test.ts`, `foodEstimateExtraction.test.ts`, `nutritionSchema.test.ts` | Privacy-safe log fields, schema, extraction validation |
| Prompt rule tests | `coachContextPromptRules.test.ts` | Endpoint rule string presence |
| Developer diagnostics | `PipelineDiagnosticsView.swift`, `HealthIntelligenceDiagnosticsView.swift` | DEBUG pipeline traces + HI snapshot verification |

---

## 3. Health Intelligence default-on behavior

**CONFIRMED:** `FormaAbTest.resolved` returns `FormaAbTestSnapshot.allEnabled` when `testOverride` is nil (`FormaAbTest.swift`). That snapshot sets:

- `foundationEnabled = true`
- `enginesEnabled = true`
- `uiEnabled = true`
- **`coachContextEnabled = true`**
- `syncEnabled = true`

**CONFIRMED:** `HealthIntelligenceFeatureFlags.shouldCoachLoadHealthIntelligence` delegates to `FormaAbTest.HealthIntelligence.shouldCoachLoad`, which requires `enginesEnabled && coachContextEnabled` (`HealthIntelligenceFeatureFlags.swift`).

**CONFIRMED:** `HealthIntelligenceFeatureFlagsTests.testDefaultsAreAllEnabled` asserts Coach context and `shouldCoachLoadHealthIntelligence` are true under default snapshot.

**CONFIRMED:** Legacy env keys (`FORMA_HEALTH_INTELLIGENCE_*`) remain documented in `HealthIntelligenceFeatureFlags.EnvironmentKey` but **`snapshot(environment:)` ignores the environment map** — runtime toggling via process env is **not** wired after the `FormaAbTest` migration.

**Behavior when HI loads:**

- `CoachContextPacketV2Builder` includes `healthIntelligence` when `loadHealthIntelligence()` returns true and snapshot composition succeeds.
- `CoachHealthIntelligenceContextBuilder` maps snapshot fields; prompt text excludes raw HRV ms / BPM (`CoachHealthIntelligenceContextTests`).
- When HealthKit denied or snapshot unavailable: section omitted, `missingData` flags set, `generationMode` may become `.degraded`.

**Toggle off in tests:** `FormaAbTest.testOverride` with `coachContextEnabled = false` (`HealthIntelligenceFeatureFlagsTests.testCoachContextRequiresExplicitEnable`).

---

## 4. Context fallback behavior

There is **no separate minimal fallback packet type**. Fallback behavior is expressed through **`generationMode`** and partial sections.

**CONFIRMED — degraded mode triggers** (`CoachContextPacketV2Builder.resolveGenerationMode`):

- Any read failure counter > 0
- Health access denied or unavailable
- Daily log service available but today's log failed to load

When degraded:

- Packet still sends with `meta.schemaVersion = 2`
- `missingData` booleans populated via builder reads
- Local commands (water, weight, status) remain usable (`COACH_TIMELINE_V2_MIGRATION.md` behavior)

**CONFIRMED — review-scoped compact packet:** `CoachContextPacketV2.reviewContext(from:)` builds a reduced packet with `generationMode: .degraded` and `sources: ["dailyReview"]` for `generate-daily-review` only (`CoachContextPacketV2+Review.swift`).

**CONFIRMED — individual source failures:** `CoachContextPacketV2Builder` catches per-source read errors, increments `readFailures`, and continues assembly rather than crashing the caller.

**NOT CONFIRMED:** A dedicated `fallbackPacketUsed` production log field (planned in observability PR, not on `main`).

---

## 5. Classifier hardening

### Advice vs log separation

**CONFIRMED backend rules** (`coachContextPromptRules.ts` → `classifyCoachIntentPromptRules`, `estimateFoodPromptRules`):

- Prefer `nutrition_estimate_query` for calorie/macro questions without logging.
- Use `log_food` only when the user wants to record food; set `requiresAppMutation: true`.
- Do not copy nutrition from chat history into log actions.

**CONFIRMED iOS routing** (`CoachRouteDecider`, `CoachIntentRouter`):

| Intent family | Handler (typical) | Gateway |
|---------------|-------------------|---------|
| `nutrition_estimate_query`, `calorie_lookup`, `macro_lookup` | `cheap_nutrition_estimate` | `/v1/ai/generate-nutrition-estimate` |
| `nutrition_comparison_query` | `cheap_nutrition_comparison` | `/v1/ai/generate-nutrition-comparison` |
| `nutrition_advice`, `meal_decision`, `workout_advice` | `*_meal_advice` | `/v1/ai/generate-meal-advice` |
| `log_food` | `ai_estimate_food` | `/v1/ai/estimate-food` |
| `daily_summary` | `local_command` | *(none)* |

Tests: `CoachRoutingTests`, `NutritionEstimateIntentRoutingTests`.

### Confidence gate fix (2026-07-04)

**CONFIRMED:** `CoachIntentConfidenceGate.defersMutationToDedicatedPipeline` returns true for `.logFood` and `.logWorkout`. Medium/low confidence **does not** clarify-block those intents because they always pass through estimate/confirmation before persisting (`CoachIntentConfidenceGate.swift`, commit `f5fc0f3`).

**CONFIRMED:** Medium/low confidence **still blocks** other mutations (e.g. direct water/weight actions from classifier) when `requiresAppMutation` or `action != nil`.

Thresholds: `highThreshold = 0.70`, `mediumThreshold = 0.45`.

### Local guard improvements

**CONFIRMED:** `LocalCommandParser` / routing tests ensure `300ml of milk` and juice strings do not route to local water logging (`CoachRoutingTests.testMilkVolumeDoesNotRouteToLocalWater`).

---

## 6. Compound food improvements

### iOS local guard

**CONFIRMED:** `LocalNutritionEstimator.blockedCompoundPatterns` includes `chicken rice`, `economy rice`, `mixed rice`, `nasi lemak`, `fried rice`, `bowl`, fast-food tokens, etc. Matches force AI path (`LocalNutritionEstimator.swift`).

**CONFIRMED:** `CoachRoutingTests.testVagueFoodRoutesToEstimateFood` — `"log chicken rice"` → `ai_estimate_food`.

### Backend extraction

**CONFIRMED:** `validateFoodExtraction` enforces:

- Multiple listed ingredients → minimum component count
- Totals ≈ sum of components (ratio + absolute tolerances)
- Collapsed single-component rejection (`foodEstimateExtraction.test.ts`)

**CONFIRMED:** `countListedIngredients` parses bullet/line-separated ingredient lists.

**CONFIRMED:** Gateway `estimate-food` instructions require each visible distinct food as its own component (`functions/src/index.ts` food estimate prompt block).

### Golden fixtures

**CONFIRMED:** `functions/test/fixtures/foodLoggingGoldenCases.ts` + `foodLoggingGolden.test.ts` — multi-ingredient bowl case with collapsed vs valid extractions.

---

## 7. Singapore / local food fixtures

**CONFIRMED — no dedicated Singapore module.** Regional dishes are covered as **compound foods**:

| Mechanism | Examples |
|-----------|----------|
| `blockedCompoundPatterns` | `chicken rice`, `economy rice`, `mixed rice`, `nasi lemak` |
| Classifier/edit prompt examples | `"delete the chicken rice"` in backend rules |
| Product copy | `FormaProductCopy` food placeholder `"e.g. chicken rice"` |
| Routing tests | `"log chicken rice"`, timeline regression strings |

**NOT CONFIRMED:** Dedicated `nasi lemak` golden fixture in `foodLoggingGoldenCases.ts` (patterns covered via iOS blocked list + general multi-ingredient golden case).

---

## 8. Context compaction policy

**File:** `CoachContextPacketV2SizeCompactor` in `CoachContextPacketV2Builder.swift`

**CONFIRMED limits** (`CoachContextPacketV2Limits`):

| Limit | Value |
|-------|-------|
| `defaultMaxEncodedBytes` | 24,576 (24 KB) |
| `maxTimelineEvents` | 40 |
| `maxChatMessages` | 12 |
| `maxRecentMeals` | 10 |
| `maxCommonFoods` | 10 |

**CONFIRMED compaction order:**

1. `clampedForTransport()` prefix limits
2. Truncate **assistant** chat messages to 80 characters
3. Remove **low-value system events** (not in protected set) until under byte limit
4. Truncate assistant timeline summaries to 60 characters; strip `compactPayload`

**CONFIRMED protected types (today's mutations prioritized):** `foodLogged`, `waterLogged`, `weightLogged`, `pendingConfirmationCreated`, photo analysis events, `workoutDetected`, `stepsUpdated`.

**CONFIRMED low-value removable types:** `systemRefresh`, `contextGenerated`, `healthDataUnavailable`, non-today `stepsUpdated`, generic system-attribution events.

**CONFIRMED validator integration:** `CoachContextCorrectnessValidator` rule `contextSizeBelowThreshold` can trigger additional clamping.

**Guarantee (CONFIRMED):** Outbound JSON is clamped to ≤ 24 KB after compaction when builder completes successfully; gateway rejects malformed oversize bodies separately (`gatewayGuardrails.ts`).

---

## 9. SwiftData migration hardening

**CONFIRMED:** `FormaMigrationPlan` (`FormaModelMigration.swift`):

| Version | Addition |
|---------|----------|
| V5 (5.0.0) | `CoachTimelineEventEntity` |
| V6 (6.0.0) | `CoachChatTranscriptMessageEntity` |

All stages use **`MigrationStage.lightweight`**.

**CONFIRMED tests:**

- `CoachChatTranscriptPersistenceTests.testSchemaV6ContainerInitializesWithTranscriptEntity`
- `CoachTimelinePersistenceTests`, `CoachTimelineStoreTests` entity mapping

**CONFIRMED runtime behavior:**

- `CoachTimelineBackfillService` hydrates timeline from existing logs on first context build
- Unknown payload types decode safely via `CoachTimelineEventPayloadCodec` (see `CoachTimelineDomainTests`)

**PARTIAL:** Full upgrade E2E from pre-V5 production builds — documented in migration guide, limited automated coverage.

---

## 10. iOS ↔ backend contract tests

### Backend (Jest)

| Test file | Covers |
|-----------|--------|
| `coachContextPacketV2.test.ts` | Schema validation, sanitization, **`coachContextLogFields` privacy**, timeline/meal export rules |
| `coachContextPromptRules.test.ts` | Shared + per-endpoint prompt rule strings |
| `foodEstimateExtraction.test.ts` | Component count, collapse rejection, `normalizeMealType` |
| `foodLoggingGolden.test.ts` | Golden extraction fixtures |
| `nutritionSchema.test.ts` | Strict nullable nutrition/comparison action payloads |
| `gatewayGuardrails.test.ts` | Body size, auth, normalization paths |

### iOS (XCTest)

| Test file | Covers |
|-----------|--------|
| `CoachContextPacketV2Tests.swift` | Encoding, limits, **`redactedDebugDescription`** |
| `CoachContextPacketV2BuilderTests.swift` | Full assembly, HI on/off, backfill |
| `CoachMealPhotoContextV2Tests.swift` | Photo requests require schema v2 context |
| `FormaAIBackendClientTests.swift` | Client request shape / error mapping |
| `CoachRoutingTests.swift` | Handler + tier expectations |
| `CoachInputHardeningTests.swift` | Input edge cases + confidence routing |
| `CoachV2ResponseHandlingTests.swift` | **`CoachEntryReferenceResolver.enrichAction`** |
| `CoachDailyStatusBuilderTests.swift` | Deterministic status copy |
| `HealthIntelligenceFeatureFlagsTests.swift` | **`FormaAbTest` default-on snapshot** |

---

## 11. Prompt snapshot tests

**CONFIRMED:** `functions/test/coachContextPromptRules.test.ts` asserts required rule **substrings** exist for:

- `coachContextV2Rules`, `coachContextHealthRules`
- `classifyCoachIntentPromptRules`, `estimateFoodPromptRules`, `mealAdvicePromptRules`
- `analyzeMealImagePromptRules`, `editDeletePromptRules`, `dailyReviewPromptRules`

**NOT CONFIRMED:** Full-file prompt snapshot diffing (no committed `.snap` artifacts). Tests are **presence/regression strings**, not complete prompt hash locks.

---

## 12. Developer context inspector

**CONFIRMED DEBUG tooling** (Settings → Developer, when `FormaAbTest.Build.includesDeveloperTools`):

| Tool | File | Purpose |
|------|------|---------|
| Pipeline traces | `PipelineDiagnosticsView.swift` | `FormaPipelineTracer` summaries + event detail |
| Health intelligence snapshot | `HealthIntelligenceDiagnosticsView.swift` | Engine composition verification (safe summary, no raw HK samples) |
| Auth diagnostics | `AuthDiagnosticsView.swift` | Session state |

**CONFIRMED log helpers (all builds):**

- `CoachContextPacketV2.redactedDebugDescription()` — counts/modes, not meal names
- `CoachAIRequestLogFormatter.redactedContextFields(from:)` — schema + timeline count + redacted summary

**NOT CONFIRMED:** A dedicated in-app **Coach Context Packet Inspector** UI that renders the full v2 JSON tree. Use DEBUG pipeline traces + redacted log lines instead.

---

## 13. Deterministic daily status

**CONFIRMED:** `CoachDailyStatusBuilder` + `CoachResponseBuilder.status(from:)` assemble local copy from:

- `DailyLog` nutrition/hydration totals
- Confirmed timeline meals (excludes estimates/rejects — `nonConsumedFoodTimelineTypes`)
- Optional steps/training when not blocked by `missingData`
- Optional HI snippet when present in hints

**CONFIRMED routing:** `daily_summary` classifier intent and local `"how many calories left"` / `"status"` map to `local_command` without gateway (`CoachRoutingTests.testCaloriesLeftStaysLocal`, `CoachDailyStatusBuilderTests`).

**CONFIRMED parity target:** `CoachContextCorrectnessValidator.calorieTolerance = 5` kcal vs Today aggregates.

---

## 14. Edit/delete reference resolution

**CONFIRMED:** `CoachEntryReferenceResolver` (`CoachAIResponseContextAdapter.swift`):

1. Explicit `linkedEntryId` on action
2. UUID string in `targetEntrySelector`
3. Meal name contained in selector → last matching `recentMealsStructured` entry
4. `linkedTimelineEventId` from last **confirmed** timeline event for entry

**CONFIRMED wiring:** `CoachAIRouteHandler` calls `enrichAction(_:context:)` before edit/delete pending confirmation.

**CONFIRMED backend rules:** `editDeletePromptRules()` — resolve from confirmed timeline + `linkedEntryId`; never delete from assistant chat alone.

**PARTIAL / RISK:** `CoachMutationExecutor.executeDeleteAction` still has **meal-type fallback** when `linkedEntryId` is nil (`deleteFood(mealType:)`). Resolver reduces reliance on this path but does not remove it.

**CONFIRMED test:** `CoachV2ResponseHandlingTests` enriches action with `linkedEntryId` from structured meals.

**NOT CONFIRMED on `main`:** Standalone `CoachEntryReferenceResolverTests.swift` (open PR).

---

## 15. Photo accuracy improvements

**CONFIRMED baseline (pre-sprint v2 + current rules):**

- `analyze-meal-image` **requires** v2 context (`CoachMealImageAIRequestBuilder`, `mealImageAnalysis.ts`)
- Response always includes `needsUserReview: true`
- Prompt rules: image-first, visible foods only, do not infer hidden foods from context (`analyzeMealImagePromptRules`, `mealImageAnalysis.ts`)
- No image bytes in timeline payloads
- Clarification loop via `clarificationAsked` / `clarificationAnswered` events

**CONFIRMED tests:** `CoachMealPhotoContextV2Tests.swift`, `coachContextPromptRules.test.ts` analyze-meal-image rules.

**PARTIAL:** Additional iOS mapper surfacing of assumptions/clarifications — verify against open meal-photo accuracy PR before claiming merged.

---

## 16. Observability / privacy logging

### Confirmed on `main`

| Mechanism | Category / location | Content |
|-----------|---------------------|---------|
| `CoachAIRequestLogFormatter` | DEBUG gateway trace fields | `redactedDebugDescription()`, schema, timeline count |
| `coachContextLogFields()` | Firebase Functions logs | Counts/buckets only — no meal names |
| `CoachContextPacketV2.redactedDebugDescription()` | Validator warn logs | Privacy-safe single line |
| DEBUG loggers | `CoachFoodEstimate`, `CoachImageAnalysis`, `PipelineTrace` | Gated by `FormaAbTest.Coach.*` flags |

### Not confirmed on `main`

| Mechanism | Status |
|-----------|--------|
| `CoachAccuracyObservability` OSLog (`Forma` / `CoachAccuracy`) | Open PR — production-safe route/context/endpoint/mutation metrics |
| Expanded gateway `backendErrorCategory` on failure logs | Partially in recent gateway commits; full observability stack in open PR |

**CONFIRMED privacy rule:** Production must not log raw user messages, food names, image base64, or auth tokens in Coach AI paths — enforced today via redaction helpers and summary-only backend fields.

---

## 17. Tests added

### Sprint commits on `main`

- `HealthIntelligenceFeatureFlagsTests` — `FormaAbTest` all-enabled defaults
- `CoachRoutingTests` — medium-confidence `log_food`, milk/juice not water, chicken rice → estimate
- `CoachInputHardeningTests` — confidence gate + log food routing
- `FoodLogDraftTests` — meal type normalization
- `FormaAIBackendClientTests` — client contract additions
- `functions/test/foodEstimateExtraction.test.ts` — extraction validation
- `functions/test/nutritionSchema.test.ts` — nullable payload keys
- `functions/test/gatewayGuardrails.test.ts` — gateway normalization/auth
- `functions/scripts/smoke-ai-gateway-auth.mjs` — auth smoke script

### Pre-sprint v2 tests still authoritative

See [COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md](./COACH_TIMELINE_CONTEXT_V2_IMPLEMENTATION.md) § test inventory.

---

## 18. Manual QA checklist

**CONFIRMED:** [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) — **70 manual cases** across 12 sections (HI, classifier, compound/SG food, compaction, migration, photo, edit/delete, local status, backend errors, privacy, regression) plus release readiness checklist.

Cross-reference baseline: [COACH_TIMELINE_CONTEXT_V2_QA.md](./COACH_TIMELINE_CONTEXT_V2_QA.md) scenarios 1–40.

---

## 19. Remaining risks

| Risk | Severity | Evidence | Mitigation direction |
|------|----------|----------|---------------------|
| Classifier misroutes advice vs log on edge phrasing | High | Partial test coverage | Expand `CoachRoutingTests` + prompt examples |
| Compound estimate quality varies by model | High | Golden tests validate shape, not kcal truth | Human QA + sanity validator warnings |
| Context compaction drops older system events | Medium | `CoachContextPacketV2SizeCompactor` | Monitor byte buckets; smarter summarization |
| Delete meal-type fallback when resolver misses | Medium | `CoachMutationExecutor.executeDeleteAction` | Require `linkedEntryId`; remove meal-type delete |
| No dedicated Coach context inspector UI | Low | Only DEBUG traces | Build inspector or expand observability logs |
| Legacy env HI toggles unused | Low | `snapshot(environment:)` ignores env | Document `FormaAbTest` as sole runtime gate |
| Weight undo not implemented | Low | `CoachMutationExecutor` | Product decision |
| Timeline backfill dedup edge cases | Low | 60s window | Tighten dedup keys |
| Observability PR not merged | Medium | No `CoachAccuracy` category on main | Merge #100 and validate Release logs |
| Full prompt snapshot locking | Low | Substring tests only | Add snapshot files if prompt drift becomes frequent |

---

## 20. Next sprint recommendation

1. **Merge observability PR** — ship `CoachAccuracyObservability` + gateway summary fields; validate Release console audit (PV-01–PV-03 in QA doc).
2. **Merge edit/delete hardening PR** — dedicated resolver tests; remove meal-type delete fallback when `linkedEntryId` absent.
3. **Merge meal-photo accuracy PR** — verify image-first rules in production traces; extend `CoachMealPhotoContextV2Tests`.
4. **Classifier golden set expansion** — add iOS fixtures mirroring backend `foodLoggingGoldenCases` for advice-vs-log utterances.
5. **Context inspector (DEBUG)** — optional Settings screen showing `redactedDebugDescription()` + byte bucket after `makeContext`.
6. **Compaction telemetry** — log `compactionOccurred` in production-safe logger once observability lands.
7. **Manual QA execution** — complete [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) release checklist before App Store submission.

---

## Related PRs / branches (informational)

| Branch / PR | Topic | Merge status |
|-------------|-------|--------------|
| `main` @ `91b7e3e` | FormaAbTest, classifier fix, gateway/schema | **Merged** |
| #100 (observability) | `CoachAccuracyObservability` | Open at doc time |
| #98 (edit/delete) | Resolver tests + meal-type delete removal | Open at doc time |
| #99 (meal photo) | Photo prompt + mapper hardening | Open at doc time |
| #101 (QA doc) | Manual QA checklist | Open at doc time |

Verify merge status before treating open PR items as production truth.
