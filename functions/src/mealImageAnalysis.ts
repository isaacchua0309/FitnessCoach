/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len, valid-jsdoc */

import {GatewayError} from "./gatewayGuardrails";
import {parseCoachContextForPrompt} from "./coachContextPacketV2";
import {
  analyzeMealImagePromptRules,
  coachContextHealthRules,
  coachContextV2Rules,
} from "./coachContextPromptRules";

export const MEAL_IMAGE_ANALYSIS_PATH = "/v1/ai/analyze-meal-image";

export const ALLOWED_MEAL_IMAGE_MIME_TYPES = [
  "image/jpeg",
  "image/png",
] as const;

export type AllowedMealImageMimeType = typeof ALLOWED_MEAL_IMAGE_MIME_TYPES[number];

const DEFAULT_MAX_IMAGE_B64_CHARS = 1_500_000;
const DEFAULT_MAX_DECODED_IMAGE_BYTES = 1_125_000;
const DEFAULT_MAX_MESSAGE_CHARS = 4_000;
const DEFAULT_MAX_LOCALE_CHARS = 32;

const GENERIC_FOOD_NAME_PATTERN = /\b(unknown|generic|unidentified|mysterious|miscellaneous|various|mixed meal|food item|meal item|something|stuff|snack plate)\b/i;

const BASE64_PATTERN = /^[A-Za-z0-9+/]*={0,2}$/;

export interface MealImageAnalysisItem {
  name: string;
  quantity?: string;
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
  confidence: "low" | "medium" | "high";
  assumptions: string[];
}

export interface MealImageAnalysisTotals {
  calories: number;
  protein: number;
  carbs: number;
  fat: number;
}

export interface MealImageAnalysisResponse {
  summary: string;
  items: MealImageAnalysisItem[];
  total: MealImageAnalysisTotals;
  needsUserReview: true;
  clarifyingQuestion?: string;
}

export interface MealImageAnalysisValidationResult {
  ok: boolean;
  errors: string[];
}

interface MealImageAnalysisSchema {
  name: string;
  schema: Record<string, any>;
}

