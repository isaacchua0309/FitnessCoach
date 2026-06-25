# FitPilot Local AI Backend

Local development gateway for the Coach AI boundary.

The iOS app should not embed provider API keys. This gateway reads `.env`, calls
OpenAI from your Mac, and exposes the same FitPilot endpoints the app already
expects.

## Run

```sh
node Tools/LocalAIBackend/server.mjs
```

Then run the app in the simulator. In debug builds, `AppContainer` points Coach
AI traffic at `http://127.0.0.1:8787` and falls back to `MockLLMClient` if the
gateway is unavailable.

## Environment

Create `.env` from `.env.example` and set:

- `OPENAI_API_KEY`
- `OPENAI_MODEL`
- `FITPILOT_AI_BACKEND_PORT`
