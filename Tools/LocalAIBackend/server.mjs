import http from "node:http";
import os from "node:os";
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { isTraceEnabled, isVerbose, logTrace, readTraceId, sanitizeSnippet } from "./trace.mjs";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "../..");

loadEnv(resolve(rootDir, ".env"));

const apiKey = process.env.OPENAI_API_KEY;
const model = process.env.OPENAI_MODEL || "gpt-5.4-mini";
const classifierModel = process.env.OPENAI_CLASSIFIER_MODEL || model;
const port = Number(process.env.FITPILOT_AI_BACKEND_PORT || 8787);
const host = process.env.FITPILOT_AI_BACKEND_HOST || "127.0.0.1";

if (!apiKey) {
  console.error("OPENAI_API_KEY is missing. Add it to .env before starting the gateway.");
  process.exit(1);
}

const server = http.createServer(async (request, response) => {
  const requestStarted = Date.now();
  const traceId = readTraceId(request);

  try {
    if (request.method !== "POST") {
      logTrace({
        traceId,
        stage: "httpRequest",
        level: "warn",
        message: "Method not allowed",
        fields: { method: request.method, path: request.url ?? "unknown" }
      });
      sendJSON(response, 405, { error: "Method not allowed." });
      return;
    }

    const rawBody = await readRawBody(request);
    logTrace({
      traceId,
      stage: "httpRequest",
      message: "Gateway request received",
      fields: {
        path: request.url,
        bodyBytes: rawBody.length,
        requestBody: sanitizeSnippet(rawBody.toString("utf8"))
      }
    });

    const body = JSON.parse(rawBody.toString("utf8") || "{}");
    const handlerStarted = Date.now();
    let payload;

    switch (request.url) {
      case "/v1/ai/classify-coach-intent":
        payload = { intentResult: await classifyCoachIntent(body, traceId) };
        break;
      case "/v1/ai/parse-command":
        payload = { parsedCommand: await parseCommand(body, traceId) };
        break;
      case "/v1/ai/estimate-food":
        payload = await estimateFood(body, traceId);
        break;
      case "/v1/ai/generate-meal-advice":
        payload = { response: await coachResponse(body, mealAdviceInstructions(), traceId) };
        break;
      case "/v1/ai/generate-daily-review":
        payload = { response: await coachResponse(body, dailyReviewInstructions(), traceId) };
        break;
      case "/v1/ai/parse-workout":
        payload = await parseWorkout(body, traceId);
        break;
      case "/v1/ai/parse-edit-delete":
        payload = { parsedCommand: await parseEditDelete(body, traceId) };
        break;
      case "/v1/ai/parse-multi-action":
        payload = { parsedCommand: await parseMultiAction(body, traceId) };
        break;
      default:
        logTrace({
          traceId,
          stage: "httpResponse",
          level: "warn",
          message: "Endpoint not found",
          fields: { path: request.url, durationMs: Date.now() - requestStarted }
        });
        sendJSON(response, 404, { error: "Endpoint not found." });
        return;
    }

    const handlerMs = Date.now() - handlerStarted;
    logTrace({
      traceId,
      stage: "gatewayHandler",
      message: "Gateway handler completed",
      fields: { path: request.url, durationMs: handlerMs }
    });

    const responseBody = JSON.stringify(payload);
    sendJSON(response, 200, payload);
    logTrace({
      traceId,
      stage: "httpResponse",
      message: "Gateway response sent",
      fields: {
        path: request.url,
        status: 200,
        responseBytes: responseBody.length,
        durationMs: Date.now() - requestStarted,
        responseBody: sanitizeSnippet(responseBody)
      }
    });
  } catch (error) {
    logTrace({
      traceId,
      stage: "error",
      level: "error",
      message: error.message || "AI gateway failed.",
      fields: {
        path: request.url,
        durationMs: Date.now() - requestStarted,
        errorType: error.name || "Error"
      }
    });
    console.error(error);
    sendJSON(response, 500, { error: error.message || "AI gateway failed." });
  }
});

