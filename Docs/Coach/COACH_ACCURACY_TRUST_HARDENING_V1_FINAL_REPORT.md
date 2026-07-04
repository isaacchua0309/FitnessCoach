# Coach Accuracy + Trust Hardening v1 — Final Sprint Report

**Date:** 2026-07-04  
**Sprint:** Coach Accuracy + Trust Hardening v1  
**Branches:** `cursor/nutrition-sanity-hardening-64df` (PR #153), `cursor/meal-photo-trust-hardening-64df` (PR #154)  
**Context schema:** `CoachContextPacketV2.meta.schemaVersion == 2` (unchanged)  
**Audience:** Engineering, QA, release engineering

**Related docs:**

- [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) — manual QA matrix (70 cases)
- [COACH_ACCURACY_HARDENING_IMPLEMENTATION.md](./COACH_ACCURACY_HARDENING_IMPLEMENTATION.md) — prior accuracy sprint architecture
- [COACH_ACCURACY_HARDENING_FINAL_REPORT.md](./COACH_ACCURACY_HARDENING_FINAL_REPORT.md) — prior accuracy sprint verification
- [COACH_CONTEXT_PACKET_V2.md](./COACH_CONTEXT_PACKET_V2.md) — transport packet (unchanged in v1)
- [CoachNutritionEstimateCards.md](../CoachNutritionEstimateCards.md) — estimate card UI
- [BackendAPI.md](../BackendAPI.md) — gateway endpoints

---

## 1. Problem statement

Coach food estimates — especially vague text (`log chicken rice`), photo-based meals, and compound Singapore hawker dishes — were presented with **deceptively high confidence** and **point-calorie precision** that did not match real uncertainty. Users could confirm and log estimates that were:

- Under-estimated for normal portions (e.g. chicken rice below 350 kcal)
- Collapsed into a single generic component when multiple ingredients were listed
- Missing visible trust signals (assumptions, ranges, clarification prompts)
- Auto-committed in edge cases where confirmation should always be required (photo estimates)

Additionally, advice/lookup phrasing (`how many calories in X`, `estimate X but don't log`) could be misclassified as `log_food`, creating unwanted pending logs.

---

## 2. Why this sprint exists

The prior **Coach Accuracy Hardening** sprint (Timeline Context v2, compound decomposition, classifier gates, entry resolver) established routing and context correctness. **Trust Hardening v1** closes the gap between *correct routing* and *honest presentation*:

| Gap | v1 response |
|-----|-------------|
| Point estimates imply certainty | Calorie **ranges** by confidence level |
| Users cannot see model assumptions | **assumptions[]** and **uncertaintyReasons[]** on every estimate |
| Vague dishes log too low | **NutritionSanityValidator** dish floors + downgrade/clarify/block |
| Photo meals feel authoritative | **MealImageAnalysisTrustPolicy** caps confidence, widens ranges, detects scenarios |
| Advice misrouted to logging | **CoachIntentPhraseGuard** + `isEstimateWithoutLogging` |
| No regression mapping for trust flows | **CoachAccuracyTrustRegressionTests** + Firebase regression suite |

**Product principle:** Estimates are **reviewed commitments**, not silent mutations. Every food estimate path ends in confirmation unless the user explicitly declines logging.

---

## 3. Summary of changes

### iOS (Swift)

| Area | Key files | Outcome |
|------|-----------|---------|
| Trust data model | `FoodLogDraft.swift`, `AIContracts.swift` | Trust fields on meal drafts and photo analysis contracts |
| Calorie ranges | `FoodCalorieRange.swift` | Derive, resolve, widen ranges by confidence |
| Text estimate sanity | `NutritionSanityValidator.swift` | Macro repair, SG dish floors, hidden oil/sauce, clarification policy |
| Text response validation | `FoodEstimateResponseValidator.swift` | Trust-field validation, narrow-range rejection |
| Photo trust policy | `MealImageAnalysisTrustPolicy.swift` | Scenario detection, confidence caps, range widening |
| Photo mapper / session | `MealImageAnalysisMapper.swift`, `ImageAnalysisSession.swift` | Trust metadata mapping; recommission preserves prior range |
| Photo validator | `MealImageAnalysisResponseValidator.swift` | Requires review, assumptions, range width, multi-plate rules |
| Confirmation | `ConfirmationPolicy.swift` | `presentationConfidence` caps when clarification required |
| Presentation | `AIFoodConfirmationFormatter.swift`, `MealPhotoAnalysisPresentationFormatter.swift` | Assumptions, range, uncertainty in pending UI |
| Routing guard | `CoachIntentPhraseGuard.swift` | `isEstimateWithoutLogging` for estimate-only phrasing |
| Route handler | `CoachAIRouteHandler.swift` | Photo path rejects `executeImmediately`; trust-aware copy |

### Backend (Firebase Functions / TypeScript)

| Area | Key files | Outcome |
|------|-----------|---------|
| Calorie ranges | `foodCalorieRange.ts` | Shared derive/resolve/validate range logic |
| Trust normalization | `foodEstimateTrust.ts` | `normalizeTrustFields`, `validateTrustFields` |
| Meal image analysis | `mealImageAnalysis.ts` | Trust fields on items/totals; stricter validation |
| Prompt rules | `coachContextPromptRules.ts` | Photo + estimate trust instructions |
| Phrase guard | `coachIntentPhraseGuard.ts` | `isEstimateWithoutLogging` parity with iOS |

### Tests

| Suite | Purpose |
|-------|---------|
| `CoachAccuracyTrustRegressionTests.swift` | 13-flow regression matrix |
| `NutritionSanityValidatorHardeningTests.swift` | SG fixtures, macro repair, dish floors |
| `MealPhotoAnalysisTrustTests.swift` | Photo trust, recommission, confirmation |
| `coachAccuracyTrustRegression.test.ts` | Backend flows 1–4 |
| `foodEstimateTrust.test.ts` | Trust field normalization |
| `mealImageAnalysis.test.ts` | Photo response validation (18 tests) |

---

## 4. New estimate trust contract

Every **text** and **photo** food estimate that reaches the pending-confirmation UI must satisfy the trust contract below. Estimate-only cards (`NutritionEstimateResponse`) use range fields at the card level; logging drafts use meal-level fields.

### Required fields (meal / photo item level)

| Field | Type | Required when | Purpose |
|-------|------|---------------|---------|
| `assumptions` | `[String]` | Always | Portion, preparation, and ingredient guesses |
| `uncertaintyReasons` | `[String]` | `confidence == low` (validated) | Why the estimate may be wrong |
| `suggestedClarifications` | `[String]` | `requiresClarificationBeforeLogging == true` | Actionable follow-up questions |
| `primaryUncertainty` | `String?` | Recommended for photo / vague text | Single headline uncertainty |
| `requiresClarificationBeforeLogging` | `Bool` | Set by policy | Blocks deceptive high-confidence presentation |
| `calorieRangeLower` | `Int?` | Always (derived if missing) | Lower bound of likely calories |
| `calorieRangeUpper` | `Int?` | Always (derived if missing) | Upper bound of likely calories |
| `confidence` | `low \| medium \| high` | Always | Drives range width and copy |
| `needsUserReview` | `true` | Photo responses only | Photo estimates never auto-log |

### Range policy (`FoodCalorieRangePolicy` / `foodCalorieRange.ts`)

| Confidence | Min width (kcal) | Margin |
|------------|------------------|--------|
| high | 10 | ±5% |
| medium | 20 | ±12% |
| low | 40 | ±20% |

Explicit model ranges are accepted when they meet minimum width; otherwise policy derives or widens.

### Presentation rules

1. **No auto-log** for AI food estimates (text or photo).
2. **Presentation confidence** is capped to `low` when `requiresClarificationBeforeLogging` is true.
3. Photo confidence is capped at **medium** by `MealImageAnalysisTrustPolicy` (never high from photo alone).
4. Invalid/trust-incomplete responses are **rejected** or trigger repair — not shown as high-confidence pending cards.

### Estimate-only routing

Phrases matching `isEstimateWithoutLogging` (e.g. `estimate pad thai but don't log`, `estimate only …`) are corrected to `nutrition_estimate_query` with `requiresAppMutation: false` and no `action`.

---

## 5. Data model changes

### `FoodLogDraft` (iOS)

New fields (backward-compatible decode defaults):

```swift
var assumptions: [String]
var uncertaintyReasons: [String]
var suggestedClarifications: [String]
var primaryUncertainty: String?
var requiresClarificationBeforeLogging: Bool
var calorieRangeLower: Int?
var calorieRangeUpper: Int?
```

Computed helpers:

- `resolvedCalorieRange` — merges explicit bounds with policy
- `hasVisibleTrustMetadata` — UI gating for trust sections

### `MealImageAnalysisTrustMetadata` (iOS)

Photo-specific normalized trust bundle attached to `ImageAnalysisSessionResult.trust` and mapped into `FoodLogDraft`.

### `AIMealImageAnalysisItem` / `AIMealImageAnalysisResponse` (iOS + backend)

Items and totals extended with trust fields; `needsUserReview` is always `true` for photo responses.

### `FoodLoggedPayload` (timeline — unchanged shape, semantics used)

- `userEditedBeforeConfirm: Bool?` — set when user edits pending draft before confirming
- `isEdit` / `isDelete` — post-log correction lifecycle

### Context packet

**No schema version bump.** Trust lives on **estimate responses**, not `CoachContextPacketV2`.

---

## 6. Backend schema changes

### `/v1/ai/analyze-meal-image`

**Request:** `{ message, context, image: { mimeType, base64 } }`  
**Response:** `MealImageAnalysisResponse`

```typescript
interface MealImageAnalysisItem {
  name: string;
  quantity?: string;
  calories: number;
  protein: number; carbs: number; fat: number;
  confidence: "low" | "medium" | "high";
  assumptions: string[];
  uncertaintyReasons?: string[];
  suggestedClarifications?: string[];
  primaryUncertainty?: string;
  calorieRangeLower?: number;
  calorieRangeUpper?: number;
}

interface MealImageAnalysisResponse {
  summary: string;
  items: MealImageAnalysisItem[];
  total: { calories, protein, carbs, fat, calorieRangeLower?, calorieRangeUpper? };
  needsUserReview: true;
  clarifyingQuestion?: string;
  primaryUncertainty?: string;
}
```

Validation (`validateMealImageAnalysisResponse`):

- Rejects missing assumptions, low-confidence without uncertainty, narrow ranges
- Multiple plates require clarification unless caption logs all plates

### `/v1/ai/estimate-food`

Response maps through `foodEstimateExtraction` → iOS `FoodLogDraft`. Trust fields are enforced client-side by `FoodEstimateResponseValidator` and `NutritionSanityValidator` after decode. Backend `foodEstimateTrust.ts` provides shared normalization for future gateway enforcement.

### New shared modules

- `functions/src/foodCalorieRange.ts`
- `functions/src/foodEstimateTrust.ts`

---

## 7. Prompt changes

| Endpoint | File | Changes |
|----------|------|---------|
| `analyze-meal-image` | `coachContextPromptRules.ts` → `analyzeMealImagePromptRules()` | Trust fields required per item; cropped/multi-plate/lighting/sauce scenarios; `primaryUncertainty`; no exact-calorie presentation |
| `analyze-meal-image` | `mealImageAnalysis.ts` → `mealImageAnalysisInstructions()` | Mirrors prompt rules in model instructions |
| `estimate-food` | `estimateFoodPromptRules()` | Compound decomposition; ambiguous portion → assumptions + clarification |
| `classify-coach-intent` | `coachPromptInstructions.ts` | Prefer `nutrition_estimate_query` without logging |

Snapshot updated: `functions/test/__snapshots__/coachPromptSnapshots.test.ts.snap`

---

## 8. UI changes

| Surface | Component | Trust behavior |
|---------|-----------|----------------|
| Pending food confirmation | `CoachPendingConfirmation`, `CoachConfirmationBar` | Summary includes confidence, assumptions, range via `AIFoodConfirmationFormatter` |
| Food edit sheet | `AIFoodConfirmationSheet`, `FormaEstimateContextBanner` | Low-confidence review warning |
| Photo assistant message | `MealPhotoAnalysisPresentationFormatter` | "I estimated this from the photo", likely range, main uncertainty |
| Nutrition estimate card | `NutritionEstimateCard` | Range display when `caloriesRangeLowerKcal`/`Upper` set; accessibility summary |
| Estimate context banner | `FormaEstimateContextBanner` | Confidence label + review copy on Today food form |

**Unchanged:** Water/weight local commands, Today dashboard layout, theme selector infrastructure.

---

## 9. Correction memory behavior

v1 does **not** introduce a separate cloud-synced correction store. Correction memory is **local and timeline-backed**:

| User action | Memory mechanism |
|-------------|------------------|
| Photo clarification (`rice was half portion`) | `ImageAnalysisSession.clarificationTurns`; `ImageAnalysisPromptBuilder.recommissionMessage` injects previous range, uncertainty, items, and history into the next analysis request |
| Pending edit before log | Updated `AIFoodConfirmationDraft`; `userEditedBeforeConfirm` on `foodLogged` timeline payload |
| Post-log edit | `CoachEntryReferenceResolver` targets entry; `CoachMutationExecutor` records `recordFoodEdited` with `supersedesEventId` linking timeline chain |
| Post-log delete | `recordFoodDeleted` with supersede link |
| Rejected estimate | `foodRejected` timeline event (excluded from context packet) |

**v1 limitation:** Correction memory is **per-device** (SwiftData timeline + session state). It does not sync across devices or survive full local wipe without cloud food log restore.

---

## 10. Benchmark harness

| Harness | Location | Coverage |
|---------|----------|----------|
| Singapore food estimation fixtures | `Docs/Coach/Fixtures/singapore_food_estimation_cases.json` | Hawker dishes, portion edge cases |
| Food logging golden cases | `functions/test/fixtures/foodLoggingGoldenCases.ts` | Multi-component bowls, collapsed rejection |
| Coach intent regression | `Docs/Coach/Fixtures/coach_intent_regression_cases.json` | Advice vs log, lookup, edit/delete |
| Compound dish detector | `foodCompoundDish.test.ts`, `FoodCompoundDishDetector` tests | chicken rice, nasi lemak, char kway teow |
| Trust regression matrix | `CoachAccuracyTrustRegressionTests.swift` | 13 end-to-end flows |
| Backend trust regression | `coachAccuracyTrustRegression.test.ts` | Routing + range policy |
| Meal image analysis | `mealImageAnalysis.test.ts` | Payload validation, trust field requirements |
| Manual QA matrix | [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) | 70 device scenarios |

**Not in v1:** Real-image photo benchmark set (recommended for v2).

---

## 11. Test coverage

### Firebase (Linux CI)

| Command | Result |
|---------|--------|
| `npm run build` | PASS |
| `npm run lint` | PASS (4 pre-existing warnings in `coachContextPacketV2.ts`) |
| `npm test` (excl. emulator suites) | **581/581 PASS** |

Key suites: `coachAccuracyTrustRegression`, `foodEstimateTrust`, `mealImageAnalysis`, `coachIntentPhraseGuard`, `foodCompoundDish`, `singaporeFoodEstimationFixture`, `foodLoggingGolden`, `coachContextPromptRules`.

**Blocked without Firestore emulator:** `nutritionSyncContract`, `accountPersistenceFirestoreRules`.

### iOS (macOS / Xcode required)

| Suite | Focus |
|-------|-------|
| `CoachAccuracyTrustRegressionTests` | 13-flow matrix |
| `NutritionSanityValidatorHardeningTests` | Validator hardening |
| `MealPhotoAnalysisTrustTests` | Photo trust + recommission |
| `CoachFoodLoggingRegressionTests` | Compound logging |
| `CoachIntentPhraseGuardTests` | Phrase guard incl. don't-log |
| `CoachInputHardeningTests` | Water/weight routing |
| `CoachTodaySyncTests` | Today refresh after log |
| `CoachEntryReferenceResolverTests` | Edit/delete resolution |
| `CoachMutationExecutorTimelineTests` | Timeline correction flags |

---

## 12. Manual QA checklist

Use [COACH_ACCURACY_HARDENING_QA.md](./COACH_ACCURACY_HARDENING_QA.md) as the primary manual matrix. v1 trust additions require verifying on **device**:

### Trust-specific spot checks

| # | Flow | Pass criteria |
|---|------|---------------|
| 1 | `log chicken rice` | Low/medium confidence OR clarification; range visible; assumptions visible; no auto-log |
| 2 | `log 200g grilled chicken breast` | High confidence; narrower range; confirmation required |
| 3 | `how many calories in chicken rice` | Estimate card with range; no pending log until user taps Log |
| 4 | `estimate pad thai but don't log` | Estimate card only; no mutation |
| 5 | Photo upload | Image visible; range + trust copy; pending confirmation |
| 6 | `rice was half portion` (after photo) | Recommission; updated range; clarification in session |
| 7 | Edit pending draft | Draft updates; confirm shows reviewed estimate |
| 8 | `actually the chicken was 300g` (post-log) | Resolver + confirmation |
| 9 | `delete that` | Resolver or clarify + confirmation |
| 10 | Water / weight | Unaffected |
| 11 | Today after food log | Totals refresh |
| 12 | Theme switch | Pending/estimate cards respect theme |
| 13 | VoiceOver | Trust fields read assumptions and range |

Record results as PASS / FAIL / BLOCKED in QA notes.

---

## 13. Known limitations

| Limitation | Impact | Mitigation in v1 |
|------------|--------|------------------|
| No cloud-synced correction memory | Edits/clarifications lost on device wipe or new device | Timeline supersede chain on same device |
| Photo confidence capped, not calibrated | Ranges are heuristic, not empirically tuned | Conservative widening + manual QA |
| Text estimate trust enforced mainly on iOS post-decode | Backend extraction schema lacks all trust fields on components | Client validators + sanity pass |
| Classifier still model-dependent | Live OpenAI may misclassify edge phrases | Phrase guard + confidence gate |
| No production accuracy telemetry dashboard | Cannot measure real-world error rates | OSLog `CoachAccuracy` category (debug/ops) |
| Firestore emulator tests skipped in default CI | Rules contract not gated on every PR | Run `npm run test:firestore-rules` before release |
| iOS tests not run in Linux cloud agent | Regression gaps until macOS CI | Documented suite list above |
| Real-image photo benchmark | Photo policy tested with fixtures/mocks only | Manual photo QA + v2 benchmark set |

---

## 14. Future v2 recommendations

1. **Cloud-synced correction memory** — Persist user portion corrections and clarification answers to Firestore; inject into `CoachContextPacketV2` as structured hints (not chat prose).

2. **Production accuracy telemetry dashboard** — Aggregate anonymized: confidence distribution, confirmation reject rate, edit-before-confirm rate, dish-floor trigger rate, photo scenario frequency.

3. **Nutrition log cloud restore awareness** — When restoring food logs from cloud, replay or summarize prior user corrections so estimates respect historical edits.

4. **Per-user portion defaults** — Learn typical rice/protein portions from confirmed logs; narrow ranges only when statistically supported.

5. **Barcode / package scan** — High-confidence anchor for packaged foods; bypass wide ranges when nutrition label OCR is confident.

6. **Meal photo real-image benchmark set** — Curated labeled photo corpus (SG hawker, home-cooked, restaurant) with expected ranges; CI vision regression separate from unit mocks.

7. **Weekly review after accuracy trust is stable** — Once telemetry shows stable confirmation/edit rates, add a weekly accuracy retrospective in Coach (e.g. "estimates you edited most") without nagging on every log.

---

## Appendix: PR map

| PR | Branch | Scope |
|----|--------|-------|
| #153 | `cursor/nutrition-sanity-hardening-64df` | Text estimate trust, `NutritionSanityValidator`, `FoodCalorieRange`, text validators |
| #154 | `cursor/meal-photo-trust-hardening-64df` | Photo trust policy, mapper, backend meal image analysis, regression suite |

**Recommended merge order:** #153 → #154 (photo branch includes nutrition commits).
