/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len, valid-jsdoc */

import {GatewayError} from "./gatewayGuardrails";

export const COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION = 2;

export const COACH_CONTEXT_LIMITS = {
  maxTimelineEvents: 20,
  maxChatMessages: 12,
  maxRecentMeals: 10,
  maxCommonFoods: 10,
  maxAssumptions: 8,
  maxSummaryLength: 180,
  maxCompactPayloadEntries: 6,
  maxChatPreviewLength: 180,
  maxCurrentUserMessageLength: 500,
  maxStringFieldLength: 240,
  maxAssumptionDetailLength: 240,
  maxEncodedBytes: 24_576,
  minSuspiciousBase64Length: 256,
} as const;

const PROTECTED_TIMELINE_EVENT_TYPES = new Set([
  "foodLogged",
  "waterLogged",
  "weightLogged",
  "foodEdited",
  "foodDeleted",
  "workoutDetected",
  "stepsUpdated",
  "pendingConfirmationCreated",
  "photoAttached",
  "photoAnalysisStarted",
  "photoAnalysisCompleted",
  "photoAnalysisFailed",
  "clarificationAsked",
  "clarificationAnswered",
  "dailyFoodSummary",
]);

const LOW_VALUE_TIMELINE_EVENT_TYPES = new Set([
  "systemRefresh",
  "contextGenerated",
  "healthDataUnavailable",
  "stepsUpdated",
]);

const EXCLUDED_TIMELINE_EVENT_TYPES = new Set([
  "unknown",
  "foodEstimateCreated",
  "foodRejected",
  "pendingConfirmationRejected",
  "backendError",
  "authError",
]);

const EXCLUDED_TIMELINE_STATUSES = new Set([
  "rejected",
  "failed",
  "superseded",
]);

const CONSUMED_FACT_EVENT_TYPES = new Set([
  "foodLogged",
  "waterLogged",
  "weightLogged",
  "workoutDetected",
  "stepsUpdated",
]);

const CONTEXT_FORBIDDEN_IMAGE_KEYS = new Set([
  "imageJPEGBase64",
  "imageBase64",
  "jpegBase64",
  "pngBase64",
  "rawImageBytes",
]);

const IMAGE_DATA_URL_PATTERN = /^data:image\//i;
const JPEG_B64_PREFIX = "/9j/";
const PNG_B64_PREFIX = "iVBORw0KGgo";
const SUSPICIOUS_BASE64_PATTERN = /^[A-Za-z0-9+/]{256,}={0,2}$/;
const LINKED_ENTRY_ID_PATTERN =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

function isPromptEligibleTimelineEvent(event: Record<string, unknown>): boolean {
  const status = String(event.status ?? "");
  if (EXCLUDED_TIMELINE_STATUSES.has(status)) {
    return false;
  }
  if (status === "pending" && event.type !== "pendingConfirmationCreated") {
    return false;
  }
  const type = String(event.type ?? "");
  if (EXCLUDED_TIMELINE_EVENT_TYPES.has(type)) {
    return false;
  }
  if (CONSUMED_FACT_EVENT_TYPES.has(type) && status !== "confirmed") {
    return false;
  }
  return true;
}

export interface CoachContextPacketV2Meta {
  schemaVersion: number;
  generatedAt?: string;
  timezoneIdentifier?: string;
  localDate?: string;
  localTime?: string;
  appVersion?: string;
}

export interface CoachContextPacketV2Input {
  meta: CoachContextPacketV2Meta;
  [key: string]: unknown;
}

export type SanitizedCoachContextPacketV2 = Record<string, unknown>;

function isPlainObject(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function clampString(value: unknown, maxLength: number): string | undefined {
  if (typeof value !== "string") return undefined;
  const trimmed = value.trim();
  if (!trimmed) return undefined;
  if (trimmed.length <= maxLength) return trimmed;
  return `${trimmed.slice(0, maxLength)}…`;
}

function optionalString(value: unknown, field: string, maxLength: number): void {
  if (value === undefined || value === null) return;
  if (typeof value !== "string") {
    throw new GatewayError(400, "Invalid context.");
  }
  if (value.length > maxLength) {
    throw new GatewayError(400, "Invalid context.");
  }
}

function optionalNumber(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new GatewayError(400, "Invalid context.");
  }
}

