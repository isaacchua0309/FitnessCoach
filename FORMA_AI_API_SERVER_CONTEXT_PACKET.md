# Forma AI API Server Context Packet

**Generated:** 2026-07-02  
**Scope:** Investigation and documentation only (no code changes).  
**Repo:** `FitnessCoach` (Forma iOS + Firebase `aiGateway`)

---

# 1. Executive Summary

| Question | Answer |
|----------|--------|
| **Does the backend exist?** | **Yes (in repo).** Firebase HTTPS function `aiGateway` is implemented in `functions/src/index.ts` with 8 `/v1/ai/*` routes. |
| **Is it deployed?** | **UNKNOWN (not verifiable from repo alone).** Docs and Xcode config point at `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway`. No deploy timestamp, CI deploy log, or live health check was run in this investigation. |
| **Is the app connected to it?** | **Configured to be.** `project.pbxproj` sets `FORMA_AI_BACKEND_URL` to the production gateway for **both Debug and Release**. `AppContainer` wires `FormaAIBackendClient` when URL resolves. |
| **Is physical-device chat working?** | **No (observed).** User message `"hello are you working?"` → `"Coach is temporarily unavailable. Please try again later."` |
| **Most likely root cause** | **Hypothesis (ranked):** (1) **Gateway/OpenAI failure at classify step** — message requires cheap LLM classify (`/v1/ai/classify-coach-intent`), not local greeting; any HTTP/5xx/decode error becomes `backendUnavailable`. (2) **`OPENAI_API_KEY` not set in Firebase Secret Manager** or function not deployed. (3) **Installed build has missing/unsubstituted `FORMA_AI_BACKEND_URL`** → `UnavailableLLMClient` at startup. Auth failure is **less likely** for this exact copy — it surfaces a different user message. |

**Confirmed vs hypothesis**

- **Confirmed:** Error string maps to `FormaProductCopy.Error.coachUnavailable` via `AIServiceError.backendUnavailable` (or related paths).
- **Confirmed:** `"hello are you working?"` has 4 tokens → **not** a standalone local greeting → **requires network** to `classify-coach-intent`.
- **Unknown:** Whether `aiGateway` is live, whether `OPENAI_API_KEY` secret is bound, whether the failing device build baked the gateway URL into `Info.plist`.

---

# 2. Current Architecture

```text
iOS Coach UI (CoachView)
  → CoachModel.send(_:) / sendCurrentMessage()
  → CoachRouteDecider.decide()          [local guard → cheap LLM classify]
  → AIService.classifyCoachIntent()     [first network hop for fuzzy messages]
  → FallbackLLMClient
  → FormaAIBackendClient.post()
  → AuthManager.idToken()               [Firebase ID token]
  → HTTPS POST + Authorization: Bearer <token>
  → https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway/v1/ai/...
  → aiGateway (Firebase Functions v2 HTTPS)
  → verifyFirebaseAuth()                [firebase-admin verifyIdToken]
  → gatewayGuardrails (quota, body size, payload validation)
  → openAIJSON() → OpenAI Responses API  [https://api.openai.com/v1/responses]
  → JSON response
  → FormaAIBackendClient decode
  → CoachIntentRouter → CoachAIRouteHandler
  → CoachModel.appendAssistantMessage()
  → CoachMessageView / CoachConversationView
```

**Firebase project:** `fitness-coach-732fd` (`.firebaserc`)

---

# 3. iOS Chat Flow

## UI ownership

| Concern | File(s) |
|---------|---------|
| Coach tab shell | `Fitness Coach/App/MainTabView.swift` |
| Coach screen | `Fitness Coach/Features/Coach/CoachView.swift` |
| Conversation list / typing indicator | `Fitness Coach/Features/Coach/Components/CoachConversationView.swift` |
| Message bubbles | `Fitness Coach/Features/Coach/Components/CoachMessageView.swift` |
| Composer | `Fitness Coach/Features/Coach/Components/CoachComposer.swift` (referenced from `CoachView`) |
| Auth retry banner | `Fitness Coach/Features/Coach/Components/CoachErrorView.swift` |

