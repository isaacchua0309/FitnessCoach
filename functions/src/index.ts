/* eslint-disable max-len, require-jsdoc, @typescript-eslint/no-explicit-any */
import {initializeApp} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {logger, setGlobalOptions} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onRequest} from "firebase-functions/v2/https";
import {sanitizeCoachIntentResult} from "./coachIntentSanitizer";
import {
  coachIntentClassificationInstructions,
  commandInstructions,
  dailyReviewInstructions,
  editDeleteInstructions,
  foodEstimateInstructions,
  foodPhotoEstimateInstructions,
  mealAdviceInstructions,
  multiActionInstructions,
  nutritionComparisonInstructions,
  nutritionEstimateInstructions,
  workoutParseInstructions,
} from "./coachPromptInstructions";
import {
  GatewayError,
  assertBodySizeWithinLimit,
  coachContextLogFields,
  enforceRequestQuota,
  validatePayload,
} from "./gatewayGuardrails";
import {
  foodEstimateRepairInstructions,
  mapExtractionToGatewayPayload,
  validateFoodExtraction,
  type FoodExtractionResponse,
} from "./foodEstimateExtraction";
import {
  mealImageAnalysisInstructions,
  mealImageAnalysisResponseSchema,
  MEAL_IMAGE_ANALYSIS_PATH,
  parseMealImageAnalysisResponse,
  validateAnalyzeMealImagePayload,
} from "./mealImageAnalysis";

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
    if (path === MEAL_IMAGE_ANALYSIS_PATH) {
      validateAnalyzeMealImagePayload(body);
    } else {
      validatePayload(path, body);
    }

    logger.info("AI gateway request received", {
      traceId,
      path,
      uid: authUID,
      bodyBytes,
      ...coachContextLogFields(body.context),
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
      modelUsed = resolveModel({
        tier: body.imageJPEGBase64 ? "strong" : "cheap",
      });
      payload = await estimateFood(body, traceId);
      break;
    case MEAL_IMAGE_ANALYSIS_PATH:
      modelUsed = resolveModel({tier: "strong"});
      payload = await analyzeMealImage(body, traceId) as unknown as Record<string, unknown>;
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
    case "/v1/ai/generate-nutrition-estimate":
      modelUsed = resolveModel({
        tier: body.modelTier ?? "cheap",
        modelName: body.modelName,
      });
      payload = {
        estimate: await nutritionEstimateResponse(body, traceId),
      };
      break;
    case "/v1/ai/generate-nutrition-comparison":
      modelUsed = resolveModel({
        tier: body.modelTier ?? "cheap",
        modelName: body.modelName,
      });
      payload = {
        comparison: await nutritionComparisonResponse(body, traceId),
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
  const raw = await openAIJSON({
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
  return sanitizeCoachIntentResult(raw);
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
  const userText = String(request.text ?? "");
  const payload = {
    text: userText,
    context: request.context,
  };
  const isPhoto = Boolean(request.imageJPEGBase64);
  const source = isPhoto ? "aiPhotoEstimate" : "aiTextEstimate";

  const runExtraction = async (repairErrors?: string[]) => {
    const repairBlock = repairErrors?.length ?
      `\n\n${foodEstimateRepairInstructions(repairErrors)}` :
      "";
    const instructions = (isPhoto ?
      foodPhotoEstimateInstructions() :
      foodEstimateInstructions()) + repairBlock;

    if (isPhoto) {
      return openAIJSON({
        instructions,
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
        schema: aiFoodExtractionResponseSchema(),
        maxOutputTokens: 1800,
        model: resolveModel({tier: "strong"}),
        traceId,
      }) as Promise<FoodExtractionResponse>;
    }

    return openAIJSON({
      instructions,
      input: JSON.stringify(payload),
      schema: aiFoodExtractionResponseSchema(),
      maxOutputTokens: 1800,
      model: resolveModel({tier: "cheap"}),
      traceId,
    }) as Promise<FoodExtractionResponse>;
  };

  const clientRepairErrors = Array.isArray(request.repairErrors) ?
    request.repairErrors.map(String) :
    undefined;

  let extraction = await runExtraction(clientRepairErrors);
  let validation = validateFoodExtraction(extraction, userText);

  if (!validation.ok && !clientRepairErrors) {
    logger.warn("Food extraction failed validation; retrying once", {
      traceId,
      errors: validation.errors,
    });
    extraction = await runExtraction(validation.errors);
    validation = validateFoodExtraction(extraction, userText);
    if (!validation.ok) {
      logger.warn("Food extraction still invalid after repair retry", {
        traceId,
        errors: validation.errors,
      });
    }
  }

  if (isPhoto && !validation.ok) {
    throw new GatewayError(
      422,
      "Could not extract reliable nutrition from the meal photo."
    );
  }

  return mapExtractionToGatewayPayload(extraction, source, validation);
}

async function analyzeMealImage(request: Record<string, any>, traceId?: string) {
  const image = request.image as {
    mimeType: string;
    base64: string;
    width?: number;
    height?: number;
  };

  const modelInput = {
    message: request.message ?? null,
    locale: request.locale ?? null,
    userContext: request.userContext ?? null,
    context: request.context ?? null,
    clarification: request.clarification ?? null,
    previousAnalysis: request.previousAnalysis ?? null,
    image: {
      mimeType: image.mimeType,
      ...(image.width !== undefined ? {width: image.width} : {}),
      ...(image.height !== undefined ? {height: image.height} : {}),
    },
  };

  const raw = await openAIJSON({
    instructions: mealImageAnalysisInstructions(),
    input: [
      {
        role: "user",
        content: [
          {type: "input_text", text: JSON.stringify(modelInput)},
          {
            type: "input_image",
            image_url: `data:${image.mimeType};base64,${image.base64}`,
          },
        ],
      },
    ],
    schema: mealImageAnalysisResponseSchema(),
    maxOutputTokens: 1800,
    model: resolveModel({tier: "strong"}),
    traceId,
  });

  return parseMealImageAnalysisResponse(raw);
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

async function nutritionEstimateResponse(
  request: Record<string, any>,
  traceId?: string
) {
  return openAIJSON({
    instructions: nutritionEstimateInstructions(),
    input: JSON.stringify(request),
    schema: nutritionEstimateResponseSchema(),
    maxOutputTokens: 1200,
    model: resolveModel({
      tier: request.modelTier ?? "cheap",
      modelName: request.modelName,
    }),
    traceId,
  });
}

async function nutritionComparisonResponse(
  request: Record<string, any>,
  traceId?: string
) {
  return openAIJSON({
    instructions: nutritionComparisonInstructions(),
    input: JSON.stringify(request),
    schema: nutritionComparisonResponseSchema(),
    maxOutputTokens: 1200,
    model: resolveModel({
      tier: request.modelTier ?? "cheap",
      modelName: request.modelName,
    }),
    traceId,
  });
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

const componentState = enumSchema(["raw", "cooked", "unknown"]);

function foodExtractionComponentSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "name", "quantity", "unit", "state",
      "calories", "protein_g", "carbs_g", "fat_g", "confidence", "source_text",
    ],
    properties: {
      name: {type: "string"},
      quantity: nullable({type: "number"}),
      unit: nullable({type: "string"}),
      state: componentState,
      calories: {type: "number"},
      protein_g: {type: "number"},
      carbs_g: {type: "number"},
      fat_g: {type: "number"},
      confidence,
      source_text: {type: "string"},
    },
  };
}

function foodExtractionTotalsSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["calories", "protein_g", "carbs_g", "fat_g"],
    properties: {
      calories: {type: "number"},
      protein_g: {type: "number"},
      carbs_g: {type: "number"},
      fat_g: {type: "number"},
    },
  };
}

function foodExtractionMealSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "meal_name", "meal_type", "components", "totals",
      "confidence", "assumptions", "warnings",
    ],
    properties: {
      meal_name: {type: "string"},
      meal_type: nullable({type: "string"}),
      components: {type: "array", items: foodExtractionComponentSchema()},
      totals: foodExtractionTotalsSchema(),
      confidence,
      assumptions: {type: "array", items: {type: "string"}},
      warnings: {type: "array", items: {type: "string"}},
    },
  };
}

