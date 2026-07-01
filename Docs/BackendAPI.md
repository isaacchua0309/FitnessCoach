# Backend API Notes

Forma iOS talks to optional backend services for AI and cloud profile sync. This document describes the contracts the app expects today.

**Related:** [Architecture.md](./Architecture.md) — app composition and `AppContainer` wiring.

---

## AI backend (hosted gateway)

The iOS app does **not** embed OpenAI keys or read any `.env` file. `AIService` routes through `LLMClient` implementations configured in `AppContainer`.

### Production path

```text
iOS app → Firebase aiGateway → OpenAI (Secret Manager)
```

**Gateway base URL** (function base only — no `/v1/ai/...` suffix):

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

The iOS client appends paths such as `/v1/ai/classify-coach-intent`. Example full request URL:

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway/v1/ai/classify-coach-intent
```

### Client wiring (`AppContainer`)

| Client | When |
|--------|------|
| `MockLLMClient` | `AppContainer(inMemory: true)` — SwiftUI previews and in-memory tests |
| `FormaAIBackendClient` via `FallbackLLMClient` | Normal app launch with a valid gateway URL |
| `UnavailableLLMClient` | Gateway URL missing, invalid, or points at localhost |

Debug, Release, and TestFlight builds all use the same hosted gateway URL baked into `Info.plist` via the Xcode user-defined build setting `FORMA_AI_BACKEND_URL`.

**URL resolution** (`AIBackendConfiguration`):

1. `FORMA_AI_BACKEND_URL` / `FITPILOT_AI_BACKEND_URL` in process environment (Xcode scheme override)
2. `FORMA_AI_BACKEND_URL` baked into `Info.plist` from `$(FORMA_AI_BACKEND_URL)` (Debug / Release / TestFlight)
3. Localhost hosts (`localhost`, `127.0.0.1`, `::1`, `0.0.0.0`) are always rejected

**HTTP timeouts:** `FormaAIBackendClient` uses **45s request / 90s resource** for gateway calls.

**Security:** OpenAI and other provider keys live in Firebase Secret Manager only. Never bundle `OPENAI_API_KEY` (or any provider key) in the iOS app, `Info.plist`, or committed files.

### Auth

`FormaAIBackendClient` attaches a Firebase ID token from `AuthManager.idToken()` on every gateway request (`Authorization: Bearer …`).

### Pipeline tracing

`FormaPipelineTracer` records in-memory diagnostics in DEBUG. Disk persistence remains disabled (`PipelineTracePersistence` stub).

`FormaAIBackendClient` sends the active trace UUID in the **`X-Forma-Trace-Id`** HTTP header. Firebase `aiGateway` reads that header and includes `traceId` in structured logs so client pipeline traces can be correlated with gateway/OpenAI request logs.

Legacy fallback: the gateway also accepts **`X-FitPilot-Trace-Id`** if the Forma header is absent.

On startup, DEBUG builds log the resolved gateway URL via `FormaPipelineTracer` (no secrets).

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

Hosted HTTPS gateway for all AI traffic from the iOS app.

**Production URL (function base only):**

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

The gateway verifies Firebase ID tokens by default. Set `FORMA_AI_REQUIRE_AUTH=0`
only for temporary emulator testing.

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

Authenticated E2E smoke test: `npm --prefix functions run smoke:auth` (see [ReleaseAI.md](./ReleaseAI.md)).

---

## Environment variables

| Variable | Purpose |
|----------|---------|
| `FORMA_AI_BACKEND_URL` | Hosted AI gateway base URL (Xcode build setting → `Info.plist`) |
| `FITPILOT_*` | Legacy aliases accepted via `FormaEnvironment` |
| `OPENAI_API_KEY` | Firebase Secret Manager secret used by `aiGateway`, never shipped to iOS |
| `FORMA_AI_REQUIRE_AUTH` | Firebase Functions setting; auth required unless set to `0` |