## State ownership

| Concern | File(s) |
|---------|---------|
| Chat state (`messages`, `inputText`, `isSending`, errors) | `Fitness Coach/Features/Coach/Model/CoachModel.swift` |
| Model factory | `AppContainer.makeCoachModel()` in `Fitness Coach/App/AppContainer.swift` |
| Domain message type | `Fitness Coach/Domain/Models/ChatMessage.swift` |

## Send pipeline

1. **User sends** — `CoachView` → `CoachModel.sendCurrentMessage()` → `send(_:)`.
2. **Trace** — `FormaPipelineTracer.beginTrace` (DEBUG only; no-op in Release).
3. **Append user bubble** — `appendUserMessage`.
4. **Route** — `processCoachMessage` → `CoachRouteDecider.decide(text:context:aiService:config:)`.
5. **Handle route** — `CoachAIRouteHandler.handle`.
6. **Apply result** — `applyActionResult` → `appendAssistantMessage` if non-empty.

## Request payload construction

- **Context:** `CoachContextBuilder.makeContext(recentMessages:workoutsToday:)` (`CoachAIContextBuilder.swift`).
- **Classify (first hop for `"hello are you working?"`):**
  - `AIService.classifyCoachIntent` builds `AICoachIntentClassificationRequest` with `text`, `context`, `modelName` (`CoachModelConfig.cheapClassifierModel`), `modelConfig` (`CoachIntentResult.swift`).
  - POST body to `/v1/ai/classify-coach-intent`.
- **Downstream tasks** (meal advice, food estimate, etc.) use other `AIService` methods → matching `LLMEndpoint` paths.

## Response rendering

- **Local/no-AI routes:** deterministic strings from `CoachResponseBuilder`.
- **AI routes:** handler returns `CoachActionResult.message` → `appendAssistantMessage`.
- **Pending confirmations:** `CoachConfirmationBar` + optional `AIFoodConfirmationSheet`.

## Loading / error states

| State | Behavior |
|-------|----------|
| `isSending` | Typing indicator in `CoachConversationView` |
| `AIServiceError.authenticationFailed` | Empty bubble + `CoachErrorView` banner (`coachSessionTitle` / `coachSessionMessage`) + retry refreshes token |
| Other `AIServiceError` | Assistant bubble with `error.userMessage` |
| Unexpected errors | `AIServiceError.requestFailed(...).userMessage` |

## Where `"Coach is temporarily unavailable"` is generated

| Source | Path |
|--------|------|
| **User-facing string** | `FormaProductCopy.Error.coachUnavailable` in `Fitness Coach/Domain/Copy/FormaProductCopy.swift` |
| **AIService mapping** | `AIServiceError.backendUnavailable`, `.requestFailed`, `.featureDisabled` → `coachUnavailable` (`AIServiceError.swift`) |
| **Direct builder** | `CoachResponseBuilder.backendUnavailableResponse` (`CoachResponseBuilder.swift`) when AI disabled / no service |
| **LLM client** | `UnavailableLLMClient` → `LLMClientError.missingConfiguration` → `AICommandParser.map` → `.backendUnavailable` |
| **Fallback wrapper** | `FallbackLLMClient` catches most errors → `LLMClientError.backendUnavailable` |

**Not this message:** `authenticationFailed` → `"We couldn't verify your session. Check your connection and try again."`

## Message-specific routing: `"hello are you working?"`

1. `LocalNoAPIGuard`: 4 tokens → **not** standalone greeting (`tokens.count <= 3` required; `LocalNoAPIGuard.swift`).
2. Local parser → typically `.needsAI` → `.passToCheapLLM`.
3. **`CheapLLMIntentClassifier`** → `AIService.classifyCoachIntent` → **HTTP required**.
4. On success with `general_conversation` → local `greetingResponse` (no second API call).
5. On failure → `AIServiceError.backendUnavailable` → unavailable copy.

---

# 4. Auth Flow for AI Requests

## Firebase initialization