function aiFoodExtractionResponseSchema(): ResponseSchema {
  return {
    name: "ai_food_extraction_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["meals", "requiresConfirmation", "assistantMessage"],
      properties: {
        meals: {type: "array", items: foodExtractionMealSchema()},
        requiresConfirmation: {type: "boolean"},
        assistantMessage: nullable({type: "string"}),
      },
    },
  };
}

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

function nutritionSuggestedActionSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: ["id", "title", "type", "payload"],
    properties: {
      id: {type: "string"},
      title: {type: "string"},
      type: enumSchema([
        "logMeal", "estimateAnother", "addCommonSide", "addDrink",
        "compareAlternative", "healthierAlternative", "askFollowUp",
      ]),
      payload: {
        type: "object",
        additionalProperties: {type: "string"},
      },
    },
  };
}

function nutritionEstimateResponseSchema(): ResponseSchema {
  return {
    name: "nutrition_estimate_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: [
        "type", "foodName", "displayEmoji", "caloriesKcal", "caloriesRangeLowerKcal",
        "caloriesRangeUpperKcal", "proteinGrams", "carbsGrams", "fatGrams",
        "servingDescription", "confidenceLevel", "confidenceLabel", "confidenceReason",
        "sourceType", "coachSummary", "coachTip", "caveats", "suggestedActions",
      ],
      properties: {
        type: {type: "string", enum: ["nutrition_estimate"]},
        foodName: {type: "string"},
        displayEmoji: nullable({type: "string"}),
        caloriesKcal: nullable({type: "integer"}),
        caloriesRangeLowerKcal: nullable({type: "integer"}),
        caloriesRangeUpperKcal: nullable({type: "integer"}),
        proteinGrams: nullable({type: "number"}),
        carbsGrams: nullable({type: "number"}),
        fatGrams: nullable({type: "number"}),
        servingDescription: nullable({type: "string"}),
        confidenceLevel: confidence,
        confidenceLabel: nullable({type: "string"}),
        confidenceReason: nullable({type: "string"}),
        sourceType: nullable(enumSchema(["branded", "common", "restaurant", "homemade", "unknown"])),
        coachSummary: nullable({type: "string"}),
        coachTip: nullable({type: "string"}),
        caveats: {type: "array", items: {type: "string"}},
        suggestedActions: {type: "array", items: nutritionSuggestedActionSchema()},
      },
    },
  };
}

