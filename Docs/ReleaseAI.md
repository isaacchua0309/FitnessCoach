# Release AI Backend Configuration

Forma’s iOS app calls a **FitPilot AI backend gateway** over HTTP(S). The gateway holds provider keys and talks to the LLM; the app never embeds OpenAI (or other) API keys.

This document covers **Release / TestFlight / App Store** wiring. Local development behavior is unchanged in **Debug** builds.

---

## Why Release must not default to localhost

Previously, Release builds used:

```text
FORMA_AI_BACKEND_URL ?? "http://127.0.0.1:8787"
```

On a physical device or TestFlight build, `127.0.0.1` is the **phone itself**, not your Mac. Coach would silently fail or hang while appearing “configured.” That is a release blocker.

**Release builds now:**

- Require an explicit non-local `FORMA_AI_BACKEND_URL`.
- Reject `localhost`, `127.0.0.1`, `::1`, and `0.0.0.0`.
- Wire `UnavailableLLMClient` when no valid URL is present (no crash; Coach shows a friendly unavailable message).

---

## Required configuration for Release

Set at **archive time** (CI or Xcode). Legacy `FITPILOT_*` names are accepted if `FORMA_*` is unset.

| Variable | Required in Release | Production value |
|----------|---------------------|------------------|
| `FORMA_AI_BACKEND_URL` | **Yes** — Firebase function **base URL only** | `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway` |

**Do not** include `/v1/ai/...` in the build setting. The app appends endpoint paths itself.

**Where to set it**

- **Xcode Build Settings (TestFlight / App Store):** target **Fitness Coach** → Build Settings → user-defined `FORMA_AI_BACKEND_URL` on the **Release** configuration. Baked into `Info.plist` via `AppURLSchemes.plist` (`$(FORMA_AI_BACKEND_URL)`). The repo Release config already points at the production gateway above.
- **CI archive:** same user-defined build setting before `xcodebuild archive`.
- **Xcode scheme:** local Release runs only; scheme env vars are **not** on TestFlight unless also set via build settings.
- **Not** `DeveloperLocal.plist` — Debug device testing only.

If the variable is missing or points at localhost, the app uses `UnavailableLLMClient`. Users see:

> Coach is temporarily unavailable. Please try again later.

Internal logs (Console / `OSLog`, subsystem `FitPilot`) record the specific reason.

---

## Debug / local development (unchanged)

Debug builds (`#if DEBUG` in `AppContainer`) keep the existing behavior:

| Priority | Source |
|----------|--------|
| 1 | `FORMA_USE_MOCK_LLM=1` → `MockLLMClient` |
| 2 | `FORMA_AI_BACKEND_URL` (scheme env) |
| 3 | `DeveloperLocal.plist` in app bundle (copy from `DeveloperLocal.plist.example`) |
| 4 | **Simulator only:** default `http://127.0.0.1:8787` |
| 5 | Physical device, unset → `MockLLMClient` |

Run the local gateway from `Tools/LocalAIBackend/` on your Mac. See `Tools/LocalAIBackend/README.md`.

---

## Code map

| File | Role |
|------|------|
| `Fitness Coach/App/AppContainer.swift` | Wires `LLMClient` for Debug vs Release |
| `Fitness Coach/App/LocalAIBackendConfiguration.swift` | Debug URL resolution (simulator localhost allowed) |
| `Fitness Coach/App/ReleaseAIBackendConfiguration.swift` | Release URL resolution (no localhost) |
| `Fitness Coach/Infrastructure/AI/UnavailableLLMClient.swift` | Safe failure when Release backend not configured |
| `Fitness Coach/Infrastructure/FormaEnvironment.swift` | Resolves config from process env, then `Info.plist` |
| `Fitness Coach/Infrastructure/AI/FormaAIBackendClient.swift` | HTTP client; 45s / 90s gateway timeouts |
| `Fitness Coach/Infrastructure/AI/FallbackLLMClient.swift` | Maps transport errors → user-safe messages |

---

## Hosted backend

Production gateway: Firebase Functions `aiGateway` (`functions/src/index.ts`). Provider keys stay in Secret Manager; same HTTP contract as `Tools/LocalAIBackend/`.

**Deploy (one-time secret, then redeploy on changes):**

```sh
firebase login
firebase use fitness-coach-732fd
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:aiGateway
```

**Production URL** (matches Release `FORMA_AI_BACKEND_URL`):

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

### Security

- `OPENAI_API_KEY` must **never** be bundled in iOS, committed to git, or exposed in client logs.
- Only the gateway reads the secret; the app sends a Firebase ID token (`Authorization: Bearer …`).