server.listen(port, host, () => {
  console.log(`FitPilot local AI backend listening on http://${host}:${port}`);
  logTrace({
    stage: "startup",
    message: "Gateway configuration",
    fields: {
      host,
      port: String(port),
      model,
      classifierModel,
      traceEnabled: String(isTraceEnabled()),
      traceVerbose: String(isVerbose())
    }
  });
  if (host === "0.0.0.0") {
    for (const address of lanIPv4Addresses()) {
      console.log(`  Device / LAN URL: http://${address}:${port}`);
    }
    console.log("  iOS: set FITPILOT_AI_BACKEND_URL in the Xcode scheme, or run:");
    console.log("    node Tools/LocalAIBackend/configure-device-backend.mjs --write");
  }
});

function lanIPv4Addresses() {
  const addresses = [];
  for (const interfaces of Object.values(os.networkInterfaces())) {
    for (const net of interfaces ?? []) {
      if (net.family === "IPv4" && !net.internal) {
        addresses.push(net.address);
      }
    }
  }
  return addresses;
}

function loadEnv(path) {
  let raw = "";
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return;
  }

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const index = trimmed.indexOf("=");
    if (index === -1) continue;
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim().replace(/^['"]|['"]$/g, "");
    if (!process.env[key]) process.env[key] = value;
  }
}

async function readRawBody(request) {
  const chunks = [];
  for await (const chunk of request) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

async function readJSON(request) {
  const raw = await readRawBody(request);
  return JSON.parse(raw.toString("utf8") || "{}");
}

function sendJSON(response, statusCode, payload) {
  response.writeHead(statusCode, {
    "Content-Type": "application/json",
    "Cache-Control": "no-store"
  });
  response.end(JSON.stringify(payload));
}

async function openAIJSON({ instructions, input, schema, maxOutputTokens = 1200, model: modelOverride, traceId }) {
  const selectedModel = modelOverride || model;
  const started = Date.now();
  logTrace({
    traceId,
    stage: "openAIRequest",
    message: "OpenAI request started",
    fields: {
      model: selectedModel,
      maxOutputTokens: String(maxOutputTokens),
      inputBytes: String(Buffer.byteLength(input ?? "", "utf8"))
    }
  });

  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      model: selectedModel,
      instructions,
      input,
      store: false,
      max_output_tokens: maxOutputTokens,
      text: {
        format: {
          type: "json_schema",
          name: schema.name,
          strict: true,
          schema: schema.schema
        }
      }
    })
  });

  const payload = await response.json().catch(() => ({}));
  const durationMs = Date.now() - started;
  if (!response.ok) {
    const message = payload?.error?.message || `OpenAI request failed with status ${response.status}.`;
    logTrace({
      traceId,
      stage: "openAIResponse",
      level: "error",
      message: "OpenAI request failed",
      fields: {
        model: selectedModel,
        status: String(response.status),
        durationMs: String(durationMs),
        errorType: payload?.error?.type ?? "unknown",
        errorCode: payload?.error?.code ?? "unknown",
        errorMessage: message
      }
    });
    throw new Error(message);
  }

  const text = payload.output_text || firstOutputText(payload);
  if (!text) {
    logTrace({
      traceId,
      stage: "openAIResponse",
      level: "error",
      message: "OpenAI response missing output text",
      fields: { model: selectedModel, durationMs: String(durationMs) }
    });
    throw new Error("OpenAI response did not contain output text.");
  }

  logTrace({
    traceId,
    stage: "openAIResponse",
    message: "OpenAI request succeeded",
    fields: {
      model: selectedModel,
      status: String(response.status),
      durationMs: String(durationMs),
      outputBytes: String(Buffer.byteLength(text, "utf8")),
      outputPreview: sanitizeSnippet(text)
    }
  });
  return JSON.parse(text);
}

function firstOutputText(payload) {
  for (const item of payload.output || []) {
    for (const part of item.content || []) {
      if (part.type === "output_text" && typeof part.text === "string") {
        return part.text;
      }
    }
  }
  return null;
}

async function classifyCoachIntent(request, traceId) {
  return openAIJSON({
    instructions: coachIntentClassificationInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: coachIntentResultSchema(),
    maxOutputTokens: 900,
    model: classifierModel,
    traceId
  });
}

async function parseCommand(request, traceId) {
  return openAIJSON({
    instructions: commandInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1800,
    traceId
  });
}

async function estimateFood(request, traceId) {
  return openAIJSON({
    instructions: foodEstimateInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: aiFoodEstimateResponseSchema(),
    maxOutputTokens: 1200,
    traceId
  });
}

