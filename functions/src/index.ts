/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {logger, setGlobalOptions} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import {
  GatewayError,
  assertBodySizeWithinLimit,
  enforceRequestQuota,
  validatePayload,
} from "./gatewayGuardrails";

initializeApp();
setGlobalOptions({maxInstances: 10});

const openAIAPIKey = defineSecret("OPENAI_API_KEY");

type JSONSchema = Record<string, any>;

interface ResponseSchema {
  name: string;
  schema: JSONSchema;
}

interface OpenAIJSONRequest {
  instructions: string;
  input: unknown;
  schema: ResponseSchema;
  maxOutputTokens?: number;
  model?: string;
  traceId?: string;
}

const DEFAULT_MODELS = {
  cheap: "gpt-5-nano",
  default: "gpt-5-nano",
  strong: "gpt-5.4-nano",
  fallback: "gpt-5.4-mini",
};

export async function handleAiGatewayRequest(
  request: any,
  response: any
): Promise<void> {
  const requestStarted = Date.now();
  const traceId = readTraceId(request);

  try {
    if (request.method === "OPTIONS") {
      response.status(204).send("");
      return;
    }

    if (request.method !== "POST") {
      response.status(405).json({error: "Method not allowed."});
      return;
    }

    const authUID = await verifyFirebaseAuth(request);
    enforceRequestQuota(authUID);
    const body = readRequestBody(request);
    const bodyBytes = assertBodySizeWithinLimit(request, body);
    const path = normalizedPath(request.path || request.url || "");
    validatePayload(path, body);

    logger.info("AI gateway request received", {
      traceId,
      path,
      uid: authUID,
      bodyBytes,
    });

    let payload: Record<string, unknown>;
    let modelUsed: string | undefined;
    switch (path) {
    case "/v1/ai/classify-coach-intent":
      modelUsed = resolveModel({
        tier: "cheap",
        modelName: body.modelName,
      });
      payload = {intentResult: await classifyCoachIntent(body, traceId)};
      break;
    case "/v1/ai/parse-command":
      modelUsed = resolveModel({tier: "cheap"});
      payload = {parsedCommand: await parseCommand(body, traceId)};
      break;
    case "/v1/ai/estimate-food":
      modelUsed = resolveModel({tier: "cheap"});
      payload = await estimateFood(body, traceId);
      break;
    case "/v1/ai/generate-meal-advice":
      modelUsed = resolveModel({
        tier: body.modelTier ?? "strong",
        modelName: body.modelName,
      });
      payload = {
        response: await coachResponse(
          body,
          mealAdviceInstructions(),
          traceId
        ),
      };
      break;
    case "/v1/ai/generate-daily-review":
      modelUsed = resolveModel({
        tier: "cheap",
        modelName: body.modelName,
      });
      payload = {
        response: await coachResponse(
          body,
          dailyReviewInstructions(),
          traceId,
          "cheap"
        ),
      };
      break;
    case "/v1/ai/parse-workout":
      modelUsed = resolveModel({tier: "cheap"});
      payload = await parseWorkout(body, traceId);
      break;
    case "/v1/ai/parse-edit-delete":
      modelUsed = resolveModel({tier: "cheap"});
      payload = {parsedCommand: await parseEditDelete(body, traceId)};
      break;
    case "/v1/ai/parse-multi-action":
      modelUsed = resolveModel({tier: "cheap"});
      payload = {parsedCommand: await parseMultiAction(body, traceId)};
      break;
    default:
      response.status(404).json({error: "Endpoint not found."});
      return;
    }

    logger.info("AI gateway request completed", {
      traceId,
      path,
      uid: authUID,
      bodyBytes,
      model: modelUsed,
      durationMs: Date.now() - requestStarted,
    });
    response.setHeader("Cache-Control", "no-store");
    response.status(200).json(payload);
  } catch (error) {
    const message = error instanceof Error ?
      error.message :
      "AI gateway failed.";
    const status = error instanceof GatewayError ? error.status : 500;
    logger.error("AI gateway request failed", {
      traceId,
      status,
      message,
      durationMs: Date.now() - requestStarted,
    });
    response.status(status).json({error: message});
  }
}

export const aiGateway = onRequest(
  {
    secrets: [openAIAPIKey],
    timeoutSeconds: 90,
    memory: "512MiB",
    cors: false,
  },
  handleAiGatewayRequest
);

function readTraceId(request: any): string | undefined {
  const candidates = [
    "X-Forma-Trace-Id",
    "X-FitPilot-Trace-Id",
  ];

  for (const headerName of candidates) {
    const value = request.header?.(headerName);
    if (typeof value === "string" && value.length > 0) {
      return value;
    }
  }

  return undefined;
}

