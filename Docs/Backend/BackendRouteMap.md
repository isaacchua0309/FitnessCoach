# Backend route map

Canonical registry for Firebase HTTPS functions in `functions/`. Source of truth for paths and ownership: `functions/src/backendRoutes.ts`.

**Related:** [BackendAPI.md](../BackendAPI.md) (client contracts), [EnvironmentVariables.md](./EnvironmentVariables.md).

---

## Function exports

| Firebase export | Handler | Base URL pattern |
|-----------------|---------|------------------|
| `aiGateway` | `handleAiGatewayRequest` | `…/aiGateway` + path below |
| `accountDataDeletion` | `handleAccountDeletionRequest` | `…/accountDataDeletion` + path below |

All routes accept `POST` only (`OPTIONS` returns `204` for CORS preflight). Unknown paths return `404`.

---

## AI gateway routes (`aiGateway`)

Implementation: `functions/src/index.ts` (`handleAiGatewayRequest`).

Auth: Firebase ID token required unless `FORMA_AI_REQUIRE_AUTH=0` (testing only).

| Path | Handler | Model tier | Top-level response keys |
|------|---------|------------|-------------------------|
| `/v1/ai/classify-coach-intent` | `classifyCoachIntent` | cheap (+ optional `body.modelName`) | `intentResult` |
| `/v1/ai/parse-command` | `parseCommand` | cheap | `parsedCommand` |
| `/v1/ai/estimate-food` | `estimateFood` | strong when `body.imageJPEGBase64`, else cheap | `foodLogDrafts`, `foodDrafts`, `confidence`, `requiresConfirmation` |
| `/v1/ai/analyze-meal-image` | `analyzeMealImage` | strong | `summary`, `items`, `total`, `needsUserReview` |
| `/v1/ai/generate-meal-advice` | `coachResponse` (meal advice) | `body.modelTier` ?? strong (+ optional `body.modelName`) | `response` |
| `/v1/ai/generate-nutrition-estimate` | `nutritionEstimateResponse` | `body.modelTier` ?? cheap (+ optional `body.modelName`) | `estimate` |
| `/v1/ai/generate-nutrition-comparison` | `nutritionComparisonResponse` | `body.modelTier` ?? cheap (+ optional `body.modelName`) | `comparison` |
| `/v1/ai/generate-daily-review` | `coachResponse` (daily review) | cheap (+ optional `body.modelName`) | `response` |
| `/v1/ai/parse-workout` | `parseWorkout` | cheap | `workoutDraft`, `confidence` |
| `/v1/ai/parse-edit-delete` | `parseEditDelete` | cheap | `parsedCommand` |
| `/v1/ai/parse-multi-action` | `parseMultiAction` | cheap | `parsedCommand` |

### Supporting modules

| Concern | Module |
|---------|--------|
| Request validation / quotas | `gatewayGuardrails.ts` |
| Prompt instructions | `coachPromptInstructions.ts`, `mealImageAnalysis.ts` |
| Response sanitizers | `coachIntentSanitizer.ts`, `nutritionResponseSanitizer.ts`, `foodEstimateExtraction.ts` |
| Model name resolution | `modelConfig.ts` |
| GPT-5 reasoning effort guard | `openAIReasoningEffort.ts` |

---

## Account deletion route (`accountDataDeletion`)

Implementation: `functions/src/accountDeletion/accountDeletionHandler.ts`.

| Path | Handler | Notes |
|------|---------|-------|
| `/v1/account/delete-data` | `handleAccountDeletionRequest` | Deletes Firestore user data for the verified token `uid`; requires `confirmation: "DELETE"` |

Supporting modules: `accountDeletionGuardrails.ts`, `accountDeletionService.ts`, `accountDeletionPaths.ts`.

---

## Smoke test

```sh
cd functions && npm test -- backendRoutes.test.ts
```