function optionalBoolean(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (typeof value !== "boolean") {
    throw new GatewayError(400, "Invalid context.");
  }
}

function optionalArray(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (!Array.isArray(value)) {
    throw new GatewayError(400, "Invalid context.");
  }
}

function isValidLinkedEntryId(value: unknown): value is string {
  return typeof value === "string" && LINKED_ENTRY_ID_PATTERN.test(value);
}

function validateLinkedEntryId(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (!isValidLinkedEntryId(value)) {
    throw new GatewayError(400, "Invalid context.");
  }
}

function looksLikeEmbeddedImageData(value: string): boolean {
  const trimmed = value.trim();
  if (IMAGE_DATA_URL_PATTERN.test(trimmed)) {
    return true;
  }
  if (trimmed.length < COACH_CONTEXT_LIMITS.minSuspiciousBase64Length) {
    return false;
  }
  if (trimmed.startsWith(JPEG_B64_PREFIX) || trimmed.startsWith(PNG_B64_PREFIX)) {
    return true;
  }
  if (!SUSPICIOUS_BASE64_PATTERN.test(trimmed)) {
    return false;
  }
  if (/^(.)\1{255,}$/.test(trimmed)) {
    return false;
  }
  return trimmed.includes("+") || trimmed.includes("/") || trimmed.endsWith("=");
}

/** Rejects raw image bytes embedded anywhere inside Coach context. */
export function assertNoImageDataInCoachContext(
  value: unknown,
  path = "context"
): void {
  if (value === null || value === undefined) {
    return;
  }

  if (typeof value === "string") {
    if (looksLikeEmbeddedImageData(value)) {
      throw new GatewayError(400, "Invalid context.");
    }
    return;
  }

  if (Array.isArray(value)) {
    value.forEach((item, index) => {
      assertNoImageDataInCoachContext(item, `${path}[${index}]`);
    });
    return;
  }

  if (!isPlainObject(value)) {
    return;
  }

  for (const [key, child] of Object.entries(value)) {
    if (CONTEXT_FORBIDDEN_IMAGE_KEYS.has(key)) {
      throw new GatewayError(400, "Invalid context.");
    }
    if (key === "image" && isPlainObject(child) && typeof child.base64 === "string") {
      throw new GatewayError(400, "Invalid context.");
    }
    if (key === "base64" && typeof child === "string" && child.length > 0) {
      throw new GatewayError(400, "Invalid context.");
    }
    assertNoImageDataInCoachContext(child, `${path}.${key}`);
  }
}

function validateTimelineEvents(events: unknown): void {
  if (!Array.isArray(events)) return;

  for (const event of events) {
    if (!isPlainObject(event)) {
      throw new GatewayError(400, "Invalid context.");
    }
    if (event.summary !== undefined && typeof event.summary !== "string") {
      throw new GatewayError(400, "Invalid context.");
    }
    validateLinkedEntryId(event.linkedEntryId, "timeline.recentEvents.linkedEntryId");
  }
}

function validateRecentChatMessages(messages: unknown): void {
  if (!Array.isArray(messages)) return;

  for (const message of messages) {
    if (!isPlainObject(message)) {
      throw new GatewayError(400, "Invalid context.");
    }
    const text = message.text ?? message.textPreview;
    if (text !== undefined && typeof text !== "string") {
      throw new GatewayError(400, "Invalid context.");
    }
  }
}

function validateAssumptions(assumptions: unknown): void {
  if (!Array.isArray(assumptions)) return;

  for (const assumption of assumptions) {
    if (!isPlainObject(assumption)) {
      throw new GatewayError(400, "Invalid context.");
    }
    if (assumption.detail !== undefined && typeof assumption.detail !== "string") {
      throw new GatewayError(400, "Invalid context.");
    }
    if (typeof assumption.detail === "string" &&
      assumption.detail.length > COACH_CONTEXT_LIMITS.maxAssumptionDetailLength) {
      throw new GatewayError(400, "Invalid context.");
    }
  }
}

function validateRecentMeals(meals: unknown): void {
  if (!Array.isArray(meals)) return;

  for (const meal of meals) {
    if (!isPlainObject(meal)) {
      throw new GatewayError(400, "Invalid context.");
    }
    validateLinkedEntryId(meal.linkedEntryId, "recentMealsStructured.linkedEntryId");
  }
}

