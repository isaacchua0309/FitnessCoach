/* eslint-disable require-jsdoc */
export function sanitizeNutritionPayload(
  payload: Record<string, unknown> | null | undefined
): Record<string, string> {
  if (!payload) {
    return {};
  }

  const result: Record<string, string> = {};
  for (const [key, value] of Object.entries(payload)) {
    if (value == null) {
      continue;
    }
    if (typeof value !== "string") {
      continue;
    }
    const trimmed = value.trim();
    if (!trimmed || trimmed.toLowerCase() === "null") {
      continue;
    }
    result[key] = trimmed;
  }
  return result;
}

export function sanitizeNutritionSuggestedActions(
  actions: Array<Record<string, unknown>> | null | undefined
): Array<Record<string, unknown>> {
  if (!Array.isArray(actions)) {
    return [];
  }

  return actions.map((action) => ({
    ...action,
    payload: sanitizeNutritionPayload(
      action.payload as Record<string, unknown> | undefined
    ),
  }));
}

export function sanitizeNutritionEstimateResponse(
  estimate: Record<string, unknown>
): Record<string, unknown> {
  return {
    ...estimate,
    suggestedActions: sanitizeNutritionSuggestedActions(
      estimate.suggestedActions as Array<Record<string, unknown>>
    ),
  };
}

export function sanitizeNutritionComparisonResponse(
  comparison: Record<string, unknown>
): Record<string, unknown> {
  return {
    ...comparison,
    suggestedActions: sanitizeNutritionSuggestedActions(
      comparison.suggestedActions as Array<Record<string, unknown>>
    ),
  };
}