function readRequestBody(request: any): Record<string, any> {
  if (request.body && typeof request.body === "object") {
    return request.body as Record<string, any>;
  }

  if (typeof request.rawBody?.toString === "function") {
    const raw = request.rawBody.toString("utf8");
    return JSON.parse(raw || "{}");
  }

  return {};
}

function normalizedPath(path: string): string {
  const withoutQuery = path.split("?")[0] || "/";
  return withoutQuery.startsWith("/") ? withoutQuery : `/${withoutQuery}`;
}

async function verifyFirebaseAuth(request: any): Promise<string | null> {
  if (process.env.FORMA_AI_REQUIRE_AUTH === "0") {
    return null;
  }

  const header = request.header?.("Authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) {
    throw new GatewayError(401, "Missing Firebase ID token.");
  }

  try {
    const decoded = await getAuth().verifyIdToken(match[1]);
    return decoded.uid;
  } catch {
    throw new GatewayError(401, "Invalid Firebase ID token.");
  }
}

function models() {
  return {
    cheap: process.env.OPENAI_CLASSIFIER_MODEL || process.env.OPENAI_MODEL || DEFAULT_MODELS.cheap,
    default: process.env.OPENAI_MODEL || DEFAULT_MODELS.default,
    strong: process.env.OPENAI_STRONG_MODEL || DEFAULT_MODELS.strong,
    fallback: process.env.OPENAI_FALLBACK_MODEL || DEFAULT_MODELS.fallback,
  };
}

function resolveModel({tier, modelName}: {tier?: string; modelName?: string} = {}): string {
  const configured = models();
  if (tier === "cheap") return configured.cheap;
  if (tier === "strong") return configured.strong;

  const allowedModels = new Set(Object.values(configured));
  if (typeof modelName === "string" && allowedModels.has(modelName)) {
    return modelName;
  }

  return configured.default;
}

function reasoningConfigForModel(model: string): {effort: string} | undefined {
  if (!/^gpt-5/i.test(model)) {
    return undefined;
  }

  const effort = process.env.OPENAI_REASONING_EFFORT?.trim() || "minimal";
  return {effort};
}

async function openAIJSON({
  instructions,
  input,
  schema,
  maxOutputTokens = 1200,
  model,
  traceId,
}: OpenAIJSONRequest): Promise<Record<string, any>> {
  const apiKey = openAIAPIKey.value();
  if (!apiKey) {
    throw new GatewayError(500, "OPENAI_API_KEY is not configured.");
  }

  const selectedModel = model || models().default;
  const started = Date.now();
  logger.info("OpenAI request started", {
    traceId,
    model: selectedModel,
    schema: schema.name,
  });

  const openAIRequestBody: Record<string, unknown> = {
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
        schema: schema.schema,
      },
    },
  };

  const reasoning = reasoningConfigForModel(selectedModel);
  if (reasoning) {
    openAIRequestBody.reasoning = reasoning;
  }

  const openAIResponse = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(openAIRequestBody),
  });

  const payload = await openAIResponse.json().catch(() => ({}));
  if (!openAIResponse.ok) {
    const message = payload?.error?.message ||
      `OpenAI request failed with status ${openAIResponse.status}.`;
    logger.error("OpenAI request failed", {
      traceId,
      model: selectedModel,
      status: openAIResponse.status,
      durationMs: Date.now() - started,
      errorType: payload?.error?.type ?? "unknown",
      errorCode: payload?.error?.code ?? "unknown",
    });
    throw new Error(message);
  }

  const text = payload.output_text || firstOutputText(payload);
  if (!text) {
    logger.error("OpenAI response missing output text", {
      traceId,
      model: selectedModel,
      responseStatus: payload?.status ?? "unknown",
      incompleteReason: payload?.incomplete_details?.reason ?? null,
      outputTypes: (payload.output || []).map((item: {type?: string}) => item.type ?? "unknown"),
      durationMs: Date.now() - started,
    });
    throw new Error("OpenAI response did not contain output text.");
  }

  logger.info("OpenAI request completed", {
    traceId,
    model: selectedModel,
    durationMs: Date.now() - started,
    inputTokens: payload?.usage?.input_tokens ?? payload?.usage?.prompt_tokens ?? null,
    outputTokens: payload?.usage?.output_tokens ?? payload?.usage?.completion_tokens ?? null,
    totalTokens: payload?.usage?.total_tokens ?? null,
  });
  return JSON.parse(text);
}