async function parseWorkout(request, traceId) {
  return openAIJSON({
    instructions: workoutParseInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: aiWorkoutParseResponseSchema(),
    maxOutputTokens: 1800,
    traceId
  });
}

async function parseEditDelete(request, traceId) {
  return openAIJSON({
    instructions: editDeleteInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1400,
    traceId
  });
}

async function parseMultiAction(request, traceId) {
  return openAIJSON({
    instructions: multiActionInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1800,
    traceId
  });
}

async function coachResponse(request, instructions, traceId) {
  return openAIJSON({
    instructions,
    input: JSON.stringify(request),
    schema: aiCoachResponseSchema(),
    maxOutputTokens: 900,
    traceId
  });
}

function sharedRules() {
  return [
    "You are FitPilot's parsing and coaching assistant.",
    "Return JSON only, matching the supplied schema.",
    "You parse, estimate, and explain. You never mutate app state.",
    "The app validates and logs drafts. You only return intents, drafts, and coaching text.",
    "For uncertain food, workouts, edits, deletes, or multi-action commands, set requiresConfirmation true.",
    "Do not diagnose medical conditions or give medical treatment.",
    "Do not encourage starvation or extreme restriction.",
    "Be concise, practical, supportive, and honest."
  ].join("\n");
}

function commandInstructions() {
  return `${sharedRules()}

Task: Parse the user's text into AIParsedCommand.
Allowed intents: logFood, logWater, logWeight, logWorkout, startNewDay, mealAdvice, status, dailyReview, editEntry, deleteEntry, undo, multiAction, casual, unknown.
Use actions for logging/status/review/advice. For edits/deletes, include targetEntrySelector as a human-readable selector and require confirmation.`;
}

function foodEstimateInstructions() {
  return `${sharedRules()}

Task: Estimate nutrition for the described food.
Return one FoodDraft in foodDrafts unless the user clearly described multiple foods.
If the user supplied partial nutrition (only calories, only protein, or some macros missing), estimate the missing values and keep the user-provided numbers.
quantity and unit must describe portion weight or count (e.g. 200g, 1 breast), never macro grams. "50g protein" is a nutrition value, not a 50g portion.
Respect preparation state: raw/uncooked vs cooked weight at the same grams are different foods nutritionally (e.g. 500g raw chicken breast ≠ 500g cooked chicken breast).
Every foodDraft must include calories > 0 and realistic protein, carbs, and fat for the food, portion, and preparation stated.
Use source aiTextEstimate and require confirmation unless the user supplied exact complete nutrition values in their message.`;
}

function mealAdviceInstructions() {
  return `${sharedRules()}

Task: Give brief meal advice using the provided fitness context.
Do not log anything. Mention practical portions or tradeoffs when helpful.`;
}

function coachIntentClassificationInstructions() {
  return `${sharedRules()}

Task: Classify the user's Coach message. You are not answering the user yet.
Return valid JSON only matching CoachIntentResult.
- Choose one intent: log_food, log_water, log_weight, log_workout, edit_log, delete_log, undo,
  daily_summary, calorie_lookup, macro_lookup, meal_decision, nutrition_advice,
  workout_advice, weight_loss_advice, app_help, general_conversation, unrelated_or_unsupported.
- Prefer app-domain intents for food, calories, weight, workouts, hydration, meals, and fitness.
- Set requiresAppMutation true only when the user wants to change FitPilot data.
- Include a typed action when mutation data is clear enough to validate.
- For log_food actions: include food name, quantity, and unit when clear. Do not include calories or macros unless the user's message contains explicit numbers.
  Never copy nutrition from chat history or prior assistant estimates. The estimate-food step handles nutrition.
- For log_food actions: quantity and unit are portion size (e.g. 200g chicken breast). protein/carbs/fat/calories are nutrition values.
  Never put macro grams into quantity. "50g protein" means proteinGrams=50, not quantity=50g.
- Set canAnswerWithCheapModel true for simple nutrition, calorie, macro, meal-decision, or workout questions.
- Set requiresEscalation true only for deeper planning, multi-step coaching, or ambiguous mutations.`;
}

function dailyReviewInstructions() {
  return `${sharedRules()}

Task: Write a concise daily review using only the provided deterministic input.
Use numbers as provided. Highlight one win and one next move.`;
}

