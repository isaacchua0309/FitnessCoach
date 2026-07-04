# Backend environment variables

Firebase Functions configuration for `functions/`. Secrets are set via Firebase Secret Manager; non-secrets may be copied from `functions/.env.example` to `functions/.env` before deploy.

**Related:** [BackendRouteMap.md](./BackendRouteMap.md), [BackendAPI.md](../BackendAPI.md).

---

## Secrets

| Variable | Where used | Notes |
|----------|------------|-------|
| `OPENAI_API_KEY` | `aiGateway` (`index.ts`) | Required for OpenAI Responses API calls. Set with `firebase functions:secrets:set OPENAI_API_KEY`. Never commit or ship to iOS. |

---

## OpenAI model configuration

Resolved by `functions/src/modelConfig.ts` (`readModelConfig`, `resolveModel`).

| Variable | Default when unset | Purpose |
|----------|-------------------|---------|
| `OPENAI_MODEL` | `gpt-5-nano` | Default model tier and fallback for `cheap` when classifier unset |
| `OPENAI_CLASSIFIER_MODEL` | falls back to `OPENAI_MODEL` / `gpt-5-nano` | Cheap-tier classifier and parsing tasks |
| `OPENAI_STRONG_MODEL` | `gpt-5.4-nano` | Strong-tier tasks (meal image, photo food estimate, coach advice default) |
| `OPENAI_FALLBACK_MODEL` | `gpt-5.4-mini` | Reserved fallback id in config (included in client `modelName` allowlist) |
| `OPENAI_REASONING_EFFORT` | `low` | GPT-5 reasoning effort for Responses API; see guards below |

Client-supplied `body.modelName` is accepted only when it matches one of the four configured model ids above. Unknown names fall back to `OPENAI_MODEL` / default.

### Reasoning effort guards

`functions/src/openAIReasoningEffort.ts`:

- Reasoning params are sent **only** for `gpt-5*` models.
- Legacy alias `minimal` → `low` (with warning log).
- Unsupported values (e.g. `turbo`) fail locally with `model_config_invalid` before calling OpenAI.
- OpenAI errors mentioning unsupported reasoning/effort are mapped to the same category.

---

## AI gateway guardrails

Read in `functions/src/gatewayGuardrails.ts` and `mealImageAnalysis.ts`.

| Variable | Default | Purpose |
|----------|---------|---------|
| `FORMA_AI_REQUIRE_AUTH` | auth required | Set to `0` only for emulator/local testing without Firebase tokens |
| `FORMA_AI_MAX_BODY_BYTES` | `524288` (512 KiB) | Max JSON body size (no image) |
| `FORMA_AI_MAX_BODY_BYTES_WITH_IMAGE` | `2097152` (2 MiB) | Max body when request includes image base64 |
| `FORMA_AI_MAX_TEXT_CHARS` | `4000` | Max `text` / meal-image `message` length |
| `FORMA_AI_MAX_QUESTION_CHARS` | `4000` | Max coaching `question` length |
| `FORMA_AI_MAX_IMAGE_B64_CHARS` | `1500000` | Max base64 image payload length |
| `FORMA_AI_MAX_DECODED_IMAGE_BYTES` | `1125000` | Max decoded meal-image bytes |
| `FORMA_AI_MAX_LOCALE_CHARS` | `32` | Max locale string on meal-image requests |
| `FORMA_AI_BURST_PER_MINUTE` | `30` | Per-uid burst limit (0 = disabled) |
| `FORMA_AI_DAILY_REQUEST_LIMIT` | `400` | Per-uid daily limit (0 = disabled) |

---

## Account deletion guardrails

Read in `functions/src/accountDeletion/accountDeletionGuardrails.ts`.

| Variable | Default | Purpose |
|----------|---------|---------|
| `FORMA_ACCOUNT_DELETE_BURST_PER_MINUTE` | `2` | Per-uid burst limit (0 = disabled) |
| `FORMA_ACCOUNT_DELETE_DAILY_LIMIT` | `5` | Per-uid daily limit (0 = disabled) |

Account deletion uses the same `FORMA_AI_REQUIRE_AUTH=0` bypass as the AI gateway when testing without tokens.

---

## iOS client (not Functions env)

These are documented here for cross-reference only; they are **not** read by Firebase Functions.

| Variable | Purpose |
|----------|---------|
| `FORMA_AI_BACKEND_URL` | Hosted `aiGateway` base URL in Xcode / `Info.plist` |
| `FITPILOT_AI_BACKEND_URL` | Legacy alias |

---

## Tests

```sh
cd functions && npm test -- modelConfig.test.ts openAIReasoningEffort.test.ts backendRoutes.test.ts
```