- `Fitness_CoachApp.init()` calls `FirebaseApp.configure()` before `AppContainer()` (`Fitness Coach/App/Fitness_CoachApp.swift`).

## Google sign-in / session restore

- `AuthManager.startListening()` attaches `Auth.auth().addStateDidChangeListener`.
- Google sign-in: `signInWithGoogle()` → `GIDSignIn` → `GoogleAuthProvider.credential` → `Auth.auth().signIn(with:)`.
- **Session policy:** `AuthSessionPolicy` accepts **only Google** provider sessions; non-Google Firebase users are signed out (`AuthSignInSupport.swift`).

## ID token retrieval

```swift
// AuthManager.idToken(forceRefresh:)
// → refreshIDToken → currentUser.getIDToken(forcingRefresh:)
```

**Eligibility:** `AuthTokenPolicy.eligibility` requires `hasUser && isGoogleUser` (`AuthSignInSupport.swift`). Otherwise `AuthManagerError.notSignedIn`.

## Attached to AI requests?

**Yes**, when `FormaAIBackendClient` is wired with `authTokenProvider`:

```swift
// AppContainer.swift (non-inMemory)
FormaAIBackendClient(
    baseURL: backendURL,
    authTokenProvider: { try await authManager.idToken() }
)
```

## Authorization header format

```http
Authorization: Bearer <Firebase ID token JWT>
Content-Type: application/json
Accept: application/json
X-Forma-Trace-Id: <UUID>   # DEBUG only when FormaPipelineTracer active; nil in Release
```

Set in `FormaAIBackendClient.post()` (`FormaAIBackendClient.swift`).

## Token retrieval failure

| Failure | Client behavior |
|---------|-----------------|
| `AuthManagerError.notSignedIn` / `missingToken` | `LLMClientError.authenticationFailed` |
| Other errors | `LLMClientError.authenticationFailed` |
| Mapped to user | `AIServiceError.authenticationFailed` → session message (not unavailable copy) |

## Signed-out users and Coach

- Main tab (`MainTabView`) is behind auth gate; Coach is not intended for anonymous use.
- If a Google-signed-in user exists, token is attached. **Non-Google sign-in is rejected** by session policy even if Firebase has a user.

---

# 5. Backend URL Configuration

## Where `FORMA_AI_BACKEND_URL` is defined

| Location | Value |
|----------|-------|
| Xcode user-defined build setting | `Fitness Coach.xcodeproj/project.pbxproj` — **Debug & Release:** `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway` |
| Info.plist injection | `AppURLSchemes.plist` → `<key>FORMA_AI_BACKEND_URL</key><string>$(FORMA_AI_BACKEND_URL)</string>` |
| Code constant (reference) | `AIBackendConfiguration.productionGatewayURLString` |
| Legacy alias | `FITPILOT_AI_BACKEND_URL` via `FormaEnvironment` |

## Resolution order (`AIBackendConfiguration.backendURL`)

1. Process environment (`FORMA_AI_BACKEND_URL` / legacy)
2. `Info.plist` bundled value (build-time substitution)
3. Reject empty, invalid URL, non-http(s), or **localhost** hosts

## Debug vs Release vs TestFlight

| Build | Expected URL | Notes |
|-------|--------------|-------|
| Debug | Same production gateway URL in `pbxproj` | Docs: no localhost fallback |
| Release | Same production gateway URL | |
| TestFlight / Archive | Same if CI/archive preserves build setting | **Risk:** archive with empty `FORMA_AI_BACKEND_URL` → `UnavailableLLMClient` |

## Local backend URL

- **Rejected at runtime** for `localhost`, `127.0.0.1`, `::1`, `0.0.0.0`.
- `Tools/LocalAIBackend` — **does not exist** in repo.
- `LocalAIBackendConfiguration.swift` — **removed** (only stale `.derivedData` references).
- Port `8787` — **only in unit tests** as rejected localhost example (`AIBackendConfigurationTests.swift`).

## Simulator vs device

- **No separate URLs** in code; same `Info.plist` / env resolution.
- Physical device cannot use Mac `localhost` gateway (and app blocks localhost anyway).