function workoutParseInstructions() {
  return `${sharedRules()}

Task: Parse the workout description into a WorkoutDraft plus a short assistantMessage.
Infer duration, calories burned, intensity, recovery demand, and exercise sets when possible.
Always require user confirmation before logging.`;
}

function editDeleteInstructions() {
  return `${sharedRules()}

Task: Parse an edit or delete request into AIParsedCommand.
Use editEntry or deleteEntry intent. Include targetEntrySelector and require confirmation.
Never guess destructive deletes when ambiguous — ask for clarification in assistantMessage.`;
}

function multiActionInstructions() {
  return `${sharedRules()}

Task: Parse a multi-action command into AIParsedCommand with intent multiAction.
Return all proposed actions and require confirmation.`;
}

function nullable(schema) {
  return { anyOf: [schema, { type: "null" }] };
}

function enumSchema(values) {
  return { type: "string", enum: values };
}

const confidence = enumSchema(["high", "medium", "low"]);
const mealType = enumSchema(["breakfast", "lunch", "dinner", "snack", "unknown"]);
const source = enumSchema(["manual", "aiTextEstimate", "aiPhotoEstimate", "nutritionLabel", "savedMeal", "corrected"]);
const intensity = enumSchema(["low", "moderate", "high"]);
const recoveryDemand = enumSchema(["low", "moderate", "high"]);

function foodDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["mealType", "name", "quantity", "unit", "calories", "protein", "carbs", "fat", "fiber", "sodium", "source", "confidence", "imageUrl", "notes"],
    properties: {
      mealType: nullable(mealType),
      name: { type: "string" },
      quantity: nullable({ type: "number" }),
      unit: nullable({ type: "string" }),
      calories: { type: "integer" },
      protein: { type: "number" },
      carbs: { type: "number" },
      fat: { type: "number" },
      fiber: nullable({ type: "number" }),
      sodium: nullable({ type: "number" }),
      source,
      confidence,
      imageUrl: nullable({ type: "string" }),
      notes: nullable({ type: "string" })
    }
  };
}

function waterDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["amountMl"],
    properties: { amountMl: { type: "integer" } }
  };
}

function weightDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["weightKg", "note"],
    properties: {
      weightKg: { type: "number" },
      note: nullable({ type: "string" })
    }
  };
}

function exerciseSetDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["exerciseName", "setNumber", "reps", "weightKg", "rpe"],
    properties: {
      exerciseName: { type: "string" },
      setNumber: { type: "integer" },
      reps: { type: "integer" },
      weightKg: nullable({ type: "number" }),
      rpe: nullable({ type: "number" })
    }
  };
}

function workoutDraftSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["name", "durationMinutes", "estimatedCaloriesBurned", "intensity", "recoveryDemand", "notes", "exerciseSets"],
    properties: {
      name: nullable({ type: "string" }),
      durationMinutes: nullable({ type: "integer" }),
      estimatedCaloriesBurned: nullable({ type: "integer" }),
      intensity: nullable(intensity),
      recoveryDemand: nullable(recoveryDemand),
      notes: nullable({ type: "string" }),
      exerciseSets: {
        type: "array",
        items: exerciseSetDraftSchema()
      }
    }
  };
}

function aiCommandActionSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["type", "foodDraft", "waterDraft", "weightDraft", "workoutDraft", "startNewDayWeightKg", "adviceQuestion", "targetEntrySelector"],
    properties: {
      type: enumSchema(["logFood", "logWater", "logWeight", "logWorkout", "startNewDay", "mealAdvice", "status", "dailyReview", "editEntry", "deleteEntry", "undo"]),
      foodDraft: nullable(foodDraftSchema()),
      waterDraft: nullable(waterDraftSchema()),
      weightDraft: nullable(weightDraftSchema()),
      workoutDraft: nullable(workoutDraftSchema()),
      startNewDayWeightKg: nullable({ type: "number" }),
      adviceQuestion: nullable({ type: "string" }),
      targetEntrySelector: nullable({ type: "string" })
    }
  };
}