/**
 * Validates CoachContextPacketV2 shape without requiring every optional section.
 * Rejects wrong schema versions and clearly malformed nested types.
 */
export function validateCoachContextPacketV2(
  value: unknown,
  {required = false}: {required?: boolean} = {}
): CoachContextPacketV2Input {
  if (value === undefined || value === null) {
    if (required) {
      throw new GatewayError(400, "Missing or invalid context.");
    }
    throw new GatewayError(400, "Missing or invalid context.");
  }

  if (!isPlainObject(value)) {
    throw new GatewayError(400, "Missing or invalid context.");
  }

  if (Object.keys(value).length === 0) {
    throw new GatewayError(400, "Missing or invalid context.");
  }

  const meta = value.meta;
  if (!isPlainObject(meta)) {
    throw new GatewayError(400, "Missing or invalid context.");
  }

  if (meta.schemaVersion !== COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION) {
    throw new GatewayError(400, "Invalid context.");
  }

  optionalString(meta.generatedAt, "meta.generatedAt", 64);
  optionalString(meta.timezoneIdentifier, "meta.timezoneIdentifier", 80);
  optionalString(meta.localDate, "meta.localDate", 32);
  optionalString(meta.localTime, "meta.localTime", 16);
  optionalString(meta.appVersion, "meta.appVersion", 32);

  optionalArray(value.recentChatMessages, "recentChatMessages");
  optionalArray(value.recentMealsStructured, "recentMealsStructured");
  optionalArray(value.commonFoods, "commonFoods");
  optionalArray(value.assumptions, "assumptions");

  validateRecentChatMessages(value.recentChatMessages);
  validateRecentMeals(value.recentMealsStructured);
  validateAssumptions(value.assumptions);

  if (value.currentUserMessage !== undefined && value.currentUserMessage !== null) {
    optionalString(
      value.currentUserMessage,
      "currentUserMessage",
      COACH_CONTEXT_LIMITS.maxCurrentUserMessageLength
    );
  }

  if (value.timeline !== undefined) {
    if (!isPlainObject(value.timeline)) {
      throw new GatewayError(400, "Invalid context.");
    }
    const timeline = value.timeline as Record<string, unknown>;
    if (timeline.recentEvents !== undefined) {
      optionalArray(timeline.recentEvents, "timeline.recentEvents");
      validateTimelineEvents(timeline.recentEvents);
    }
  }

  if (value.today !== undefined && !isPlainObject(value.today)) {
    throw new GatewayError(400, "Invalid context.");
  }
  if (value.training !== undefined && !isPlainObject(value.training)) {
    throw new GatewayError(400, "Invalid context.");
  }
  if (value.healthIntelligence !== undefined && !isPlainObject(value.healthIntelligence)) {
    throw new GatewayError(400, "Invalid context.");
  }
  if (value.missingData !== undefined && !isPlainObject(value.missingData)) {
    throw new GatewayError(400, "Invalid context.");
  }
  if (value.profile !== undefined && !isPlainObject(value.profile)) {
    throw new GatewayError(400, "Invalid context.");
  }

  if (isPlainObject(value.today)) {
    if (value.today.steps !== undefined && !isPlainObject(value.today.steps)) {
      throw new GatewayError(400, "Invalid context.");
    }
    if (isPlainObject(value.today.steps)) {
      optionalNumber(value.today.steps.value, "today.steps.value");
    }
    if (value.today.workoutCaloriesBurned !== undefined &&
      !isPlainObject(value.today.workoutCaloriesBurned)) {
      throw new GatewayError(400, "Invalid context.");
    }
  }

  if (isPlainObject(value.training)) {
    if (value.training.workoutsToday !== undefined && value.training.workoutsToday !== null) {
      optionalNumber(value.training.workoutsToday, "training.workoutsToday");
    }
    optionalArray(value.training.workouts, "training.workouts");
  }

  if (isPlainObject(value.missingData)) {
    for (const [key, fieldValue] of Object.entries(value.missingData)) {
      optionalBoolean(fieldValue, `missingData.${key}`);
    }
  }

  assertNoImageDataInCoachContext(value);
  assertCoachContextEncodedSizeWithinLimit(value);

  return value as CoachContextPacketV2Input;
}