## Fail-fast if URL missing

```swift
// AppContainer — else branch
llmClient = UnavailableLLMClient(reason: AIBackendConfiguration.unavailableReason())
```

All LLM calls throw `LLMClientError.missingConfiguration` immediately — no mock answers.

## Stale build cache note

`.derivedData/.../TARGET@...json` once showed `FORMA_AI_BACKEND_URL=""` — **hypothesis:** local derived build artifact may not reflect current `pbxproj`. **Verify on device** via DEBUG `FormaPipelineTracer` startup log or `Settings` diagnostics if available.

---

# 6. Firebase aiGateway Server

| Property | Value |
|----------|-------|
| **Function name** | `aiGateway` |
| **Export** | `export const aiGateway = onRequest(...)` (`functions/src/index.ts`) |
| **Region** | **Not explicit in code** → Firebase default for project; **URL implies `us-central1`** |
| **Public URL (base)** | `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway` |
| **Runtime** | Node 24 (`functions/package.json`) |
| **Timeout** | `timeoutSeconds: 90` |
| **Memory** | `512MiB` |
| **Max instances** | `10` (`setGlobalOptions`) |
| **CORS** | `cors: false` (fine for native iOS `URLSession`) |

## Routes

| Path | Handler | Response shape |
|------|---------|----------------|
| `POST /v1/ai/classify-coach-intent` | `classifyCoachIntent` | `{ intentResult: {...} }` |
| `POST /v1/ai/parse-command` | `parseCommand` | `{ parsedCommand: {...} }` |
| `POST /v1/ai/estimate-food` | `estimateFood` | `{ foodDrafts, confidence, requiresConfirmation, assistantMessage }` |
| `POST /v1/ai/generate-meal-advice` | `coachResponse` | `{ response: { message, confidence, followUpSuggestions } }` |
| `POST /v1/ai/generate-daily-review` | `coachResponse` | `{ response: {...} }` |
| `POST /v1/ai/parse-workout` | `parseWorkout` | `{ workoutDraft, assistantMessage, confidence }` |
| `POST /v1/ai/parse-edit-delete` | `parseEditDelete` | `{ parsedCommand: {...} }` |
| `POST /v1/ai/parse-multi-action` | `parseMultiAction` | `{ parsedCommand: {...} }` |
| `OPTIONS *` | 204 empty | Preflight |
| Other methods | 405 | `{ error: "Method not allowed." }` |
| Unknown path | 404 | `{ error: "Endpoint not found." }` |

## Auth requirements

- Default: **Firebase ID token required** (`verifyFirebaseAuth`).
- Bypass: `FORMA_AI_REQUIRE_AUTH=0` (emulator/testing only; `functions/.env.example`).
- Missing/invalid token → **401** `{ error: "Missing Firebase ID token." }` or `{ error: "Invalid Firebase ID token." }`.

## Request schema (classify example)

```json
{
  "text": "string",
  "context": { "date", "timezoneIdentifier", "commonFoods", "recentMessages", ... },
  "modelName": "gpt-5-nano",
  "modelConfig": { "cheapClassifierModel", "cheapAnswerModel", "strongCoachModel" }
}
```

Validated in `gatewayGuardrails.ts` (`validatePayload`).

## Error responses

- `GatewayError` → HTTP status from error (400, 401, 413, 429, etc.) + `{ error: "message" }`.
- Other exceptions → **500** + `{ error: message }`.
- Logged via `logger.error("AI gateway request failed", { traceId, status, message, durationMs })`.

## Logging

- **Incoming:** `logger.info("AI gateway request received", { traceId, path, uid, bodyBytes })`.
- **OpenAI:** `OpenAI request started` / `completed` / `failed` with `traceId`, `model`, token usage.
- **Completed:** `AI gateway request completed` with `model`, `durationMs`.
- **Trace header:** `X-Forma-Trace-Id` or legacy `X-FitPilot-Trace-Id`.

## Guardrails (`gatewayGuardrails.ts`)

