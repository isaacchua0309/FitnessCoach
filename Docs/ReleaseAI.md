# Release AI Backend Configuration

Forma's iOS app calls the **Firebase aiGateway** over HTTPS. The gateway holds provider keys in Secret Manager and talks to OpenAI; the app never embeds API keys or reads `.env` files.

This document covers **Debug, Release, TestFlight, and App Store** wiring.

---

## Production path

```text
iOS app → Firebase aiGateway → OpenAI (Secret Manager)
```

There is no local AI backend, localhost fallback, or Mac-side `.env` dependency in the iOS app.

---

## Required configuration

Set at build time (CI or Xcode). Legacy `FITPILOT_*` names are accepted if `FORMA_*` is unset.

| Variable | Required | Production value |
|----------|----------|------------------|
| `FORMA_AI_BACKEND_URL` | **Yes** — Firebase function **base URL only** | `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway` |

**Do not** include `/v1/ai/...` in the build setting. The app appends endpoint paths itself.

**Where to set it**

- **Xcode Build Settings:** target **Fitness Coach** → Build Settings → user-defined `FORMA_AI_BACKEND_URL` on **Debug** and **Release**. Baked into `Info.plist` via `AppURLSchemes.plist` (`$(FORMA_AI_BACKEND_URL)`). The repo already points both configurations at the production gateway above.
- **CI archive:** same user-defined build setting before `xcodebuild archive`.
- **Xcode scheme:** optional process-environment override for local testing against a non-localhost staging URL.

Localhost hosts (`localhost`, `127.0.0.1`, `::1`, `0.0.0.0`) are **always rejected**. If the URL is missing or invalid, the app uses `UnavailableLLMClient`. Users see:

> Coach is temporarily unavailable. Please try again later.

Internal logs (Console / `OSLog`, subsystem `FitPilot`) record the specific reason. DEBUG builds also log the resolved gateway URL via `FormaPipelineTracer` (no secrets).

---

## Client wiring

| Client | When |
|--------|------|
| `MockLLMClient` | `AppContainer(inMemory: true)` — previews / in-memory tests only |
| `FormaAIBackendClient` | Normal launch with valid `FORMA_AI_BACKEND_URL` |
| `UnavailableLLMClient` | URL missing, invalid, or localhost |

Every live gateway request includes a Firebase ID token (`Authorization: Bearer …`).

---

## Code map

| File | Role |
|------|------|
| `Fitness Coach/App/AppContainer.swift` | Wires `LLMClient` |
| `Fitness Coach/App/AIBackendConfiguration.swift` | Gateway URL resolution (no localhost) |
| `Fitness Coach/Infrastructure/AI/UnavailableLLMClient.swift` | Safe failure when gateway URL invalid |
| `Fitness Coach/Infrastructure/FormaEnvironment.swift` | Resolves config from process env, then `Info.plist` |
| `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift` | HTTP client; 45s / 90s gateway timeouts |
| `Fitness Coach/Infrastructure/AI/FallbackLLMClient.swift` | Maps transport errors → user-safe messages |

---

## Hosted backend

Production gateway: Firebase Functions `aiGateway` (`functions/src/index.ts`).

**Deploy (one-time secret, then redeploy on changes):**

```sh
firebase login
firebase use fitness-coach-732fd
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:aiGateway
```

**Production URL** (matches `FORMA_AI_BACKEND_URL`):

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

### Security

- `OPENAI_API_KEY` must **never** be bundled in iOS, committed to git, or exposed in client logs.
- Only the gateway reads the secret; the app sends a Firebase ID token.

### Timeouts

`FormaAIBackendClient` uses **45s request / 90s resource** timeouts. Production builds must not use legacy short timeouts (1.5s / 2.0s) — real LLM calls need the full budget or users see false "Coach took too long" errors.

### Monitoring

- **Firebase:** Functions → `aiGateway` → Logs (correlate with `X-Forma-Trace-Id` / `traceId` in JSON logs).
- **OpenAI:** Usage and billing dashboard after deploys or user reports of slow/failed Coach.

---

## Manual validation

### E2E smoke test (production gateway)

#### CLI (authenticated, hits live OpenAI)

From repo root, with a Firebase ID token or test-user credentials:

```sh
# Option A — token from signed-in app
FORMA_ID_TOKEN='paste-token-here' npm --prefix functions run smoke:auth

# Option B — email/password test user + Web API key from GoogleService-Info.plist (API_KEY field)
FIREBASE_WEB_API_KEY='…' \
FIREBASE_TEST_EMAIL='…' \
FIREBASE_TEST_PASSWORD='…' \
npm --prefix functions run smoke:auth
```

Script: `functions/scripts/smoke-ai-gateway-auth.mjs`. Default base URL matches `FORMA_AI_BACKEND_URL`. Sends `X-Forma-Trace-Id` for log correlation.

| # | Scenario | Route | User input | Pass criteria |
|---|----------|-------|------------|---------------|
| 1 | Coach classify | `/v1/ai/classify-coach-intent` | "Should I eat a McDonald's double cheeseburger tonight?" | HTTP 200, `intentResult.intent` set, < 90s |
| 2 | Food estimate | `/v1/ai/estimate-food` | "Estimate calories for a double cheeseburger from McDonald's" | HTTP 200, `foodDrafts` + `confidence`, < 90s |
| 3 | Meal advice | `/v1/ai/generate-meal-advice` | Follow-up coaching question | HTTP 200, `response.message` useful text, < 90s |
| 4 | Parse workout (optional) | `/v1/ai/parse-workout` | "Bench press 5x5 at 90kg" | HTTP 200, `workoutDraft` returned |

**Post-run logs:**

```sh
firebase functions:log --only aiGateway --project fitness-coach-732fd | rg '<trace-id-from-script>'
```

#### iOS app (Debug or Release on physical device)

Confirm `FORMA_AI_BACKEND_URL` resolves to:

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

| Step | Action | Pass criteria |
|------|--------|---------------|
| 1 | Sign in (Apple / Google / email) | Session active |
| 2 | Coach → "Should I eat a McDonald's double cheeseburger tonight?" | Coach reply; not "temporarily unavailable" |
| 3 | "Estimate calories for a double cheeseburger from McDonald's" | Food draft or confirmation UI |
| 4 | Ask for meal advice on that choice | Coaching text |
| 5 | (Optional) "Bench press 5x5 at 90kg" | Workout draft / log prompt |

**User-facing failures:**

| Symptom | Likely cause |
|---------|----------------|
| "Coach is temporarily unavailable…" | Missing/invalid `FORMA_AI_BACKEND_URL` or gateway 5xx |
| "We couldn't verify your session…" | Expired token / 401 |
| "Coach took too long to respond…" | Timeout (> 45s request); check Firebase + OpenAI latency |

On failure: device Console (`subsystem:FitPilot`), Firebase `aiGateway` logs (filter `traceId`), OpenAI Usage dashboard.

### Misconfiguration regression

1. Archive with **empty** `FORMA_AI_BACKEND_URL`.
2. Coach AI prompt → friendly unavailable copy; no network calls.

### Debug regression

1. Debug build on simulator → hosted gateway (same URL as Release).
2. SwiftUI preview (`AppContainer(inMemory: true)`) → `MockLLMClient`, no network.

---

## Related

- [Architecture.md](./Architecture.md) — app composition and AI boundary
- [BackendAPI.md](./BackendAPI.md) — HTTP contract and endpoints