### Timeouts

`FormaAIBackendClient` uses **45s request / 90s resource** timeouts. Production builds must not use legacy short timeouts (1.5s / 2.0s) — real LLM calls need the full budget or users see false “Coach took too long” errors.

### Monitoring

- **Firebase:** Functions → `aiGateway` → Logs (correlate with `X-Forma-Trace-Id` / `traceId` in JSON logs).
- **OpenAI:** Usage and billing dashboard after deploys or user reports of slow/failed Coach.

If `FORMA_AI_BACKEND_URL` is missing at archive time, TestFlight builds use `UnavailableLLMClient` (no localhost); AI Coach features show the friendly unavailable message.

---

## Manual validation

### E2E smoke test (production gateway)

#### CLI (authenticated, hits live OpenAI)

From repo root, with a Firebase ID token or test-user credentials:

```sh
# Option A — token from signed-in Release app (Settings → Developer, or temporary debug log)
FORMA_ID_TOKEN='paste-token-here' npm --prefix functions run smoke:auth

# Option B — email/password test user + Web API key from GoogleService-Info.plist (API_KEY field)
FIREBASE_WEB_API_KEY='…' \
FIREBASE_TEST_EMAIL='…' \
FIREBASE_TEST_PASSWORD='…' \
npm --prefix functions run smoke:auth
```

Script: `functions/scripts/smoke-ai-gateway-auth.mjs`. Default base URL matches Release `FORMA_AI_BACKEND_URL`. Sends `X-Forma-Trace-Id` for log correlation.

| # | Scenario | Route | User input | Pass criteria |
|---|----------|-------|------------|---------------|
| 1 | Coach classify | `/v1/ai/classify-coach-intent` | “Should I eat a McDonald's double cheeseburger tonight?” | HTTP 200, `intentResult.intent` set, &lt; 90s |
| 2 | Food estimate | `/v1/ai/estimate-food` | “Estimate calories for a double cheeseburger from McDonald's” | HTTP 200, `foodDrafts` + `confidence`, &lt; 90s |
| 3 | Meal advice | `/v1/ai/generate-meal-advice` | Follow-up coaching question | HTTP 200, `response.message` useful text, &lt; 90s |
| 4 | Parse workout (optional) | `/v1/ai/parse-workout` | “Bench press 5x5 at 90kg” | HTTP 200, `workoutDraft` returned |

**Record per run:** route, HTTP status, latency ms, timeout yes/no, trace ID, Firebase log lines, OpenAI usage bump.

**Post-run logs:**

```sh
firebase functions:log --only aiGateway --project fitness-coach-732fd | rg '<trace-id-from-script>'
```

#### iOS app (Release build)

Run on a **Release** build (Archive → TestFlight, or Scheme → Run with **Release** + signed-in user). Confirm `FORMA_AI_BACKEND_URL` is baked:

```text
https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway
```

| Step | Action | Pass criteria |
|------|--------|---------------|
| 1 | Sign in (Apple / Google / email) | Session active |
| 2 | Coach → “Should I eat a McDonald's double cheeseburger tonight?” | Coach reply or routed flow; not “temporarily unavailable” / session error |
| 3 | “Estimate calories for a double cheeseburger from McDonald's” | Food draft or confirmation UI |
| 4 | Ask for meal advice on that choice | Coaching text |
| 5 | (Optional) “Bench press 5x5 at 90kg” | Workout draft / log prompt |

**User-facing failures:**

| Symptom | Likely cause |
|---------|----------------|
| “Coach is temporarily unavailable…” | Missing/invalid `FORMA_AI_BACKEND_URL` or gateway 5xx |
| “We couldn't verify your session…” | Expired token / 401 |
| “Coach took too long to respond…” | Timeout (&gt; 45s request); check Firebase + OpenAI latency |

On failure: device Console (`subsystem:FitPilot`), Firebase `aiGateway` logs (filter `traceId`), OpenAI Usage dashboard.

### Release without backend URL

1. Archive Release with **empty** `FORMA_AI_BACKEND_URL`.
2. Coach AI prompt → friendly unavailable copy; no calls to `127.0.0.1`.

### Debug regression

1. Simulator Debug, no env vars → `127.0.0.1:8787` or Mock LLM.
2. `FORMA_USE_MOCK_LLM=1` → mock client.
3. Device Debug → scheme env or `DeveloperLocal.plist` with Mac LAN IP.

---

## Related

- [Architecture.md](./Architecture.md) — app composition and AI boundary
- [Tools/LocalAIBackend/README.md](../Tools/LocalAIBackend/README.md) — local gateway setup