/** Rejects encoded Coach context payloads that exceed the transport ceiling. */
export function assertCoachContextEncodedSizeWithinLimit(value: unknown): void {
  const bytes = Buffer.byteLength(JSON.stringify(value), "utf8");
  if (bytes > COACH_CONTEXT_LIMITS.maxEncodedBytes) {
    throw new GatewayError(413, "Context payload too large.");
  }
}

function sanitizeCompactPayload(value: unknown): Record<string, string> | undefined {
  if (!isPlainObject(value)) {
    return undefined;
  }

  const entries = Object.entries(value)
    .slice(0, COACH_CONTEXT_LIMITS.maxCompactPayloadEntries)
    .map(([key, entryValue]) => {
      const normalizedValue = entryValue === null || entryValue === undefined ?
        "" :
        typeof entryValue === "string" ?
          entryValue :
          typeof entryValue === "number" || typeof entryValue === "boolean" ?
            String(entryValue) :
            "[sanitized]";
      return [
        clampString(key, 40) ?? "key",
        clampString(normalizedValue, 80) ?? "",
      ] as const;
    });

  if (entries.length === 0) {
    return undefined;
  }

  return Object.fromEntries(entries);
}

function sanitizeTimelineEvent(event: Record<string, unknown>): Record<string, unknown> {
  const copy: Record<string, unknown> = {
    id: event.id,
    timestamp: event.timestamp,
    type: event.type,
    source: event.source,
    status: event.status,
    summary: clampString(event.summary, COACH_CONTEXT_LIMITS.maxSummaryLength) ?? "",
  };

  if (event.confidence !== undefined) copy.confidence = event.confidence;
  if (isValidLinkedEntryId(event.linkedEntryId)) {
    copy.linkedEntryId = event.linkedEntryId;
  }

  const compactPayload = sanitizeCompactPayload(event.compactPayload);
  if (compactPayload !== undefined) {
    copy.compactPayload = compactPayload;
  }

  return copy;
}

function sanitizeTimeline(timeline: unknown): Record<string, unknown> {
  if (!isPlainObject(timeline)) {
    return {recentEvents: []};
  }

  const events = Array.isArray(timeline.recentEvents) ? timeline.recentEvents : [];
  const normalized = events
    .filter(isPlainObject)
    .filter(isPromptEligibleTimelineEvent)
    .map(sanitizeTimelineEvent);

  const protectedEvents = normalized.filter((event) =>
    PROTECTED_TIMELINE_EVENT_TYPES.has(String(event.type ?? ""))
  );
  const otherEvents = normalized.filter((event) =>
    !PROTECTED_TIMELINE_EVENT_TYPES.has(String(event.type ?? "")) &&
    !LOW_VALUE_TIMELINE_EVENT_TYPES.has(String(event.type ?? ""))
  );

  const merged = [...protectedEvents, ...otherEvents]
    .slice(0, COACH_CONTEXT_LIMITS.maxTimelineEvents);

  return {recentEvents: merged};
}

function sanitizeRecentMeals(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];

  return value
    .filter(isPlainObject)
    .slice(0, COACH_CONTEXT_LIMITS.maxRecentMeals)
    .map((meal) => {
      const sanitized: Record<string, unknown> = {
        name: clampString(meal.name, COACH_CONTEXT_LIMITS.maxStringFieldLength) ?? "Meal",
        mealType: clampString(meal.mealType, 32),
        quantity: typeof meal.quantity === "number" ? meal.quantity : undefined,
        unit: clampString(meal.unit, 32),
        calories: typeof meal.calories === "number" ? Math.round(meal.calories) : undefined,
        proteinGrams: typeof meal.proteinGrams === "number" ? meal.proteinGrams : undefined,
        carbsGrams: typeof meal.carbsGrams === "number" ? meal.carbsGrams : undefined,
        fatGrams: typeof meal.fatGrams === "number" ? meal.fatGrams : undefined,
        loggedAt: meal.loggedAt,
        localDate: clampString(meal.localDate, 32),
        source: clampString(meal.source, 64),
        confidence: meal.confidence,
      };
      if (isValidLinkedEntryId(meal.linkedEntryId)) {
        sanitized.linkedEntryId = meal.linkedEntryId;
      }
      return sanitized;
    });
}

