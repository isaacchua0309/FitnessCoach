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

### Auth

`FormaAIBackendClient` attaches a Firebase ID token from `AuthManager.idToken()` when calling the gateway.

### Pipeline tracing

`FormaPipelineTracer` records in-memory diagnostics in DEBUG. Disk persistence remains disabled (`PipelineTracePersistence` stub).

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

The repository includes a minimal Firebase Functions TypeScript scaffold (`functions/src/index.ts`). It is **not** the primary AI path for the iOS app today — the local/production HTTP gateway handles LLM proxying.

When Functions are expanded, document new endpoints here and add contract tests alongside iOS integration tests.

---

## Environment variables

| Variable | Purpose |
|----------|---------|
| `FORMA_AI_BACKEND_URL` | Debug/release AI gateway base URL |
| `FORMA_USE_MOCK_LLM` | Force `MockLLMClient` in DEBUG |
| `FITPILOT_*` | Legacy aliases accepted via `FormaEnvironment` |