function firstOutputText(payload: any): string | null {
  for (const item of payload.output || []) {
    for (const part of item.content || []) {
      if (part.type === "output_text" && typeof part.text === "string") {
        return part.text;
      }
    }
  }
  return null;
}

async function classifyCoachIntent(request: Record<string, any>, traceId?: string) {
  return openAIJSON({
    instructions: coachIntentClassificationInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context,
    }),
    schema: coachIntentResultSchema(),
    maxOutputTokens: 900,
    model: resolveModel({tier: "cheap", modelName: request.modelName}),
    traceId,
  });
}

async function parseCommand(request: Record<string, any>, traceId?: string) {
  return openAIJSON({
    instructions: commandInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context,
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1800,
    model: resolveModel({tier: "cheap"}),
    traceId,
  });
}

async function estimateFood(request: Record<string, any>, traceId?: string) {
  const payload = {
    text: request.text,
    context: request.context,
  };

  if (request.imageJPEGBase64) {
    return openAIJSON({
      instructions: foodPhotoEstimateInstructions(),
      input: [
        {
          role: "user",
          content: [
            {type: "input_text", text: JSON.stringify(payload)},
            {
              type: "input_image",
              image_url: `data:image/jpeg;base64,${request.imageJPEGBase64}`,
            },
          ],
        },
      ],
      schema: aiFoodEstimateResponseSchema(),
      maxOutputTokens: 1200,
      model: resolveModel({tier: "cheap"}),
      traceId,
    });
  }

  return openAIJSON({
    instructions: foodEstimateInstructions(),
    input: JSON.stringify(payload),
    schema: aiFoodEstimateResponseSchema(),
    maxOutputTokens: 1200,
    model: resolveModel({tier: "cheap"}),
    traceId,
  });
}

async function parseWorkout(request: Record<string, any>, traceId?: string) {
  return openAIJSON({
    instructions: workoutParseInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context,
    }),
    schema: aiWorkoutParseResponseSchema(),
    maxOutputTokens: 1800,
    model: resolveModel({tier: "cheap"}),
    traceId,
  });
}

async function parseEditDelete(request: Record<string, any>, traceId?: string) {
  return openAIJSON({
    instructions: editDeleteInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context,
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1400,
    model: resolveModel({tier: "cheap"}),
    traceId,
  });
}

async function parseMultiAction(request: Record<string, any>, traceId?: string) {
  return openAIJSON({
    instructions: multiActionInstructions(),
    input: JSON.stringify({
      text: request.text,
      context: request.context,
    }),
    schema: aiParsedCommandSchema(),
    maxOutputTokens: 1800,
    model: resolveModel({tier: "cheap"}),
    traceId,
  });
}

async function coachResponse(
  request: Record<string, any>,
  instructions: string,
  traceId?: string,
  fallbackTier?: string
) {
  return openAIJSON({
    instructions,
    input: JSON.stringify(request),
    schema: aiCoachResponseSchema(),
    maxOutputTokens: 900,
    model: resolveModel({
      tier: request.modelTier ?? fallbackTier,
      modelName: request.modelName,
    }),
    traceId,
  });
}

function sharedRules(): string {
  return [
    "You are FitPilot's parsing and coaching assistant.",
    "Return JSON only, matching the supplied schema.",
    "You parse, estimate, and explain. You never mutate app state.",
    "The app validates and logs drafts. You only return intents, drafts, and coaching text.",
    "For uncertain food, workouts, edits, deletes, or multi-action commands, set requiresConfirmation true.",
    "Do not diagnose medical conditions or give medical treatment.",
    "Do not encourage starvation or extreme restriction.",
    "Be concise, practical, supportive, and honest.",
  ].join("\n");
}

function commandInstructions(): string {
  return `${sharedRules()}

Task: Parse the user's text into AIParsedCommand.
Allowed intents: logFood, logWater, logWeight, logWorkout, startNewDay, mealAdvice, status, dailyReview, editEntry, deleteEntry, undo, multiAction, casual, unknown.
Use actions for logging/status/review/advice. For edits/deletes, include targetEntrySelector as a human-readable selector and require confirmation.`;
}