function intEnv(name: string, fallback: number): number {
  const raw = process.env[name];
  if (raw === undefined || raw === "") return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

export function stripDataUrlPrefix(value: string): string {
  const trimmed = value.trim();
  const match = /^data:[^;]+;base64,(.*)$/i.exec(trimmed);
  return (match?.[1] ?? trimmed).trim();
}

export function normalizeMealImageMimeType(value: string): string {
  return value.trim().toLowerCase();
}

export function isAllowedMealImageMimeType(
  mimeType: string
): mimeType is AllowedMealImageMimeType {
  return (ALLOWED_MEAL_IMAGE_MIME_TYPES as readonly string[]).includes(mimeType);
}

export function validateAnalyzeMealImagePayload(body: Record<string, any>): void {
  const maxImageB64 = intEnv("FORMA_AI_MAX_IMAGE_B64_CHARS", DEFAULT_MAX_IMAGE_B64_CHARS);
  const maxDecodedBytes = intEnv(
    "FORMA_AI_MAX_DECODED_IMAGE_BYTES",
    DEFAULT_MAX_DECODED_IMAGE_BYTES
  );
  const maxMessage = intEnv("FORMA_AI_MAX_TEXT_CHARS", DEFAULT_MAX_MESSAGE_CHARS);
  const maxLocale = intEnv("FORMA_AI_MAX_LOCALE_CHARS", DEFAULT_MAX_LOCALE_CHARS);

  if (!body.image || typeof body.image !== "object" || Array.isArray(body.image)) {
    throw new GatewayError(400, "Missing or invalid image.");
  }

  const image = body.image as Record<string, any>;
  if (typeof image.mimeType !== "string" || image.mimeType.trim().length === 0) {
    throw new GatewayError(400, "Missing or invalid image.mimeType.");
  }

  const mimeType = normalizeMealImageMimeType(image.mimeType);
  if (mimeType === "image/heic" || mimeType === "image/heif") {
    throw new GatewayError(
      400,
      "image/heic is not supported. Convert the photo to JPEG or PNG."
    );
  }
  if (!isAllowedMealImageMimeType(mimeType)) {
    throw new GatewayError(
      400,
      `Unsupported image.mimeType "${image.mimeType}". Allowed: image/jpeg, image/png.`
    );
  }

  if (typeof image.base64 !== "string" || image.base64.trim().length === 0) {
    throw new GatewayError(400, "Missing or invalid image.base64.");
  }

  const base64 = stripDataUrlPrefix(image.base64);
  if (base64.length === 0) {
    throw new GatewayError(400, "Missing or invalid image.base64.");
  }
  if (base64.length > maxImageB64) {
    throw new GatewayError(413, "image.base64 exceeds maximum length.");
  }
  if (!BASE64_PATTERN.test(base64) || base64.length % 4 !== 0) {
    throw new GatewayError(400, "image.base64 is not valid base64.");
  }

  let decoded: Buffer;
  try {
    decoded = Buffer.from(base64, "base64");
  } catch {
    throw new GatewayError(400, "image.base64 is not valid base64.");
  }

  if (decoded.length === 0) {
    throw new GatewayError(400, "image.base64 decoded to an empty payload.");
  }
  if (decoded.length > maxDecodedBytes) {
    throw new GatewayError(413, "Decoded image exceeds maximum size.");
  }

  if (!decodedBytesMatchMimeType(decoded, mimeType)) {
    throw new GatewayError(400, "image.base64 does not match image.mimeType.");
  }

  if (image.width !== undefined) {
    if (typeof image.width !== "number" || !Number.isFinite(image.width) || image.width <= 0) {
      throw new GatewayError(400, "Invalid image.width.");
    }
  }
  if (image.height !== undefined) {
    if (typeof image.height !== "number" || !Number.isFinite(image.height) || image.height <= 0) {
      throw new GatewayError(400, "Invalid image.height.");
    }
  }

  body.context = parseCoachContextForPrompt(body.context, {required: true});

  if (body.message !== undefined) {
    if (typeof body.message !== "string") {
      throw new GatewayError(400, "Invalid message.");
    }
    const message = body.message.trim();
    if (message.length === 0) {
      throw new GatewayError(400, "Invalid message.");
    }
    if (message.length > maxMessage) {
      throw new GatewayError(400, "message exceeds maximum length.");
    }
    body.message = message;
  }

  if (body.locale !== undefined) {
    if (typeof body.locale !== "string" || body.locale.trim().length === 0) {
      throw new GatewayError(400, "Invalid locale.");
    }
    if (body.locale.trim().length > maxLocale) {
      throw new GatewayError(400, "locale exceeds maximum length.");
    }
    body.locale = body.locale.trim();
  }

  if (body.userContext !== undefined) {
    if (!body.userContext || typeof body.userContext !== "object" || Array.isArray(body.userContext)) {
      throw new GatewayError(400, "Invalid userContext.");
    }
  }

  if (body.clarification !== undefined) {
    if (typeof body.clarification !== "string") {
      throw new GatewayError(400, "Invalid clarification.");
    }
    const clarification = body.clarification.trim();
    if (clarification.length === 0) {
      throw new GatewayError(400, "Invalid clarification.");
    }
    if (clarification.length > maxMessage) {
      throw new GatewayError(400, "clarification exceeds maximum length.");
    }
    body.clarification = clarification;
  }

  if (body.previousAnalysis !== undefined) {
    validatePreviousAnalysis(body.previousAnalysis, maxMessage);
  }

  body.image = {
    mimeType,
    base64,
    ...(image.width !== undefined ? {width: image.width} : {}),
    ...(image.height !== undefined ? {height: image.height} : {}),
  };
}

function decodedBytesMatchMimeType(decoded: Buffer, mimeType: AllowedMealImageMimeType): boolean {
  if (mimeType === "image/jpeg") {
    return decoded.length >= 2 && decoded[0] === 0xFF && decoded[1] === 0xD8;
  }
  if (mimeType === "image/png") {
    const pngSignature = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    return decoded.length >= pngSignature.length && decoded.subarray(0, 8).equals(pngSignature);
  }
  return false;
}

export function mealImageAnalysisResponseSchema(): MealImageAnalysisSchema {
  const confidence = {type: "string", enum: ["low", "medium", "high"]};
  return {
    name: "meal_image_analysis_response",
    schema: {
      type: "object",
      additionalProperties: false,
      required: ["summary", "items", "total", "needsUserReview", "clarifyingQuestion"],
      properties: {
        summary: {type: "string"},
        items: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: [
              "name", "quantity", "calories", "protein", "carbs", "fat",
              "confidence", "assumptions",
            ],
            properties: {
              name: {type: "string"},
              quantity: {anyOf: [{type: "string"}, {type: "null"}]},
              calories: {type: "number"},
              protein: {type: "number"},
              carbs: {type: "number"},
              fat: {type: "number"},
              confidence,
              assumptions: {type: "array", items: {type: "string"}},
            },
          },
        },
        total: {
          type: "object",
          additionalProperties: false,
          required: ["calories", "protein", "carbs", "fat"],
          properties: {
            calories: {type: "number"},
            protein: {type: "number"},
            carbs: {type: "number"},
            fat: {type: "number"},
          },
        },
        needsUserReview: {type: "boolean"},
        clarifyingQuestion: {anyOf: [{type: "string"}, {type: "null"}]},
      },
    },
  };
}