function aiParsedCommandSchema() {
  return {
    name: "ai_parsed_command",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["originalText", "intent", "actions", "confidence", "requiresConfirmation", "assistantMessage", "reasoningSummary"],
      properties: {
        originalText: { type: "string" },
        intent: enumSchema(["logFood", "logWater", "logWeight", "logWorkout", "startNewDay", "mealAdvice", "status", "dailyReview", "editEntry", "deleteEntry", "undo", "multiAction", "casual", "unknown"]),
        actions: { type: "array", items: aiCommandActionSchema() },
        confidence,
        requiresConfirmation: { type: "boolean" },
        assistantMessage: nullable({ type: "string" }),
        reasoningSummary: nullable({ type: "string" })
      }
    }
  };
}

function aiFoodEstimateResponseSchema() {
  return {
    name: "ai_food_estimate_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["foodDrafts", "confidence", "requiresConfirmation", "assistantMessage"],
      properties: {
        foodDrafts: { type: "array", items: foodDraftSchema() },
        confidence,
        requiresConfirmation: { type: "boolean" },
        assistantMessage: nullable({ type: "string" })
      }
    }
  };
}

function aiCoachResponseSchema() {
  return {
    name: "ai_coach_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["message", "confidence", "followUpSuggestions"],
      properties: {
        message: { type: "string" },
        confidence,
        followUpSuggestions: { type: "array", items: { type: "string" } }
      }
    }
  };
}

function aiWorkoutParseResponseSchema() {
  return {
    name: "ai_workout_parse_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["workoutDraft", "assistantMessage", "confidence"],
      properties: {
        workoutDraft: workoutDraftSchema(),
        assistantMessage: nullable({ type: "string" }),
        confidence
      }
    }
  };
}

function coachActionSchema() {
  return {
    type: "object",
    additionalProperties: false,
    required: ["type", "foodDraft", "waterDraft", "weightDraft", "workoutDraft", "selector", "undoTarget"],
    properties: {
      type: enumSchema(["log_food", "log_water", "log_weight", "log_workout", "edit_log", "delete_log", "undo", "status", "daily_review"]),
      foodDraft: nullable(foodDraftSchema()),
      waterDraft: nullable(waterDraftSchema()),
      weightDraft: nullable(weightDraftSchema()),
      workoutDraft: nullable(workoutDraftSchema()),
      selector: nullable({ type: "string" }),
      undoTarget: nullable(enumSchema(["food", "water", "workout", "weight", "last"]))
    }
  };
}

function coachIntentResultSchema() {
  return {
    name: "coach_intent_result",
    schema: {
      type: "object",
      additionalProperties: false,
      required: [
        "intent", "confidence", "domain", "requiresAppMutation", "requiresUserContext",
        "canAnswerWithCheapModel", "requiresEscalation", "entities", "action", "reason"
      ],
      properties: {
        intent: enumSchema([
          "log_food", "log_water", "log_weight", "log_workout", "edit_log", "delete_log", "undo",
          "daily_summary", "calorie_lookup", "macro_lookup", "meal_decision", "nutrition_advice",
          "workout_advice", "weight_loss_advice", "app_help", "general_conversation",
          "unrelated_or_unsupported"
        ]),
        confidence: { type: "number" },
        domain: enumSchema(["nutrition", "fitness", "hydration", "body_metrics", "app", "general", "unrelated"]),
        requiresAppMutation: { type: "boolean" },
        requiresUserContext: { type: "boolean" },
        canAnswerWithCheapModel: { type: "boolean" },
        requiresEscalation: { type: "boolean" },
        entities: {
          type: "object",
          additionalProperties: false,
          required: ["food", "meal", "amountMl", "weightKg", "durationMinutes", "distanceKm", "calories", "proteinGrams", "carbsGrams", "fatGrams", "quantity", "unit", "notes"],
          properties: {
            food: nullable({ type: "string" }),
            meal: nullable({ type: "string" }),
            amountMl: nullable({ type: "integer" }),
            weightKg: nullable({ type: "number" }),
            durationMinutes: nullable({ type: "integer" }),
            distanceKm: nullable({ type: "number" }),
            calories: nullable({ type: "integer" }),
            proteinGrams: nullable({ type: "number" }),
            carbsGrams: nullable({ type: "number" }),
            fatGrams: nullable({ type: "number" }),
            quantity: nullable({ type: "number" }),
            unit: nullable({ type: "string" }),
            notes: nullable({ type: "string" })
          }
        },
        action: nullable(coachActionSchema()),
        reason: nullable({ type: "string" })
      }
    }
  };
}
