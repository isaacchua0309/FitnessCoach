# Release AI Backend Configuration

Forma’s iOS app calls a **FitPilot AI backend gateway** over HTTP(S). The gateway holds provider keys and talks to the LLM; the app never embeds OpenAI (or other) API keys.

This document covers **Release / TestFlight / App Store** wiring. Local development behavior is unchanged in **Debug** builds.

---

## Why Release must not default to localhost

Previously, Release builds used:

```text
FITPILOT_AI_BACKEND_URL ?? "http://127.0.0.1:8787"
```

On a physical device or TestFlight build, `127.0.0.1` is the **phone itself**, not your Mac. Coach would silently fail or hang while appearing “configured.” That is a release blocker.

**Release builds now:**

- Require an explicit non-local `FITPILOT_AI_BACKEND_URL`.
- Reject `localhost`, `127.0.0.1`, `::1`, and `0.0.0.0`.
- Wire `UnavailableLLMClient` when no valid URL is present (no crash; Coach shows a friendly unavailable message).

---

## Required configuration for Release

Set the environment variable at **archive time** (CI or Xcode):

| Variable | Required in Release | Example |
|----------|---------------------|---------|
| `FITPILOT_AI_BACKEND_URL` | **Yes** — HTTPS production/staging gateway | `https://ai.your-domain.com` |

**Where to set it**

- **CI archive:** inject into the Xcode build environment before `xcodebuild archive`.
- **Xcode:** Product → Scheme → Edit Scheme → **Run** / **Archive** → Arguments → Environment Variables (for local Release runs).
- **Not** via `DeveloperLocal.plist` — that file is for Debug device testing only and is not a substitute for production config.

If the variable is missing or points at localhost, the app uses `UnavailableLLMClient`. Users see:

> Coach is temporarily unavailable. Please try again later.

Internal logs (Console / `OSLog`, subsystem `FitPilot`) record the specific reason.

---

## Debug / local development (unchanged)

Debug builds (`#if DEBUG` in `AppContainer`) keep the existing behavior:

| Priority | Source |
|----------|--------|
| 1 | `FITPILOT_USE_MOCK_LLM=1` → `MockLLMClient` |
| 2 | `FITPILOT_AI_BACKEND_URL` (scheme env) |
| 3 | `DeveloperLocal.plist` in app bundle (copy from `DeveloperLocal.plist.example`) |
| 4 | **Simulator only:** default `http://127.0.0.1:8787` |
| 5 | Physical device, unset → `MockLLMClient` |

Run the local gateway from `Tools/LocalAIBackend/` on your Mac. See `Tools/LocalAIBackend/README.md`.

---

## Code map

| File | Role |
|------|------|
| `FitPilot/App/AppContainer.swift` | Wires `LLMClient` for Debug vs Release |
| `App/LocalAIBackendConfiguration.swift` | Debug URL resolution (simulator localhost allowed) |
| `App/ReleaseAIBackendConfiguration.swift` | Release URL resolution (no localhost) |
| `Infrastructure/AI/UnavailableLLMClient.swift` | Safe failure when Release backend not configured |
| `Infrastructure/AI/FitPilotAIBackendClient.swift` | HTTP client when URL is valid |
| `Infrastructure/AI/FallbackLLMClient.swift` | Maps transport errors → `backendUnavailable` |

---

## Hosted backend status

**A production-hosted FitPilot AI gateway is not part of this repo stage.** Stage E only makes Release **safe** when that URL is absent.

Until a hosted backend is deployed and `FITPILOT_AI_BACKEND_URL` is set in the release pipeline:

- TestFlight / App Store builds will **not** call localhost.
- AI-dependent Coach features (classification, food estimate, meal advice, daily review narrative) will return the unavailable path.
- Local commands that do not need the backend (e.g. direct “log 500ml water” via local parser) continue to work where routing allows.

**Next step (outside Stage E):** deploy the gateway (see `Tools/LocalAIBackend/` contract), set `FITPILOT_AI_BACKEND_URL` in CI, and verify Coach end-to-end on a Release build.

---

## Manual validation

### Release without backend URL

1. Archive with **Release** and **no** `FITPILOT_AI_BACKEND_URL`.
2. Install on device or simulator.
3. Open Coach and send a message that requires AI (e.g. meal advice).
4. Expect: friendly unavailable copy; no network calls to `127.0.0.1` (verify in Instruments / Console).

### Release with valid URL

1. Set `FITPILOT_AI_BACKEND_URL=https://<your-gateway>` for the archive.
2. Coach AI features should hit that host with Firebase auth bearer token.

### Debug regression

1. Run Debug on simulator without env vars → local gateway on port 8787 or Mock LLM.
2. Set `FITPILOT_USE_MOCK_LLM=1` → mock client.
3. Device Debug: set scheme env or `DeveloperLocal.plist` to Mac LAN IP.

---

## Related

- [Architecture.md](./Architecture.md) — app composition and AI boundary
- [Tools/LocalAIBackend/README.md](../Tools/LocalAIBackend/README.md) — local gateway setup
