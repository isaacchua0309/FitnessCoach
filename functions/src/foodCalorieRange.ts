/* eslint-disable require-jsdoc */

export type FoodConfidenceLevel = "low" | "medium" | "high";

export interface FoodCalorieRange {
  lower: number;
  upper: number;
}

export function deriveCalorieRange(
  calories: number,
  confidence: FoodConfidenceLevel
): FoodCalorieRange {
  const roundedCalories = Math.max(0, Math.round(calories));
  const margin = confidence === "high" ? 0.05 : confidence === "medium" ? 0.12 : 0.20;
  const spread = Math.max(10, Math.round(roundedCalories * margin));
  return {
    lower: Math.max(0, roundedCalories - spread),
    upper: roundedCalories + spread,
  };
}

export function resolveCalorieRange(
  calories: number,
  confidence: FoodConfidenceLevel,
  explicitLower?: number | null,
  explicitUpper?: number | null
): FoodCalorieRange {
  if (
    typeof explicitLower === "number" &&
    typeof explicitUpper === "number" &&
    explicitLower >= 0 &&
    explicitUpper >= explicitLower
  ) {
    return {
      lower: Math.round(explicitLower),
      upper: Math.round(explicitUpper),
    };
  }
  return deriveCalorieRange(calories, confidence);
}