function sanitizeCommonFoods(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];

  return value
    .filter(isPlainObject)
    .slice(0, COACH_CONTEXT_LIMITS.maxCommonFoods)
    .map((food) => ({
      name: clampString(food.name, COACH_CONTEXT_LIMITS.maxStringFieldLength) ?? "food",
      displayName: clampString(food.displayName, COACH_CONTEXT_LIMITS.maxStringFieldLength),
      frequency: typeof food.frequency === "number" ? food.frequency : food.logCount,
      logCount: typeof food.logCount === "number" ? food.logCount : undefined,
      lastLoggedAt: food.lastLoggedAt,
      typicalCalories: typeof food.typicalCalories === "number" ?
        Math.round(food.typicalCalories) :
        undefined,
      typicalProteinGrams: typeof food.typicalProteinGrams === "number" ?
        food.typicalProteinGrams :
        undefined,
      typicalCarbsGrams: typeof food.typicalCarbsGrams === "number" ?
        food.typicalCarbsGrams :
        undefined,
      typicalFatGrams: typeof food.typicalFatGrams === "number" ?
        food.typicalFatGrams :
        undefined,
      macroConfidence: food.macroConfidence,
    }));
}

function sanitizeChatMessages(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];

  return value
    .filter(isPlainObject)
    .slice(0, COACH_CONTEXT_LIMITS.maxChatMessages)
    .map((message) => ({
      id: message.id,
      role: message.role,
      text: clampString(
        message.text ?? message.textPreview,
        COACH_CONTEXT_LIMITS.maxChatPreviewLength
      ) ?? "",
      timestamp: message.timestamp ?? message.sentAt,
      hasPhotoAttachment: Boolean(message.hasPhotoAttachment),
    }));
}

function sanitizeCurrentUserMessage(value: unknown): string | undefined {
  return clampString(value, COACH_CONTEXT_LIMITS.maxCurrentUserMessageLength);
}

function sanitizeAssumptions(value: unknown): Record<string, unknown>[] {
  if (!Array.isArray(value)) return [];

  return value
    .filter(isPlainObject)
    .slice(0, COACH_CONTEXT_LIMITS.maxAssumptions)
    .map((assumption) => ({
      key: clampString(assumption.key, 64) ?? "assumption",
      detail: clampString(
        assumption.detail,
        COACH_CONTEXT_LIMITS.maxAssumptionDetailLength
      ) ?? "",
      confidence: assumption.confidence,
    }));
}

function pickKnownTopLevelFields(
  context: CoachContextPacketV2Input
): SanitizedCoachContextPacketV2 {
  const allowedKeys = new Set([
    "meta",
    "profile",
    "today",
    "training",
    "healthIntelligence",
    "timeline",
    "recentChatMessages",
    "currentUserMessage",
    "recentMealsStructured",
    "commonFoods",
    "missingData",
    "assumptions",
    "generationMode",
    "sourceAttribution",
  ]);

  const sanitized: SanitizedCoachContextPacketV2 = {
    meta: context.meta,
  };

  for (const key of allowedKeys) {
    if (key === "meta") continue;
    if (context[key] !== undefined) {
      sanitized[key] = context[key];
    }
  }

  return sanitized;
}

/**
 * Validates and sanitizes CoachContextPacketV2 for prompt embedding.
 * Strips unknown top-level keys and clamps list/string fields.
 */
