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
- `OPENAI_MODEL` (optional)
- `FITPILOT_AI_BACKEND_PORT` (default `8787`)
- `FITPILOT_AI_BACKEND_HOST` — use `0.0.0.0` for device testing over Wi‑Fi
- `OPENAI_CLASSIFIER_MODEL` (optional) — model for `/v1/ai/classify-coach-intent` only
- `FITPILOT_AI_BACKEND_TRACE` — set `0` to disable gateway JSON trace logs (default on)
- `FITPILOT_AI_BACKEND_TRACE_VERBOSE` — set `1` to include truncated request/response bodies

### Pipeline tracing

Gateway logs one JSON object per line to stdout. Filter by trace ID (matches iOS `X-FitPilot-Trace-Id`):

```sh
node Tools/LocalAIBackend/server.mjs 2>&1 | rg '"traceId":"YOUR-UUID"'
```

On iOS (DEBUG builds): Settings → Developer → **Pipeline traces**, or filter Console with `subsystem:FitPilot category:PipelineTrace`.

- `FITPILOT_PIPELINE_TRACE=0` — disable iOS pipeline tracing
- `FITPILOT_PIPELINE_TRACE_VERBOSE=1` — include sanitized JSON body snippets in traces
