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
} as const;

const PROTECTED_TIMELINE_EVENT_TYPES = new Set([
  "foodLogged",
  "waterLogged",
  "weightLogged",
  "workoutDetected",
  "stepsUpdated",
  "pendingConfirmationCreated",
  "photoAttached",
  "photoAnalysisCompleted",
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
    throw new GatewayError(400, `Invalid context.${field}.`);
  }
  if (value.length > maxLength) {
    throw new GatewayError(400, `context.${field} exceeds maximum length.`);
  }
}

function optionalNumber(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new GatewayError(400, `Invalid context.${field}.`);
  }
}

function optionalBoolean(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (typeof value !== "boolean") {
    throw new GatewayError(400, `Invalid context.${field}.`);
  }
}

function optionalArray(value: unknown, field: string): void {
  if (value === undefined || value === null) return;
  if (!Array.isArray(value)) {
    throw new GatewayError(400, `Invalid context.${field}.`);
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
    throw new GatewayError(400, "Missing or invalid context.meta.");
  }

  const meta = value.meta;
  if (!isPlainObject(meta)) {
    throw new GatewayError(400, "Missing or invalid context.meta.");
  }

  if (meta.schemaVersion !== COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION) {
    throw new GatewayError(
      400,
      `Invalid context.meta.schemaVersion. Expected ${COACH_CONTEXT_PACKET_V2_SCHEMA_VERSION}.`
    );
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

  if (value.timeline !== undefined) {
    if (!isPlainObject(value.timeline)) {
      throw new GatewayError(400, "Invalid context.timeline.");
    }
    const timeline = value.timeline as Record<string, unknown>;
    if (timeline.recentEvents !== undefined) {
      optionalArray(timeline.recentEvents, "timeline.recentEvents");
    }
  }

  if (value.today !== undefined && !isPlainObject(value.today)) {
    throw new GatewayError(400, "Invalid context.today.");
  }
  if (value.training !== undefined && !isPlainObject(value.training)) {
    throw new GatewayError(400, "Invalid context.training.");
  }
  if (value.healthIntelligence !== undefined && !isPlainObject(value.healthIntelligence)) {
    throw new GatewayError(400, "Invalid context.healthIntelligence.");
  }
  if (value.missingData !== undefined && !isPlainObject(value.missingData)) {
    throw new GatewayError(400, "Invalid context.missingData.");
  }
  if (value.profile !== undefined && !isPlainObject(value.profile)) {
    throw new GatewayError(400, "Invalid context.profile.");
  }

  if (isPlainObject(value.today)) {
    if (value.today.steps !== undefined && !isPlainObject(value.today.steps)) {
      throw new GatewayError(400, "Invalid context.today.steps.");
    }
    if (isPlainObject(value.today.steps)) {
      optionalNumber(value.today.steps.value, "today.steps.value");
    }
    if (value.today.workoutCaloriesBurned !== undefined &&
      !isPlainObject(value.today.workoutCaloriesBurned)) {
      throw new GatewayError(400, "Invalid context.today.workoutCaloriesBurned.");
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

  return value as CoachContextPacketV2Input;
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
  if (event.linkedEntryId !== undefined) copy.linkedEntryId = event.linkedEntryId;

  if (isPlainObject(event.compactPayload)) {
    const entries = Object.entries(event.compactPayload)
      .slice(0, COACH_CONTEXT_LIMITS.maxCompactPayloadEntries)
      .map(([key, value]) => [
        clampString(key, 40) ?? key,
        clampString(String(value), 80) ?? String(value),
      ]);
    copy.compactPayload = Object.fromEntries(entries);
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
    .map((meal) => ({
      name: clampString(meal.name, COACH_CONTEXT_LIMITS.maxStringFieldLength) ?? "Meal",
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
      linkedEntryId: meal.linkedEntryId,
    }));
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
      detail: clampString(assumption.detail, COACH_CONTEXT_LIMITS.maxStringFieldLength) ?? "",
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

/** Privacy-safe logging fields — never includes raw health/nutrition payloads. */
export function coachContextLogFields(
  value: unknown
): Record<string, string | number | boolean | null> {
  if (!isPlainObject(value)) {
    return {
      contextSchemaVersion: null,
      contextPresent: false,
    };
  }

  const meta = isPlainObject(value.meta) ? value.meta : null;
  const timeline = isPlainObject(value.timeline) ? value.timeline : null;
  const timelineEvents = Array.isArray(timeline?.recentEvents) ?
    timeline.recentEvents.length :
    0;

  return {
    contextPresent: true,
    contextSchemaVersion: typeof meta?.schemaVersion === "number" ?
      meta.schemaVersion :
      null,
    contextLocalDate: typeof meta?.localDate === "string" ? meta.localDate : null,
    contextTimelineEvents: timelineEvents,
    contextRecentMeals: Array.isArray(value.recentMealsStructured) ?
      value.recentMealsStructured.length :
      0,
    contextCommonFoods: Array.isArray(value.commonFoods) ? value.commonFoods.length : 0,
    contextHasHealthIntelligence: isPlainObject(value.healthIntelligence),
    contextHasTraining: isPlainObject(value.training),
  };
}