export function mealImageAnalysisInstructions(): string {
  return [
    "You are FitPilot's meal photo analysis assistant.",
    "Return JSON only, matching the supplied schema.",
    "The attached image is the primary source of truth — identify only foods you can see.",
    analyzeMealImagePromptRules(),
    coachContextV2Rules(),
    coachContextHealthRules(),
    "Each distinct visible food must be its own item with realistic calories, macros, confidence, and assumptions.",
    "Never invent a generic catch-all item such as 'unknown meal', 'mixed food', or 'generic plate'.",
    "If the photo is unclear, set clarifyingQuestion and keep items to only what you can identify with evidence.",
    "When previousAnalysis and clarification are provided, refine that estimate using the same image.",
    "Treat clarification as authoritative for ambiguous ingredients, sauces, grains, or portion sizes.",
    "Sum item nutrition into total exactly.",
    "Prefer realistic or slightly conservative estimates.",
    "Always set needsUserReview to true.",
  ].join("\n");
}

function validatePreviousAnalysis(value: unknown, maxMessage: number): void {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new GatewayError(400, "Invalid previousAnalysis.");
  }
  const previous = value as Record<string, any>;
  if (typeof previous.summary !== "string" || previous.summary.trim().length === 0) {
    throw new GatewayError(400, "Invalid previousAnalysis.summary.");
  }
  if (!Array.isArray(previous.items) || previous.items.length === 0) {
    throw new GatewayError(400, "Invalid previousAnalysis.items.");
  }
  if (!previous.total || typeof previous.total !== "object") {
    throw new GatewayError(400, "Invalid previousAnalysis.total.");
  }
  if (previous.summary.length > maxMessage) {
    throw new GatewayError(400, "previousAnalysis.summary exceeds maximum length.");
  }
}