- Body size: 512KB default; 2MB with image.
- Text/question max 4000 chars.
- Rate limits: 30/min burst, 400/day per UID (in-memory; resets on cold start).

---

# 7. OpenAI Integration

| Item | Detail |
|------|--------|
| **Endpoint** | `POST https://api.openai.com/v1/responses` |
| **Default models** | `gpt-5-nano` (cheap/default), `gpt-5.4-nano` (strong), `gpt-5.4-mini` (fallback) — `DEFAULT_MODELS` in `index.ts` |
| **iOS model config** | `CoachModelConfig.default` in `CoachIntentResult.swift` (matches smoke script) |
| **Overrides** | Request `modelName` / `modelTier`; env `OPENAI_CLASSIFIER_MODEL`, `OPENAI_MODEL`, `OPENAI_STRONG_MODEL`, `OPENAI_FALLBACK_MODEL` |
| **API key loading** | `defineSecret("OPENAI_API_KEY")` → `openAIAPIKey.value()` at call time |
| **Missing secret** | `GatewayError(500, "OPENAI_API_KEY is not configured.")` |
| **iOS bundles OpenAI key?** | **No** — grep shows no `OPENAI` / `API_KEY` in `Fitness Coach/` Swift sources |
| **Secret Manager** | Documented: `firebase functions:secrets:set OPENAI_API_KEY` |

## Risks

| Risk | Severity |
|------|----------|
| Secret not created or not bound to `aiGateway` | **High** — 500 on every OpenAI call |
| Model names (`gpt-5-nano`, etc.) invalid in OpenAI account | **High** — OpenAI 4xx → gateway 500 |
| OpenAI quota/billing | **Medium** |
| `functions/.env` not copied | **Low** — defaults exist in code |

---

# 8. Local Backend / .env Situation

| Item | Status |
|------|--------|
| `Tools/LocalAIBackend` | **Does not exist** |
| `LocalAIBackendConfiguration.swift` | **Removed** from source (derived data only) |
| `FORMA_USE_MOCK_LLM` | **Not referenced** in current source |
| Root `.env` | **Exists**, **gitignored** (`.gitignore`). Purpose **UNKNOWN** without inspection; not read by iOS app per docs. |
| `functions/.env` | **Optional** — copy from `functions/.env.example` for deploy-time model overrides |
| `functions/.env.example` | Documents non-secret model env vars; explicitly says **do not** put `OPENAI_API_KEY` in file |

## Dev-only

- Root `.env` — dev-only / local tooling (not wired to iOS).
- `functions/.env` — deploy defaults only.
- `MockLLMClient` — `AppContainer(inMemory: true)` previews/tests only.

## Hosted-gateway-only cleanup

Safe to remove if committed anywhere: localhost URL docs, stale derived-data references, any resurrected `LocalAIBackend*` files.

## Risks of keeping local path

- Developers might set scheme env to `localhost:8787` → app rejects → `UnavailableLLMClient`.
- Confusion in docs/runbooks vs production-only direction.

---

# 9. Smoke Test Status

## `smoke:auth`

- **Script:** `functions/scripts/smoke-ai-gateway-auth.mjs`
- **npm script:** `npm --prefix functions run smoke:auth`
- **Default base URL:** production `aiGateway` URL

## Without credentials (verified this session)

```text
No auth configured. Set FORMA_ID_TOKEN, or FIREBASE_TEST_EMAIL + FIREBASE_TEST_PASSWORD + FIREBASE_WEB_API_KEY
exit code: 1
```

**Why exit 1 is expected:** `resolveIdToken()` throws before any HTTP call.

## With credentials

```sh
# Option A
FORMA_ID_TOKEN='…' npm --prefix functions run smoke:auth

# Option B
FIREBASE_WEB_API_KEY='…' \
FIREBASE_TEST_EMAIL='…' \
FIREBASE_TEST_PASSWORD='…' \
npm --prefix functions run smoke:auth
```

## What passing proves