export function parseCoachContextForPrompt(
  value: unknown,
  options: {required?: boolean} = {}
): SanitizedCoachContextPacketV2 | null {
  if (value === undefined || value === null) {
    if (options.required) {
      validateCoachContextPacketV2(value, {required: true});
    }
    return null;
  }

  const validated = validateCoachContextPacketV2(value, options);
  const known = pickKnownTopLevelFields(validated);

  known.timeline = sanitizeTimeline(known.timeline);
  known.recentChatMessages = sanitizeChatMessages(known.recentChatMessages);
  if (known.currentUserMessage !== undefined) {
    known.currentUserMessage = sanitizeCurrentUserMessage(known.currentUserMessage);
  }
  known.recentMealsStructured = sanitizeRecentMeals(known.recentMealsStructured);
  known.commonFoods = sanitizeCommonFoods(known.commonFoods);
  known.assumptions = sanitizeAssumptions(known.assumptions);

  if (isPlainObject(known.healthIntelligence)) {
    const hi = {...known.healthIntelligence};
    hi.recoveryExplanation = clampString(
      hi.recoveryExplanation,
      COACH_CONTEXT_LIMITS.maxStringFieldLength
    );
    hi.workoutSummaryText = clampString(
      hi.workoutSummaryText,
      COACH_CONTEXT_LIMITS.maxStringFieldLength
    );
    hi.adaptiveNutritionAdvice = clampString(
      hi.adaptiveNutritionAdvice,
      COACH_CONTEXT_LIMITS.maxStringFieldLength
    );
    known.healthIntelligence = hi;
  }

  if (isPlainObject(known.training)) {
    const training = {...known.training};
    training.trainingLoadExplanation = clampString(
      training.trainingLoadExplanation,
      COACH_CONTEXT_LIMITS.maxStringFieldLength
    );
    if (Array.isArray(training.workouts)) {
      training.workouts = training.workouts
        .filter(isPlainObject)
        .slice(0, 10)
        .map((workout) => ({
          title: clampString(workout.title, 80) ?? "Workout",
          type: clampString(workout.type, 64),
          start: workout.start,
          end: workout.end,
          durationMinutes: workout.durationMinutes,
          activeEnergyKcal: workout.activeEnergyKcal,
          source: clampString(workout.source, 64),
          confidence: workout.confidence,
        }));
    }
    known.training = training;
  }

  return known;
}

function missingDataTrueFlags(value: unknown): string[] {
  if (!isPlainObject(value)) return [];
  return Object.entries(value)
    .filter(([, flagValue]) => flagValue === true)
    .map(([key]) => key)
    .sort();
}

function contextSizeBucket(byteCount: number): string {
  if (byteCount < 4_096) return "<4k";
  if (byteCount < 8_192) return "4k-8k";
  if (byteCount < 16_384) return "8k-16k";
  if (byteCount < 24_576) return "16k-24k";
  return ">24k";
}

function estimateContextByteCount(value: Record<string, unknown>): number {
  try {
    return Buffer.byteLength(JSON.stringify(value), "utf8");
  } catch {
    return 0;
  }
}

function countMissingDataFlags(missingData: unknown): number {
  if (!isPlainObject(missingData)) return 0;
  return Object.values(missingData).filter((field) => field === true).length;
}

/** Privacy-safe logging fields — counts and flags only, never raw nutrition/chat text. */
export function coachContextLogFields(
  value: unknown
): Record<string, string | number | boolean | null> {
  if (!isPlainObject(value)) {
    return {
      contextSchemaVersion: null,
      contextPresent: false,
      contextMissingDataFlags: null,
    };
  }

  const meta = isPlainObject(value.meta) ? value.meta : null;
  const timeline = isPlainObject(value.timeline) ? value.timeline : null;
  const timelineEvents = Array.isArray(timeline?.recentEvents) ?
    timeline.recentEvents.length :
    0;
  const missingFlags = missingDataTrueFlags(value.missingData);
  const encodedBytes = estimateContextByteCount(value);

  return {
    contextPresent: true,
    contextSchemaVersion: typeof meta?.schemaVersion === "number" ?
      meta.schemaVersion :
      null,
    contextGenerationMode: typeof value.generationMode === "string" ?
      value.generationMode :
      null,
    contextSizeBucket: contextSizeBucket(encodedBytes),
    contextEncodedBytes: encodedBytes,
    contextLocalDate: typeof meta?.localDate === "string" ? meta.localDate : null,
    contextTimelineEvents: timelineEvents,
    contextRecentMeals: Array.isArray(value.recentMealsStructured) ?
      value.recentMealsStructured.length :
      0,
    contextCommonFoods: Array.isArray(value.commonFoods) ? value.commonFoods.length : 0,
    contextChatMessages: Array.isArray(value.recentChatMessages) ?
      value.recentChatMessages.length :
      0,
    contextAssumptions: Array.isArray(value.assumptions) ? value.assumptions.length : 0,
    contextMissingDataFlags: missingFlags.length > 0 ? missingFlags.join(",") : null,
    contextMissingDataFlagsCount: countMissingDataFlags(value.missingData),
    contextHasHealthIntelligence: isPlainObject(value.healthIntelligence),
    contextHasTraining: isPlainObject(value.training),
    contextGenerationFailed: missingFlags.includes("contextGenerationFailed"),
  };
}