function nutritionComparisonItemSchema(): JSONSchema {
  return {
    type: "object",
    additionalProperties: false,
    required: [
      "id", "foodName", "displayEmoji", "caloriesKcal", "caloriesRangeLowerKcal",
      "caloriesRangeUpperKcal", "proteinGrams", "carbsGrams", "fatGrams", "servingDescription",
    ],
    properties: {
      id: {type: "string"},
      foodName: {type: "string"},
      displayEmoji: nullable({type: "string"}),
      caloriesKcal: nullable({type: "integer"}),
      caloriesRangeLowerKcal: nullable({type: "integer"}),
      caloriesRangeUpperKcal: nullable({type: "integer"}),
      proteinGrams: nullable({type: "number"}),
      carbsGrams: nullable({type: "number"}),
      fatGrams: nullable({type: "number"}),
      servingDescription: nullable({type: "string"}),
    },
  };
}

function nutritionComparisonResponseSchema(): ResponseSchema {
  return {
    name: "nutrition_comparison_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["type", "leftItem", "rightItem", "coachPick", "suggestedActions"],
      properties: {
        type: {type: "string", enum: ["nutrition_comparison"]},
        leftItem: nutritionComparisonItemSchema(),
        rightItem: nutritionComparisonItemSchema(),
        coachPick: nullable({type: "string"}),
        suggestedActions: {type: "array", items: nutritionSuggestedActionSchema()},
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
          "daily_summary", "calorie_lookup", "macro_lookup", "meal_decision",
          "nutrition_estimate_query", "nutrition_comparison_query", "nutrition_advice",
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
