# FitPilot Local AI Backend

Local development gateway for the Coach AI boundary.

The iOS app should not embed provider API keys. This gateway reads `.env`, calls
OpenAI from your Mac, and exposes the same FitPilot endpoints the app already
expects.

## Run

```sh
node Tools/LocalAIBackend/server.mjs
```

### Simulator

In debug builds, the app uses `http://127.0.0.1:8787` automatically and falls
back to `MockLLMClient` if the gateway is unavailable.

### Physical iPhone (same Wi‑Fi)

1. Copy `.env.example` → `.env` and set `OPENAI_API_KEY`.
2. Ensure `.env` includes `FITPILOT_AI_BACKEND_HOST=0.0.0.0` so the gateway
   listens on your Mac's LAN address (not just localhost).
3. Start the gateway: `node Tools/LocalAIBackend/server.mjs`
4. Point the app at your Mac using **one** of:
   - **Scheme env var** (recommended): Product → Scheme → Edit Scheme → Run →
     Arguments → Environment Variables →
     `FITPILOT_AI_BACKEND_URL` = `http://<your-mac-ip>:8787`
   - **Bundled plist**: `node Tools/LocalAIBackend/configure-device-backend.mjs --write`
     (writes `Fitness Coach/DeveloperLocal.plist`, gitignored — rebuild on device)

Print the URL without writing files:

```sh
node Tools/LocalAIBackend/configure-device-backend.mjs
```

To skip the backend entirely (no connection-refused noise), set the scheme
environment variable `FITPILOT_USE_MOCK_LLM=1`.

## Environment

Create `.env` from `.env.example` and set:

- `OPENAI_API_KEY`
- `OPENAI_CLASSIFIER_MODEL` (default `gpt-5-nano`) — intent classification and cheap-tier tasks
- `OPENAI_MODEL` (default `gpt-5-nano`) — default for parsing, food estimate, daily review
- `OPENAI_STRONG_MODEL` (default `gpt-5.4-nano`) — complex coaching when iOS sends `modelTier: strong`
- `OPENAI_FALLBACK_MODEL` (default `gpt-5.4-mini`) — reserved for rare manual/eval fallback; not used as default
- `FITPILOT_AI_BACKEND_PORT` (default `8787`)
- `FITPILOT_AI_BACKEND_HOST` — use `0.0.0.0` for device testing over Wi‑Fi
- `FITPILOT_AI_BACKEND_TRACE` — set `0` to disable gateway JSON trace logs (default on)
- `FITPILOT_AI_BACKEND_TRACE_VERBOSE` — set `1` to include truncated request/response bodies

The gateway maps iOS `modelTier` (`cheap` / `strong`) to these env vars through a safe
allowlist. Untrusted `modelName` values from the client are ignored unless they match
one of the configured models.

### Pipeline tracing

Gateway logs one JSON object per line to stdout. Filter by trace ID (matches iOS `X-Forma-Trace-Id`):

```sh
node Tools/LocalAIBackend/server.mjs 2>&1 | rg '"traceId":"YOUR-UUID"'
```

On iOS (DEBUG builds): Settings → Developer → **Pipeline traces**, or filter Console with `subsystem:FitPilot category:PipelineTrace`.

- `FITPILOT_PIPELINE_TRACE=0` — disable iOS pipeline tracing
- `FITPILOT_PIPELINE_TRACE_VERBOSE=1` — include sanitized JSON body snippets in traces

## Production (Release / TestFlight)

This folder is for **local development only**. Production uses Firebase `aiGateway`:

- URL: `https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway` (base URL; iOS appends `/v1/ai/...`)
- Deploy: `firebase functions:secrets:set OPENAI_API_KEY` then `firebase deploy --only functions:aiGateway`
- Details: [Docs/ReleaseAI.md](../../Docs/ReleaseAI.md), [Docs/BackendAPI.md](../../Docs/BackendAPI.md)