function foodEstimateInstructions(): string {
  return `${sharedRules()}

Task: Estimate nutrition for the described food.
Return one FoodDraft in foodDrafts unless the user clearly described multiple foods.
If the user supplied partial nutrition (only calories, only protein, or some macros missing), estimate the missing values and keep the user-provided numbers.
quantity and unit must describe portion weight or count (e.g. 200g, 1 breast), never macro grams. "50g protein" is a nutrition value, not a 50g portion.
Respect preparation state: raw/uncooked vs cooked weight at the same grams are different foods nutritionally (e.g. 500g raw chicken breast ≠ 500g cooked chicken breast).
Every foodDraft must include calories > 0 and realistic protein, carbs, and fat for the food, portion, and preparation stated.
Use source aiTextEstimate and require confirmation unless the user supplied exact complete nutrition values in their message.`;
}

function foodPhotoEstimateInstructions(): string {
  return `${sharedRules()}

Task: Analyze the attached meal photo and estimate nutrition.
Identify visible foods, reasonable portion size, and preparation when inferable from the image.
Return one FoodDraft in foodDrafts unless the photo clearly shows multiple distinct items that should be logged separately.
Every foodDraft must include calories > 0 and realistic protein, carbs, and fat for what is visible.
Use source aiPhotoEstimate and always require confirmation before logging.`;
}

function mealAdviceInstructions(): string {
  return `${sharedRules()}

Task: Give brief meal advice using the provided fitness context.
Do not log anything. Mention practical portions or tradeoffs when helpful.`;
}

function coachIntentClassificationInstructions(): string {
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

function dailyReviewInstructions(): string {
  return `${sharedRules()}

Task: Write a concise daily review using only the provided deterministic input.
Use numbers as provided. Highlight one win and one next move.`;
}

function workoutParseInstructions(): string {
  return `${sharedRules()}

Task: Parse the workout description into a WorkoutDraft plus a short assistantMessage.
Infer duration, calories burned, intensity, recovery demand, and exercise sets when possible.
Always require user confirmation before logging.`;
}

function editDeleteInstructions(): string {
  return `${sharedRules()}

Task: Parse an edit or delete request into AIParsedCommand.
Use editEntry or deleteEntry intent. Include targetEntrySelector and require confirmation.
Never guess destructive deletes when ambiguous — ask for clarification in assistantMessage.`;
}

function multiActionInstructions(): string {
  return `${sharedRules()}

Task: Parse a multi-action command into AIParsedCommand with intent multiAction.
Return all proposed actions and require confirmation.`;
}

function nullable(schema: JSONSchema): JSONSchema {
  return {anyOf: [schema, {type: "null"}]};
}

function enumSchema(values: string[]): JSONSchema {
  return {type: "string", enum: values};
}

const confidence = enumSchema(["high", "medium", "low"]);
const mealType = enumSchema(["breakfast", "lunch", "dinner", "snack", "unknown"]);
const source = enumSchema(["manual", "aiTextEstimate", "aiPhotoEstimate", "nutritionLabel", "savedMeal", "corrected"]);
const intensity = enumSchema(["low", "moderate", "high"]);
const recoveryDemand = enumSchema(["low", "moderate", "high"]);

function foodDraftSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["mealType", "name", "quantity", "unit", "calories", "protein", "carbs", "fat", "fiber", "sodium", "source", "confidence", "imageUrl", "notes"],
    properties: {
      mealType: nullable(mealType),
      name: {type: "string"},
      quantity: nullable({type: "number"}),
      unit: nullable({type: "string"}),
      calories: {type: "integer"},
      protein: {type: "number"},
      carbs: {type: "number"},
      fat: {type: "number"},
      fiber: nullable({type: "number"}),
      sodium: nullable({type: "number"}),
      source,
      confidence,
      imageUrl: nullable({type: "string"}),
      notes: nullable({type: "string"}),
    },
  };
}

function waterDraftSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["amountMl"],
    properties: {amountMl: {type: "integer"}},
  };
}

function weightDraftSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["weightKg", "note"],
    properties: {
      weightKg: {type: "number"},
      note: nullable({type: "string"}),
    },
  };
}

function exerciseSetDraftSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["exerciseName", "setNumber", "reps", "weightKg", "rpe"],
    properties: {
      exerciseName: {type: "string"},
      setNumber: {type: "integer"},
      reps: {type: "integer"},
      weightKg: nullable({type: "number"}),
      rpe: nullable({type: "number"}),
    },
  };
}

function workoutDraftSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["name", "durationMinutes", "estimatedCaloriesBurned", "intensity", "recoveryDemand", "notes", "exerciseSets"],
    properties: {
      name: nullable({type: "string"}),
      durationMinutes: nullable({type: "integer"}),
      estimatedCaloriesBurned: nullable({type: "integer"}),
      intensity: nullable(intensity),
      recoveryDemand: nullable(recoveryDemand),
      notes: nullable({type: "string"}),
      exerciseSets: {type: "array", items: exerciseSetDraftSchema()},
    },
  };
}

