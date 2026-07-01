#!/usr/bin/env node
/**
 * Authenticated E2E smoke test for production aiGateway.
 *
 * Requires a Firebase ID token (never log or commit tokens).
 *
 * Option A — paste token from a signed-in Release app:
 *   FORMA_ID_TOKEN='…' node functions/scripts/smoke-ai-gateway-auth.mjs
 *
 * Option B — sign in with a test Firebase Auth user:
 *   FIREBASE_WEB_API_KEY='…' \
 *   FIREBASE_TEST_EMAIL='…' \
 *   FIREBASE_TEST_PASSWORD='…' \
 *   node functions/scripts/smoke-ai-gateway-auth.mjs
 *
 * Optional:
 *   FORMA_AI_BACKEND_URL (default: production cloudfunctions URL)
 *   FORMA_SMOKE_TRACE_ID (default: random UUID per run)
 */

const DEFAULT_BASE_URL =
  "https://us-central1-fitness-coach-732fd.cloudfunctions.net/aiGateway";

const REQUEST_TIMEOUT_MS = 90_000;

const baseURL = (process.env.FORMA_AI_BACKEND_URL || DEFAULT_BASE_URL).replace(/\/$/, "");
const traceId = process.env.FORMA_SMOKE_TRACE_ID || crypto.randomUUID();

const sampleContext = {
  date: new Date().toISOString(),
  timezoneIdentifier: Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC",
  commonFoods: [],
  recentMessages: [],
};

const modelConfig = {
  cheapClassifierModel: "gpt-5-nano",
  cheapAnswerModel: "gpt-5-nano",
  strongCoachModel: "gpt-5.4-nano",
};

/** @type {Array<{name: string, path: string, body: Record<string, unknown>, assert: (json: Record<string, unknown>) => void}>} */
const scenarios = [
  {
    name: "Coach classify",
    path: "/v1/ai/classify-coach-intent",
    body: {
      text: "Should I eat a McDonald's double cheeseburger tonight?",
      context: sampleContext,
      modelName: modelConfig.cheapClassifierModel,
      modelConfig,
    },
    assert(json) {
      const intent = json?.intentResult?.intent;
      if (typeof intent !== "string" || !intent.length) {
        throw new Error("Missing intentResult.intent");
      }
      const nutritionLike = [
        "meal_decision",
        "nutrition_advice",
        "calorie_lookup",
        "macro_lookup",
        "weight_loss_advice",
        "general_conversation",
      ];
      if (!nutritionLike.includes(intent)) {
        throw new Error(`Unexpected intent for burger question: ${intent}`);
      }
    },
  },
  {
    name: "Food estimate",
    path: "/v1/ai/estimate-food",
    body: {
      text: "Estimate calories for a double cheeseburger from McDonald's",
      context: sampleContext,
    },
    assert(json) {
      if (!Array.isArray(json?.foodDrafts) || json.foodDrafts.length === 0) {
        throw new Error("Missing foodDrafts");
      }
      if (typeof json.confidence !== "string") {
        throw new Error("Missing confidence");
      }
    },
  },
  {
    name: "Meal advice",
    path: "/v1/ai/generate-meal-advice",
    body: {
      question:
        "I was thinking about a McDonald's double cheeseburger tonight. Given my day so far, what do you recommend?",
      context: sampleContext,
      modelTier: "strong",
    },
    assert(json) {
      const message = json?.response?.message;
      if (typeof message !== "string" || message.trim().length < 20) {
        throw new Error("Missing or too-short response.message");
      }
    },
  },
  {
    name: "Parse workout (optional)",
    path: "/v1/ai/parse-workout",
    body: {
      text: "Bench press 5x5 at 90kg",
      context: sampleContext,
    },
    assert(json) {
      if (!json?.workoutDraft || typeof json.workoutDraft !== "object") {
        throw new Error("Missing workoutDraft");
      }
    },
  },
];