- Gateway reachable over HTTPS
- Firebase token accepted (401 path not taken)
- All 4 scenarios return HTTP 200 with expected JSON
- OpenAI secret works end-to-end (live OpenAI calls)

## What it does NOT prove

- iOS `Info.plist` URL on a physical device build
- iOS token attachment timing / Google-only `AuthTokenPolicy`
- Release-build observability (`FormaPipelineTracer` is no-op)
- UI routing after classify

## Still required on real device

1. Sign in with **Google** (required for token eligibility).
2. Coach → send classify-dependent message.
3. Correlate with Firebase logs if DEBUG trace available.

---

# 10. Current Failure Analysis

**Observed:** User sends `"hello are you working?"` → `"Coach is temporarily unavailable. Please try again later."`

## Plausible failure points

| # | Failure point | Maps to unavailable copy? | Notes |
|---|---------------|----------------------------|-------|
| 1 | `UnavailableLLMClient` at startup (missing/localhost URL) | **Yes** | No HTTP; immediate `missingConfiguration` |
| 2 | iOS request not sent | **Yes** | Would surface via `FallbackLLMClient` |
| 3 | Wrong backend URL | **Yes** | DNS/404/non-JSON → `backendUnavailable` |
| 4 | Missing `Authorization` header | Unlikely this copy | Would be 401 → **session message**, not unavailable |
| 5 | Invalid/expired Firebase token | Unlikely this copy | 401 → session message |
| 6 | User not Google-signed-in | Unlikely this copy | `authenticationFailed` → session message |
| 7 | Function not deployed / wrong project | **Yes** | Connection error or 404 HTML |
| 8 | `OPENAI_API_KEY` missing | **Yes** | Gateway 500 |
| 9 | Gateway exception / OpenAI error | **Yes** | 500 → `invalidStatusCode` → `backendUnavailable` |
| 10 | OpenAI quota/model failure | **Yes** | Logged server-side; client sees unavailable |
| 11 | Response parsing failure | **Yes** | `FallbackLLMClient` maps decode errors to `backendUnavailable` |
| 12 | Timeout (>45s request) | **No** | Would show `"Coach took too long to respond"` |

## Ranked by likelihood (given repo + symptom)

1. **Gateway not deployed, secret missing, or OpenAI call failing (500)** — classify is first network hop; server-side issues fit symptom.
2. **Physical device build missing substituted `FORMA_AI_BACKEND_URL`** — `UnavailableLLMClient`; fits symptom; check DEBUG wiring log.
3. **Network/connectivity/TLS issue on device** — possible; maps to `requestFailed` → unavailable.
4. **Response schema mismatch** — possible if gateway returns unexpected shape; still shows unavailable due to `FallbackLLMClient`.
5. **Wrong URL in an older sideloaded build** — possible if not rebuilt from current `pbxproj`.
6. **Auth problems** — **lower** for this exact user-facing string.

---

# 11. Required Logs to Confirm Root Cause

## Xcode console (physical device)

Filter OSLog:

| Subsystem | Category | When |
|-----------|----------|------|
| `Forma` | `AIBackend` | URL missing/invalid at resolve |
| `FitPilot` | `UnavailableLLM` | Startup `UnavailableLLMClient` |
| `FitPilot` | `LLMFallback` | Primary client failed (Release-visible) |
| `Forma` | `CoachAI` | **DEBUG only** — AIService LLM errors |
| `Forma` | `PipelineTrace` | **DEBUG only** — full HTTP trace |

**Release gap:** `FormaPipelineTracer` is a **no-op** in Release (`#else` stub). No `X-Forma-Trace-Id` on device Release builds.

### DEBUG startup wiring (look for)

```text
stage=appWiring message="LLM client wired" clientType=FallbackLLMClient+FormaAIBackendClient authAttached=true baseURL=...
```

or

```text
clientType=UnavailableLLMClient authAttached=false
```

### DEBUG classify failure (look for)

```text
stage=classify message="Intent classification failed"
stage=httpResponse message="HTTP non-success status" status=...
stage=aiTask message="AIService LLM client error" llmError=...
```

## Firebase Functions logs

