/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len */

const COACH_ACTION_TYPES = new Set([
  "log_food",
  "log_water",
  "log_weight",
  "log_workout",
  "edit_log",
  "delete_log",
  "undo",
  "status",
  "daily_review",
]);

const NULL_ENTITIES = {
  food: null,
  meal: null,
  amountMl: null,
  weightKg: null,
  durationMinutes: null,
  distanceKm: null,
  calories: null,
  proteinGrams: null,
  carbsGrams: null,
  fatGrams: null,
  quantity: null,
  unit: null,
  notes: null,
};

function coerceNumber(value: unknown, fallback: number): number {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number.parseFloat(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

function nullableString(value: unknown): string | null {
  return typeof value === "string" ? value : null;
}

function nullableInteger(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return Math.trunc(value);
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number.parseInt(value, 10);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function nullableNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string" && value.trim().length > 0) {
    const parsed = Number.parseFloat(value);
    return Number.isFinite(parsed) ? parsed : null;
  }
  return null;
}

function sanitizeCoachIntentEntities(value: unknown): Record<string, unknown> {
  const source = value && typeof value === "object" && !Array.isArray(value) ?
    value as Record<string, unknown> :
    {};

  return {
    food: nullableString(source.food),
    meal: nullableString(source.meal),
    amountMl: nullableInteger(source.amountMl),
    weightKg: nullableNumber(source.weightKg),
    durationMinutes: nullableInteger(source.durationMinutes),
    distanceKm: nullableNumber(source.distanceKm),
    calories: nullableInteger(source.calories),
    proteinGrams: nullableNumber(source.proteinGrams),
    carbsGrams: nullableNumber(source.carbsGrams),
    fatGrams: nullableNumber(source.fatGrams),
    quantity: nullableNumber(source.quantity),
    unit: nullableString(source.unit),
    notes: nullableString(source.notes),
  };
}

function hasObjectValue(value: unknown): value is Record<string, unknown> {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

export function sanitizeCoachAction(value: unknown): Record<string, unknown> | null {
  if (!hasObjectValue(value)) {
    return null;
  }

  const type = value.type;
  if (typeof type !== "string" || !COACH_ACTION_TYPES.has(type)) {
    return null;
  }

  const action = {
    type,
    foodDraft: value.foodDraft ?? null,
    waterDraft: value.waterDraft ?? null,
    weightDraft: value.weightDraft ?? null,
    workoutDraft: value.workoutDraft ?? null,
    selector: nullableString(value.selector),
    undoTarget: nullableString(value.undoTarget),
  };

  switch (type) {
  case "log_food":
    if (!hasObjectValue(action.foodDraft)) return null;
    break;
  case "log_water":
    if (!hasObjectValue(action.waterDraft)) return null;
    break;
  case "log_weight":
    if (!hasObjectValue(action.weightDraft)) return null;
    break;
  case "log_workout":
    if (!hasObjectValue(action.workoutDraft)) return null;
    break;
  default:
    break;
  }

  return action;
}

export function sanitizeCoachIntentResult(raw: Record<string, any>): Record<string, unknown> {
  const confidence = Math.min(Math.max(coerceNumber(raw.confidence, 0.5), 0), 1);

  return {
    intent: typeof raw.intent === "string" ? raw.intent : "general_conversation",
    confidence,
    domain: typeof raw.domain === "string" ? raw.domain : "general",
    requiresAppMutation: Boolean(raw.requiresAppMutation),
    requiresUserContext: Boolean(raw.requiresUserContext),
    canAnswerWithCheapModel: raw.canAnswerWithCheapModel !== false,
    requiresEscalation: Boolean(raw.requiresEscalation),
    entities: sanitizeCoachIntentEntities(raw.entities),
    action: sanitizeCoachAction(raw.action),
    reason: nullableString(raw.reason),
  };
}

export function emptyCoachIntentEntities(): Record<string, null> {
  return {...NULL_ENTITIES};
}
