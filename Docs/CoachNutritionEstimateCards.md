# Coach Nutrition Estimate Cards

## Summary

Nutrition estimate and comparison queries in Coach return structured, scannable cards instead of long AI paragraphs. Meal logging flow is unchanged — **tapping Log Meal still requires confirmation**.

**Trust Hardening v1:** Estimate cards may show **calorie ranges** (`caloriesRangeLowerKcal`–`caloriesRangeUpperKcal`) when point estimates are uncertain. Logging drafts carry full trust metadata (assumptions, uncertainty, clarification flags). See [COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md](./Coach/COACH_ACCURACY_TRUST_HARDENING_V1_FINAL_REPORT.md).

## New gateway endpoints

- `v1/ai/generate-nutrition-estimate` — structured `NutritionEstimateResponse` JSON
- `v1/ai/generate-nutrition-comparison` — structured `NutritionComparisonResponse` JSON
- `v1/ai/analyze-meal-image` — structured `MealImageAnalysisResponse` with trust fields (photo logging pipeline)

## Trust fields (v1)

| Surface | Range | Assumptions / uncertainty |
|---------|-------|---------------------------|
| Estimate card | `caloriesRangeLowerKcal` / `caloriesRangeUpperKcal` in `NutritionEstimateResponse` | `confidenceLevel`, `confidenceReason`, `caveats[]` |
| Pending food log | `FoodLogDraft.calorieRangeLower/Upper` | `assumptions[]`, `uncertaintyReasons[]`, `suggestedClarifications[]`, `primaryUncertainty` |
| Photo analysis | Item + total ranges | `needsUserReview: true`; `MealImageAnalysisTrustPolicy` on iOS |

Estimate-only queries (`nutrition_estimate_query`, `how many calories in X`) **never** create pending logs unless the user taps a suggested action (e.g. Log Meal).

Phrases like `estimate pad thai but don't log` are routed to estimate-only via `isEstimateWithoutLogging` (no mutation).

## Intent mapping

| User intent | Route | Behavior |
|---|---|---|
| `nutrition_estimate_query` | `nutritionEstimate` | Estimate card, no auto-log |
| `nutrition_comparison_query` | `nutritionComparison` | Comparison card, no auto-log |
| Legacy `calorie_lookup`, `macro_lookup`, `meal_decision` | `nutritionEstimate` | Backward-compatible estimate card |
| `log_food` | `estimateFood` | Existing confirmation/logging flow |
| `nutrition_advice`, workout/weight advice | `mealAdvice` | Unchanged prose advice |

## Key iOS files

- Models: `Fitness Coach/Domain/Coach/NutritionEstimateModels.swift`
- Parser: `Fitness Coach/Application/UseCases/Coach/NutritionEstimateResponseParser.swift`
- Handler: `Fitness Coach/Application/UseCases/Coach/CoachAIRouteHandler.swift`
- UI: `Fitness Coach/Features/Coach/Components/NutritionEstimateCard.swift`, `NutritionComparisonCard.swift`
- Analytics: `Fitness Coach/Domain/Coach/CoachAnalyticsLogging.swift`

## Suggested actions

- **Log Meal** → pending confirmation bar (user must confirm)
- **Add fries / Add drink** → sends new estimate query
- **Estimate another** → focuses composer
- **Compare / healthier / follow-up** → sends follow-up Coach query

## Analytics events

- `nutrition_estimate_card_shown`
- `nutrition_comparison_card_shown`
- `nutrition_estimate_json_parse_failed`
- `nutrition_estimate_action_tapped`
- `nutrition_estimate_log_started` / `_confirmed` / `_cancelled`

Metadata: `confidenceLevel`, `hasMacros`, `hasTodayContext`, `actionType`, `sourceType` (no raw user message).