```sh
firebase functions:log --only aiGateway --project fitness-coach-732fd
```

Or Google Cloud Console → Cloud Functions → `aiGateway` → Logs.

Filter for:

- `AI gateway request received`
- `AI gateway request failed`
- `OpenAI request failed`
- `OPENAI_API_KEY is not configured`

With trace (DEBUG iOS only):

```sh
firebase functions:log --only aiGateway --project fitness-coach-732fd | rg '<trace-uuid>'
```

## Secret Manager / config

```sh
firebase functions:secrets:access OPENAI_API_KEY --project fitness-coach-732fd
# Do not paste output into tickets — only verify exit 0 / secret exists

firebase functions:secrets:get OPENAI_API_KEY --project fitness-coach-732fd
```

Verify function binding in deployed config (Console → Functions → `aiGateway` → Configuration → Secrets).

## Smoke test (authenticated)

```sh
FORMA_ID_TOKEN='…' npm --prefix functions run smoke:auth
```

## OpenAI dashboard

- Usage → confirm requests after smoke or device test
- Errors for model name / billing

---

# 12. Production Readiness Checklist

| Area | Status | Evidence | Risk | Next Action |
|------|--------|----------|------|-------------|
| Firebase deployment | **UNKNOWN** | Code + docs exist; no deploy proof in repo | High | `firebase deploy --only functions:aiGateway` + verify URL responds 401 without token |
| Secret Manager | **UNKNOWN** | `defineSecret("OPENAI_API_KEY")` in code | High | `firebase functions:secrets:set OPENAI_API_KEY` + redeploy |
| iOS backend URL | **CONFIGURED** | `pbxproj` Debug/Release both set production URL | Medium | Verify on-device `Info.plist` / DEBUG wiring log |
| Auth token attachment | **IMPLEMENTED** | `AppContainer` + `FormaAIBackendClient` | Medium | Confirm Google sign-in on test device |
| Real-device request | **FAILING** | User report | High | Capture DEBUG trace or Firebase logs |
| Gateway invocation | **UNKNOWN** | No server logs reviewed | High | Run `smoke:auth` with token |
| OpenAI call | **UNKNOWN** | Depends on secret + models | High | Smoke test + OpenAI dashboard |
| Error observability | **WEAK (Release)** | `FormaPipelineTracer` DEBUG-only | High | Add safe Release diagnostics (see sprint) |
| Timeout behavior | **OK** | 45s/90s client; 90s function | Low | Monitor latency in logs |
| Release/TestFlight config | **CONFIGURED in repo** | Same URL Debug/Release | Medium | Confirm archive CI sets `FORMA_AI_BACKEND_URL` |
| Local backend removal | **DONE** | No `LocalAIBackend` source | Low | Clean stale docs/derived data references |
| Smoke tests | **PARTIAL** | Contract tests + `smoke:auth` script; auth run not executed | Medium | Run authenticated smoke |
| E2E physical-device test | **FAILING** | User report | High | Google sign-in + classify message + logs |

---

# 13. Recommended Next Sprint

1. **Add DEBUG-only AI request diagnostics** — extend `FormaPipelineTracer` or guarded OSLog in `FormaAIBackendClient` (status, endpoint, `authHeaderPresent`; never log token).
2. **Verify physical-device backend URL** — DEBUG build on device; confirm `LLM client wired` + `baseURL`.
3. **Verify Authorization header** — confirm `authHeaderPresent=true` in HTTP trace; user signed in via Google.
4. **Inspect Firebase logs** — during reproduce; look for 401 vs 500 vs no invocations.
5. **Run authenticated smoke test** — `npm --prefix functions run smoke:auth` with `FORMA_ID_TOKEN` or test user.
6. **Fix root cause** — likely secret/deploy/OpenAI model or URL substitution in installed build.
7. **Remove local backend references** — stale derived data / any docs mentioning `8787` as active path.
8. **Add E2E regression checklist** — automate `smoke:auth` in CI with secrets; manual device checklist in `ReleaseAI.md`.

---