async function resolveIdToken() {
  if (process.env.FORMA_ID_TOKEN?.trim()) {
    return process.env.FORMA_ID_TOKEN.trim();
  }

  const email = process.env.FIREBASE_TEST_EMAIL?.trim();
  const password = process.env.FIREBASE_TEST_PASSWORD?.trim();
  const apiKey = process.env.FIREBASE_WEB_API_KEY?.trim();

  if (!email || !password || !apiKey) {
    throw new Error(
      "No auth configured. Set FORMA_ID_TOKEN, or FIREBASE_TEST_EMAIL + " +
        "FIREBASE_TEST_PASSWORD + FIREBASE_WEB_API_KEY (Firebase Web API key from " +
        "GoogleService-Info.plist, not OpenAI)."
    );
  }

  const url =
    `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  const response = await fetch(url, {
    method: "POST",
    headers: {"Content-Type": "application/json"},
    body: JSON.stringify({email, password, returnSecureToken: true}),
  });

  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const msg = payload?.error?.message || `HTTP ${response.status}`;
    throw new Error(`Firebase sign-in failed: ${msg}`);
  }

  if (!payload.idToken) {
    throw new Error("Firebase sign-in did not return idToken");
  }

  return payload.idToken;
}

/**
 * @param {object} params
 * @param {string} params.idToken
 * @param {typeof scenarios[number]} scenario
 */
async function runScenario({idToken, scenario}) {
  const url = `${baseURL}${scenario.path}`;
  const started = performance.now();
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);

  let status = 0;
  let bodyText = "";
  let json = null;
  let timedOut = false;

  try {
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${idToken}`,
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-Forma-Trace-Id": traceId,
      },
      body: JSON.stringify(scenario.body),
      signal: controller.signal,
    });

    status = response.status;
    bodyText = await response.text();
    try {
      json = JSON.parse(bodyText);
    } catch {
      json = null;
    }
  } catch (error) {
    if (error?.name === "AbortError") {
      timedOut = true;
    } else {
      throw error;
    }
  } finally {
    clearTimeout(timer);
  }

  const latencyMs = Math.round(performance.now() - started);
  let pass = false;
  let detail = "";

  if (timedOut) {
    detail = `Timed out after ${REQUEST_TIMEOUT_MS}ms`;
  } else if (status !== 200) {
    detail = json?.error || bodyText.slice(0, 200) || `HTTP ${status}`;
  } else {
    try {
      scenario.assert(json);
      pass = true;
      detail = summarizeSuccess(scenario.name, json);
    } catch (error) {
      detail = error instanceof Error ? error.message : String(error);
    }
  }

  return {
    scenario: scenario.name,
    route: scenario.path,
    status,
    latencyMs,
    timedOut,
    pass,
    detail,
  };
}

function summarizeSuccess(name, json) {
  switch (name) {
  case "Coach classify":
    return `intent=${json.intentResult?.intent}, confidence=${json.intentResult?.confidence}`;
  case "Food estimate":
    return `drafts=${json.foodDrafts?.length}, confidence=${json.confidence}, ` +
      `first=${json.foodDrafts?.[0]?.name} ~${json.foodDrafts?.[0]?.calories} kcal`;
  case "Meal advice":
    return `message=${String(json.response?.message).slice(0, 120)}…`;
  case "Parse workout (optional)":
    return `name=${json.workoutDraft?.name}, sets=${json.workoutDraft?.exerciseSets?.length ?? 0}`;
  default:
    return "OK";
  }
}

function printResults(results) {
  console.log("");
  console.log("Forma aiGateway authenticated smoke test");
  console.log(`Base URL: ${baseURL}`);
  console.log(`Trace ID: ${traceId}`);
  console.log(`Timeout budget: ${REQUEST_TIMEOUT_MS}ms per request`);
  console.log("");
  console.log("| Scenario | Route | Status | Latency | Timeout | Pass | Detail |");
  console.log("|----------|-------|--------|---------|---------|------|--------|");

  for (const row of results) {
    console.log(
      `| ${row.scenario} | ${row.route} | ${row.status || "—"} | ${row.latencyMs}ms | ` +
      `${row.timedOut ? "YES" : "no"} | ${row.pass ? "PASS" : "FAIL"} | ${row.detail} |`
    );
  }

  const failed = results.filter((r) => !r.pass);
  console.log("");
  if (failed.length === 0) {
    console.log("All scenarios passed.");
  } else {
    console.log(`${failed.length} scenario(s) failed.`);
    process.exitCode = 1;
  }

  console.log("");
  console.log("Post-run checks:");
  console.log(`  Firebase logs: firebase functions:log --only aiGateway --project fitness-coach-732fd | rg '${traceId}'`);
  console.log("  OpenAI usage: dashboard → Usage (expect new requests after this run)");
  console.log("  iOS Release: Product → Scheme → Run (Release) or Archive; sign in before Coach tests");
}

async function main() {
  const idToken = await resolveIdToken();
  const results = [];

  for (const scenario of scenarios) {
    process.stdout.write(`Running ${scenario.name}… `);
    const result = await runScenario({idToken, scenario});
    results.push(result);
    console.log(result.pass ? "PASS" : "FAIL");
  }

  printResults(results);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  console.error("");
  console.error("Manual iOS checklist: Docs/ReleaseAI.md → E2E smoke test");
  process.exitCode = 1;
});
