# Backend API Notes

Forma iOS talks to optional backend services for AI and cloud profile sync. This document describes the contracts the app expects today.

**Related:** [Architecture.md](./Architecture.md) — app composition and `AppContainer` wiring.

---

## AI backend (debug + release)

The iOS app does **not** embed OpenAI keys. `AIService` routes through `LLMClient` implementations configured in `AppContainer`.

### Debug (`#if DEBUG`)

| Client | When |
|--------|------|
| `MockLLMClient` | `FORMA_USE_MOCK_LLM=1` (or legacy `FITPILOT_USE_MOCK_LLM=1`) |
| `FormaAIBackendClient` via `FallbackLLMClient` | Local gateway URL resolved by `LocalAIBackendConfiguration` |
| `MockLLMClient` (fallback) | No backend URL on physical device |

**URL resolution** (`LocalAIBackendConfiguration`):

1. `FORMA_AI_BACKEND_URL` / `FITPILOT_AI_BACKEND_URL` in Xcode scheme environment
2. `DeveloperLocal.plist` in app bundle
3. Simulator default: `http://127.0.0.1:8787`

The local gateway (`Tools/LocalAIBackend/`) reads provider keys from the Mac `.env` and proxies OpenAI requests.

### Release

`ReleaseAIBackendConfiguration` supplies the production gateway URL. If unavailable, `UnavailableLLMClient` surfaces a user-visible error.

**Production gateway (function base URL only — no `/v1/ai/...` suffix):**

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

The iOS client appends paths such as `/v1/ai/classify-coach-intent`. Example full request URL:

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway/v1/ai/classify-coach-intent
```

**URL resolution** (`FormaEnvironment` → `ReleaseAIBackendConfiguration`):

1. `FORMA_AI_BACKEND_URL` / `FITPILOT_AI_BACKEND_URL` in process environment (Xcode scheme — local Release runs only)
2. `FORMA_AI_BACKEND_URL` baked into `Info.plist` from the Xcode user-defined build setting `$(FORMA_AI_BACKEND_URL)` (TestFlight / App Store)
3. Localhost hosts are rejected in Release

**HTTP timeouts:** `FormaAIBackendClient` uses **45s request / 90s resource** for gateway calls. Do not use short Release timeouts (e.g. 1.5s / 2.0s); real LLM latency requires this budget.

**Security:** OpenAI and other provider keys live in Firebase Secret Manager only. Never bundle `OPENAI_API_KEY` (or any provider key) in the iOS app, `Info.plist`, or committed files.

### Auth

`FormaAIBackendClient` attaches a Firebase ID token from `AuthManager.idToken()` when calling the gateway.

### Pipeline tracing

`FormaPipelineTracer` records in-memory diagnostics in DEBUG. Disk persistence remains disabled (`PipelineTracePersistence` stub).

`FormaAIBackendClient` sends the active trace UUID in the **`X-Forma-Trace-Id`** HTTP header. Both the local gateway and Firebase `aiGateway` read that header and include `traceId` in structured logs so client pipeline traces can be correlated with gateway/OpenAI request logs.

Legacy fallback: gateways also accept **`X-FitPilot-Trace-Id`** if the Forma header is absent.

---

## Cloud profile (Firebase)

| Component | Role |
|-----------|------|
| `FirestoreCloudUserProfileStore` | Signed-in profile read/write |
| `ProfileBootstrapService` | Local profile bootstrap + cloud restore |
| `ProfileBootstrapCoordinatorService` | Signed-in reconcile after auth |

Profile documents are owned by `Application/UseCases/ProfileBootstrapService.swift` and related cloud DTOs under `Infrastructure/Cloud/`.

---

## Firebase Functions (`functions/`)

Hosted HTTPS gateway for the same AI contract as `Tools/LocalAIBackend/`.

**Production URL (function base only):**

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

The gateway verifies Firebase ID tokens by default. Set `FORMA_AI_REQUIRE_AUTH=0`
only for temporary local/emulator testing.

### Firebase AI gateway endpoints

| Path | Purpose |
|------|---------|
| `/v1/ai/classify-coach-intent` | Cheap model Coach intent classification |
| `/v1/ai/parse-command` | AI command parsing |
| `/v1/ai/estimate-food` | Text or photo food estimate |
| `/v1/ai/generate-meal-advice` | Meal, calorie, macro, and coaching text |
| `/v1/ai/generate-daily-review` | Daily review narrative |
| `/v1/ai/parse-workout` | Workout parsing |
| `/v1/ai/parse-edit-delete` | Edit/delete intent parsing |
| `/v1/ai/parse-multi-action` | Multi-action parsing |

### Firebase setup

```sh
firebase login
firebase use fitness-coach-732fd
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:aiGateway
```

Optional non-secret model settings: copy `functions/.env.example` → `functions/.env` before deploy, or use defaults.

### Monitoring

After deploy or incident:

- **Firebase logs:** Firebase Console → Functions → `aiGateway` → Logs. Filter by `traceId` (matches iOS `X-Forma-Trace-Id`).
- **OpenAI:** Dashboard → Usage / Billing for unexpected spikes or failed model calls.

Contract tests (no live OpenAI): `cd functions && npm test`.

---

## Environment variables

| Variable | Purpose |
|----------|---------|
| `FORMA_AI_BACKEND_URL` | Debug/release AI gateway base URL |
| `FORMA_USE_MOCK_LLM` | Force `MockLLMClient` in DEBUG |
| `FITPILOT_*` | Legacy aliases accepted via `FormaEnvironment` |
| `OPENAI_API_KEY` | Firebase secret used by `aiGateway`, never shipped to iOS |
| `FORMA_AI_REQUIRE_AUTH` | Firebase Functions setting; auth required unless set to `0` |