# 14. Exact Cursor Follow-Up Prompts

### Diagnose current unavailable error

```text
Physical device shows "Coach is temporarily unavailable" for "hello are you working?".
Using FORMA_AI_API_SERVER_CONTEXT_PACKET.md, trace CoachModel → CoachRouteDecider → AIService.classifyCoachIntent → FormaAIBackendClient.
Add DEBUG-only logs to confirm: resolved baseURL, authHeaderPresent, HTTP status, and whether UnavailableLLMClient was wired at startup.
Do not log tokens. Propose minimal diff.
```

### Remove local AI backend path

```text
Audit the repo for any remaining LocalAIBackend, localhost:8787, or FORMA_USE_MOCK_LLM references outside tests.
Confirm AIBackendConfiguration rejects localhost and AppContainer never wires a local client.
Remove stale references and update Docs if needed.
```

### Harden iOS backend URL config

```text
Review FORMA_AI_BACKEND_URL resolution (FormaEnvironment, AIBackendConfiguration, AppURLSchemes.plist, project.pbxproj).
Add a fail-fast DEBUG assertion or startup log when Info.plist contains unsubstituted "$(FORMA_AI_BACKEND_URL)".
Ensure Archive/TestFlight builds cannot ship with empty URL.
```

### Add debug logs safely

```text
In FormaAIBackendClient.post and AppContainer LLM wiring, add DEBUG-only OSLog (subsystem Forma, category AIGateway) for endpoint, status code, durationMs, authHeaderPresent, and gateway error snippet (redacted).
Keep Release behavior unchanged unless behind a new FORMA_AI_DEBUG_NETWORK flag default off.
```

### Validate Firebase Secret Manager

```text
Document and script verification steps for OPENAI_API_KEY on project fitness-coach-732fd:
firebase functions:secrets:get, deploy aiGateway with secrets binding, and interpret 500 "OPENAI_API_KEY is not configured" in functions logs.
No secret values in output.
```

### Physical-device E2E test

```text
Create a step-by-step physical device test plan:
1) DEBUG build on iPhone, Google sign-in
2) Filter Console for Forma/PipelineTrace and FitPilot/LLMFallback
3) Send "hello are you working?"
4) Capture traceId and correlate with firebase functions:log --only aiGateway
5) Pass/fail criteria per Docs/ReleaseAI.md
```

### Improve user-facing error messages

```text
Today AIServiceError.backendUnavailable and FallbackLLMClient collapse auth, 500, decode, and network into one message.
Propose a mapping table that keeps security constraints but distinguishes: not configured, network offline, server error, session expired — without exposing raw gateway payloads.
```

---

# Current Truth

## What is confirmed working (in code)

- End-to-end **architecture** from `CoachView` → `FormaAIBackendClient` → `aiGateway` → OpenAI Responses API is implemented and documented.
- **Production gateway URL** is set in Xcode for Debug and Release.
- **Firebase ID token** attachment is implemented for live clients.
- **Localhost / missing URL fail-fast** via `UnavailableLLMClient`.
- **OpenAI key is server-side only** (`defineSecret`); not in iOS sources.
- **Contract tests** and **smoke script** exist; `smoke:auth` correctly exits 1 without credentials.

## What is not confirmed

- `aiGateway` is **deployed and healthy** in `fitness-coach-732fd`.
- `OPENAI_API_KEY` is **set and bound** to the function.
- OpenAI **model names** work on the configured account.
- The **failing physical device build** has a valid substituted `FORMA_AI_BACKEND_URL`.
- User was **Google-signed-in** with eligible token at time of failure.

## What is currently broken

- **Physical-device Coach chat** returns unavailable for a classify-dependent message (user-observed).

## Next single best action

**Run authenticated `smoke:auth` against production** (with `FORMA_ID_TOKEN` from a signed-in device or test Firebase user). If smoke fails → fix gateway/secret/OpenAI server-side. If smoke passes → attach DEBUG build to the device, reproduce once, and read `LLM client wired` + HTTP status logs to isolate iOS URL/auth vs server issues.