function aiCommandActionSchema(): JSONSchema {
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
      startNewDayWeightKg: nullable({type: "number"}),
      adviceQuestion: nullable({type: "string"}),
      targetEntrySelector: nullable({type: "string"}),
    },
  };
}

function aiParsedCommandSchema(): ResponseSchema {
  return {
    name: "ai_parsed_command",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["originalText", "intent", "actions", "confidence", "requiresConfirmation", "assistantMessage", "reasoningSummary"],
      properties: {
        originalText: {type: "string"},
        intent: enumSchema(["logFood", "logWater", "logWeight", "logWorkout", "startNewDay", "mealAdvice", "status", "dailyReview", "editEntry", "deleteEntry", "undo", "multiAction", "casual", "unknown"]),
        actions: {type: "array", items: aiCommandActionSchema()},
        confidence,
        requiresConfirmation: {type: "boolean"},
        assistantMessage: nullable({type: "string"}),
        reasoningSummary: nullable({type: "string"}),
      },
    },
  };
}

function aiFoodEstimateResponseSchema(): ResponseSchema {
  return {
    name: "ai_food_estimate_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["foodDrafts", "confidence", "requiresConfirmation", "assistantMessage"],
      properties: {
        foodDrafts: {type: "array", items: foodDraftSchema()},
        confidence,
        requiresConfirmation: {type: "boolean"},
        assistantMessage: nullable({type: "string"}),
      },
    },
  };
}

function aiCoachResponseSchema(): ResponseSchema {
  return {
    name: "ai_coach_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["message", "confidence", "followUpSuggestions"],
      properties: {
        message: {type: "string"},
        confidence,
        followUpSuggestions: {type: "array", items: {type: "string"}},
      },
    },
  };
}

function aiWorkoutParseResponseSchema(): ResponseSchema {
  return {
    name: "ai_workout_parse_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["workoutDraft", "assistantMessage", "confidence"],
      properties: {
        workoutDraft: workoutDraftSchema(),
        assistantMessage: nullable({type: "string"}),
        confidence,
      },
    },
  };
}

function coachActionSchema(): JSONSchema {
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
      selector: nullable({type: "string"}),
      undoTarget: nullable(enumSchema(["food", "water", "workout", "weight", "last"])),
    },
  };
}

function coachIntentResultSchema(): ResponseSchema {
  return {
    name: "coach_intent_result",
    schema: {
      type: "object",
      additionalProperties: false,
      required: [
        "intent", "confidence", "domain", "requiresAppMutation", "requiresUserContext",
        "canAnswerWithCheapModel", "requiresEscalation", "entities", "action", "reason",
      ],
      properties: {
        intent: enumSchema([
          "log_food", "log_water", "log_weight", "log_workout", "edit_log", "delete_log", "undo",
          "daily_summary", "calorie_lookup", "macro_lookup", "meal_decision", "nutrition_advice",
          "workout_advice", "weight_loss_advice", "app_help", "general_conversation",
          "unrelated_or_unsupported",
        ]),
        confidence: {type: "number"},
        domain: enumSchema(["nutrition", "fitness", "hydration", "body_metrics", "app", "general", "unrelated"]),
        requiresAppMutation: {type: "boolean"},
        requiresUserContext: {type: "boolean"},
        canAnswerWithCheapModel: {type: "boolean"},
        requiresEscalation: {type: "boolean"},
        entities: {
          type: "object",
          additionalProperties: false,
          required: ["food", "meal", "amountMl", "weightKg", "durationMinutes", "distanceKm", "calories", "proteinGrams", "carbsGrams", "fatGrams", "quantity", "unit", "notes"],
          properties: {
            food: nullable({type: "string"}),
            meal: nullable({type: "string"}),
            amountMl: nullable({type: "integer"}),
            weightKg: nullable({type: "number"}),
            durationMinutes: nullable({type: "integer"}),
            distanceKm: nullable({type: "number"}),
            calories: nullable({type: "integer"}),
            proteinGrams: nullable({type: "number"}),
            carbsGrams: nullable({type: "number"}),
            fatGrams: nullable({type: "number"}),
            quantity: nullable({type: "number"}),
            unit: nullable({type: "string"}),
            notes: nullable({type: "string"}),
          },
        },
        action: nullable(coachActionSchema()),
        reason: nullable({type: "string"}),
      },
    },
  };
}
