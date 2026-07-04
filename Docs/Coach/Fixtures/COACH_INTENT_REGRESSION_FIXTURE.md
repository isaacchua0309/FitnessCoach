# Coach Intent Regression Fixture Suite

## Source of truth

`Docs/Coach/Fixtures/coach_intent_regression_cases.json`

This file defines durable regression cases for Coach intent classification and routing. It is loaded by:

- iOS: `CoachIntentRegressionFixtureTests`
- Backend: `functions/test/coachIntentRegressionFixture.test.ts`

## Categories

| Category | Purpose |
|---|---|
| `should_not_log_food` | Advice, hypothetical, and lookup phrasing must not create food mutations |
| `should_log_food` | Explicit consumption/logging language should remain `log_food` |
| `nutrition_lookup` | Calorie/macro/comparison questions without logging |
| `meal_decision` | Fit / "should I eat" decisions without logging |
| `daily_summary` | Local status and daily review commands |
| `edit_delete_reference` | Edit, delete, undo, and reference resolution |
| `water_logging` | Local hydration commands |
| `weight_logging` | Local weight commands |
| `workout_redirect` | Workout logging redirects to Training |
| `unsupported` | Out-of-scope requests |

## Case fields

- `input` — user message
- `expectedIntent` — canonical intent after guards/sanitizer (snake_case backend form)
- `shouldCreateMutation` — whether the pipeline should attempt an app mutation
- `shouldRequireConfirmation` — whether confirmation is expected before persisting (food estimates always confirm)
- `notes` — human-readable context
- `edgeReason` — stable tag for debugging regressions
- `verificationLayers` — which automated checks apply (see below)

Optional fields:

- `misclassifiedIntent` — classifier stub intent for routing/guard tests (usually `log_food`)
- `classifierConfidence` — confidence stub for gate tests
- `expectedRouteHandler` — iOS `CoachRouteDecision.chosenHandler`
- `forbiddenRouteHandlers` — handlers that must not be chosen

## Verification layers (automated)

| Layer | What it tests | Requires live OpenAI? |
|---|---|---|
| `phrase_guard` | `CoachIntentPhraseGuard` / `coachIntentPhraseGuard.ts` corrects misclassified `log_food` | No |
| `backend_sanitizer` | `sanitizeCoachIntentResult(text)` applies phrase guard + strips spurious actions | No |
| `local_guard` | `CoachRouteDecider` local path (water, weight, status, catalog food) | No |
| `routing_stub` | End-to-end routing with stubbed classifier output | No |
| `confidence_gate` | `CoachIntentConfidenceGate` threshold behavior | No |

## Manual verification required

Live `/v1/ai/classify-coach-intent` OpenAI classification is **not** exercised in CI today. After prompt or model changes, manually spot-check a stratified sample:

1. 5 cases from `should_not_log_food` (include chicken rice, nasi lemak, bubble tea)
2. 5 cases from `should_log_food` (include explicit "I ate …" and "log …")
3. 3 `nutrition_lookup`, 3 `meal_decision`, 2 `edit_delete_reference`

Record results in QA notes. If live classifier diverges from fixture `expectedIntent`, update prompts first; only change fixtures when product intent rules intentionally change.

## Adding cases

1. Add a case with a unique `id` and explicit `verificationLayers`.
2. Include `edgeReason` that explains why the case exists.
3. Prefer Singapore/local food names where realistic.
4. Run:
   - `xcodebuild test -only-testing:Fitness\ CoachTests/CoachIntentRegressionFixtureTests`
   - `cd functions && npm test -- --testPathPatterns=coachIntentRegressionFixture`
