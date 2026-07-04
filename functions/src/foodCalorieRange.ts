/* eslint-disable require-jsdoc */

export type ConfidenceLevel = "low" | "medium" | "high";

const MIN_RANGE_WIDTH: Record<ConfidenceLevel, number> = {
  high: 10,
  medium: 20,
  low: 40,
};

const RANGE_MARGIN: Record<ConfidenceLevel, number> = {
  high: 0.05,
  medium: 0.12,
  low: 0.20,
};

export function deriveCalorieRange(
  calories: number,
  confidence: ConfidenceLevel
): {lower: number; upper: number} {
  const roundedCalories = Math.max(0, Math.round(calories));
  const margin = RANGE_MARGIN[confidence];
  const spread = Math.max(
    MIN_RANGE_WIDTH[confidence],
    Math.round(roundedCalories * margin)
  );
  return {
    lower: Math.max(0, roundedCalories - spread),
    upper: roundedCalories + spread,
  };
}

export function resolveCalorieRange(
  calories: number,
  confidence: ConfidenceLevel,
  explicitLower?: number | null,
  explicitUpper?: number | null
): {lower: number; upper: number} {
  const roundedCalories = Math.max(0, Math.round(calories));
  if (typeof explicitLower === "number" &&
    typeof explicitUpper === "number" &&
    explicitLower >= 0 &&
    explicitUpper >= explicitLower) {
    return {
      lower: Math.round(explicitLower),
      upper: Math.round(explicitUpper),
    };
  }
  return deriveCalorieRange(roundedCalories, confidence);
}

export function minimumRangeWidth(
  calories: number,
  confidence: ConfidenceLevel
): number {
  const roundedCalories = Math.max(0, Math.round(calories));
  return Math.max(
    MIN_RANGE_WIDTH[confidence],
    Math.round(roundedCalories * RANGE_MARGIN[confidence])
  );
}

export function validateCalorieRangeBounds(
  calories: number,
  lower: number,
  upper: number,
  confidence: ConfidenceLevel,
  label: string
): string[] {
  const errors: string[] = [];
  const roundedCalories = Math.max(0, Math.round(calories));
  if (lower < 0 || upper < 0) {
    errors.push(`${label} calorie range cannot be negative.`);
    return errors;
  }
  if (lower > upper) {
    errors.push(`${label} calorie range lower bound exceeds upper bound.`);
    return errors;
  }
  if (roundedCalories > 0 && lower > roundedCalories) {
    errors.push(
      `${label} calorie range lower bound exceeds estimated calories.`
    );
  }
  if (roundedCalories > 0 && upper < roundedCalories) {
    errors.push(
      `${label} calorie range upper bound is below estimated calories.`
    );
  }
  const width = upper - lower;
  const minWidth = minimumRangeWidth(roundedCalories, confidence);
  if (roundedCalories >= 80 && width < minWidth) {
    errors.push(
      `${label} calorie range is too narrow for ${confidence} confidence ` +
      `(expected at least ~${minWidth} kcal spread).`
    );
  }
  return errors;
}