export function validateMealImageAnalysisResponse(
  raw: Record<string, any>
): MealImageAnalysisValidationResult {
  const errors: string[] = [];

  const summary = typeof raw.summary === "string" ? raw.summary.trim() : "";
  if (!summary) {
    errors.push("summary is required.");
  }

  if (!Array.isArray(raw.items) || raw.items.length === 0) {
    errors.push("items must contain at least one identified food.");
    return {ok: false, errors};
  }

  const items: MealImageAnalysisItem[] = [];
  for (const [index, item] of raw.items.entries()) {
    const name = typeof item?.name === "string" ? item.name.trim() : "";
    if (!name) {
      errors.push(`items[${index}].name is required.`);
      continue;
    }
    if (GENERIC_FOOD_NAME_PATTERN.test(name)) {
      errors.push(`items[${index}].name is too generic: "${name}".`);
    }

    const calories = numberField(item?.calories, `items[${index}].calories`, errors);
    const protein = numberField(item?.protein, `items[${index}].protein`, errors);
    const carbs = numberField(item?.carbs, `items[${index}].carbs`, errors);
    const fat = numberField(item?.fat, `items[${index}].fat`, errors);
    if (calories === null || protein === null || carbs === null || fat === null) {
      continue;
    }

    if (!["low", "medium", "high"].includes(item?.confidence)) {
      errors.push(`items[${index}].confidence is invalid.`);
    }

    const assumptions = Array.isArray(item?.assumptions) ?
      item.assumptions.map(String) :
      [];

    items.push({
      name,
      ...(typeof item?.quantity === "string" && item.quantity.trim().length > 0 ?
        {quantity: item.quantity.trim()} :
        {}),
      calories,
      protein,
      carbs,
      fat,
      confidence: item.confidence,
      assumptions,
    });
  }

  if (items.length === 0) {
    errors.push("No valid food items were identified.");
    return {ok: false, errors};
  }

  const total = {
    calories: numberField(raw.total?.calories, "total.calories", errors),
    protein: numberField(raw.total?.protein, "total.protein", errors),
    carbs: numberField(raw.total?.carbs, "total.carbs", errors),
    fat: numberField(raw.total?.fat, "total.fat", errors),
  };

  if (
    total.calories === null ||
    total.protein === null ||
    total.carbs === null ||
    total.fat === null
  ) {
    return {ok: false, errors};
  }

  const summed = sumItems(items);
  if (!withinTolerance(total.calories, summed.calories, 3)) {
    errors.push("total.calories does not match item sums.");
  }
  if (!withinTolerance(total.protein, summed.protein, 1)) {
    errors.push("total.protein does not match item sums.");
  }
  if (!withinTolerance(total.carbs, summed.carbs, 1)) {
    errors.push("total.carbs does not match item sums.");
  }
  if (!withinTolerance(total.fat, summed.fat, 1)) {
    errors.push("total.fat does not match item sums.");
  }

  return {ok: errors.length === 0, errors};
}

export function parseMealImageAnalysisResponse(
  raw: Record<string, any>
): MealImageAnalysisResponse {
  const validation = validateMealImageAnalysisResponse(raw);
  if (!validation.ok) {
    throw new GatewayError(
      422,
      validation.errors[0] ?? "Could not extract reliable nutrition from the meal photo."
    );
  }

  const items = (raw.items as any[]).map((item) => ({
    name: String(item.name).trim(),
    ...(typeof item.quantity === "string" && item.quantity.trim().length > 0 ?
      {quantity: item.quantity.trim()} :
      {}),
    calories: Math.round(item.calories),
    protein: roundMacro(item.protein),
    carbs: roundMacro(item.carbs),
    fat: roundMacro(item.fat),
    confidence: item.confidence,
    assumptions: Array.isArray(item.assumptions) ? item.assumptions.map(String) : [],
  }));

  const total = {
    calories: Math.round(raw.total.calories),
    protein: roundMacro(raw.total.protein),
    carbs: roundMacro(raw.total.carbs),
    fat: roundMacro(raw.total.fat),
  };

  const clarifyingQuestion = typeof raw.clarifyingQuestion === "string" &&
    raw.clarifyingQuestion.trim().length > 0 ?
    raw.clarifyingQuestion.trim() :
    undefined;

  return {
    summary: String(raw.summary).trim(),
    items,
    total,
    needsUserReview: true,
    ...(clarifyingQuestion ? {clarifyingQuestion} : {}),
  };
}

function numberField(
  value: unknown,
  label: string,
  errors: string[]
): number | null {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    errors.push(`${label} must be a non-negative number.`);
    return null;
  }
  return value;
}

function sumItems(items: MealImageAnalysisItem[]): MealImageAnalysisTotals {
  return items.reduce(
    (acc, item) => ({
      calories: acc.calories + item.calories,
      protein: acc.protein + item.protein,
      carbs: acc.carbs + item.carbs,
      fat: acc.fat + item.fat,
    }),
    {calories: 0, protein: 0, carbs: 0, fat: 0}
  );
}

function withinTolerance(actual: number, expected: number, absolute: number): boolean {
  return Math.abs(actual - expected) <= absolute;
}

function roundMacro(value: number): number {
  return Math.round(value * 10) / 10;
}
