/* eslint-disable require-jsdoc, max-len */

import {
  deriveCalorieRange,
  FoodCalorieRange,
  FoodConfidenceLevel,
  resolveCalorieRange,
  validateCalorieRangeBounds,
} from "./foodCalorieRange";

export const GENERIC_FOOD_NAME_PATTERN =
  /\b(unknown|generic|unidentified|mysterious|miscellaneous|various|mixed meal|food item|meal item|something|stuff|snack plate|^food$|^meal$)\b/i;

export const HIGH_RISK_FOOD_PATTERNS = [
  /chicken rice/i,
  /caifan|cai fan|economy rice|mixed rice/i,
  /mala/i,
  /nasi lemak/i,
  /char kway teow|char kway/i,
  /laksa/i,
  /buffet/i,
  /hawker/i,
  /mixed plate/i,
  /curry rice/i,
  /fried noodle/i,
  /creamy dressing|mayo dressing|hidden sauce|extra sauce/i,
] as const;

export const IMAGE_AMBIGUITY_PATTERNS = [
  /cropped/i,
  /unclear/i,
  /blurry/i,
  /multiple plate/i,
  /several plate/i,
] as const;

export function isGenericFoodName(name: string): boolean {
  const trimmed = name.trim();
  if (!trimmed) return true;
  return GENERIC_FOOD_NAME_PATTERN.test(trimmed);
}

export function isHighRiskFoodText(text: string): boolean {
  return HIGH_RISK_FOOD_PATTERNS.some((pattern) => pattern.test(text));
}

export function hasExplicitPortionHint(text: string): boolean {
  const lower = text.toLowerCase();
  if (/\d+\s*(g|gram|grams|kg|ml|oz|lb|cup|cups|tbsp|tablespoon)\b/.test(lower)) {
    return true;
  }
  if (/\d+\s*(piece|pieces|slice|slices|pc|pcs)\b/.test(lower)) {
    return true;
  }
  if (/\d+\s*-\s*\d+\s*(g|gram|grams)\b/.test(lower)) {
    return true;
  }
  return false;
}

export function sanitizeStringList(values: unknown): string[] {
  if (!Array.isArray(values)) {
    return [];
  }
  const seen = new Set<string>();
  const result: string[] = [];
  for (const value of values) {
    const trimmed = String(value).trim();
    if (!trimmed || trimmed.toLowerCase() === "null") continue;
    const key = trimmed.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(trimmed);
  }
  return result;
}

export function capConfidenceForRisk(
  confidence: FoodConfidenceLevel,
  text: string
): FoodConfidenceLevel {
  if (!isHighRiskFoodText(text) || hasExplicitPortionHint(text)) {
    return confidence;
  }
  if (confidence === "high") return "medium";
  return confidence;
}

export function deriveRiskLevel(
  confidence: FoodConfidenceLevel
): "low" | "medium" | "high" {
  switch (confidence) {
  case "high": return "low";
  case "medium": return "medium";
  case "low": return "high";
  }
}

export function defaultUncertaintyReason(confidence: FoodConfidenceLevel): string {
  switch (confidence) {
  case "low":
    return "Portion size or hidden ingredients are unclear.";
  case "medium":
    return "Some portion or preparation details were assumed.";
  default:
    return "Minor preparation details were assumed.";
  }
}

export interface TrustFieldValidationInput {
  confidence: FoodConfidenceLevel;
  calories: number;
  rangeLower?: number | null;
  rangeUpper?: number | null;
  assumptions?: string[];
  uncertaintyReasons?: string[];
  suggestedClarifications?: string[];
  primaryUncertainty?: string | null;
  requiresClarificationBeforeLogging?: boolean;
  label: string;
}

export function validateTrustFields(input: TrustFieldValidationInput): string[] {
  const errors: string[] = [];
  const assumptions = sanitizeStringList(input.assumptions);
  const uncertaintyReasons = sanitizeStringList(input.uncertaintyReasons);
  const suggestedClarifications = sanitizeStringList(input.suggestedClarifications);
  const range = resolveCalorieRange(
    input.calories,
    input.confidence,
    input.rangeLower,
    input.rangeUpper
  );

  errors.push(
    ...validateCalorieRangeBounds(
      input.calories,
      range.lower,
      range.upper,
      input.confidence,
      input.label
    )
  );

  if (input.confidence === "low" && uncertaintyReasons.length === 0) {
    errors.push(`${input.label} must include uncertaintyReasons when confidence is low.`);
  }

  if (input.requiresClarificationBeforeLogging && suggestedClarifications.length === 0) {
    errors.push(
      `${input.label} must include suggestedClarifications when requiresClarificationBeforeLogging is true.`
    );
  }

  if (input.confidence === "low" && assumptions.length === 0) {
    errors.push(`${input.label} must include assumptions when confidence is low.`);
  }

  return errors;
}

export function normalizeTrustFields<T extends TrustFieldValidationInput>(input: T): T {
  const assumptions = sanitizeStringList(input.assumptions);
  const uncertaintyReasons = sanitizeStringList(input.uncertaintyReasons);
  const suggestedClarifications = sanitizeStringList(input.suggestedClarifications);
  const range = resolveCalorieRange(
    input.calories,
    input.confidence,
    input.rangeLower,
    input.rangeUpper
  );

  let requiresClarificationBeforeLogging = input.requiresClarificationBeforeLogging ?? false;
  if (
    input.confidence === "low" ||
    suggestedClarifications.length > 0 ||
  uncertaintyReasons.some((reason) => /portion|sauce|oil|unclear|ambiguous/i.test(reason))
  ) {
    requiresClarificationBeforeLogging = true;
  }

  const normalizedUncertainty = uncertaintyReasons.length > 0 ?
    uncertaintyReasons :
    input.confidence === "low" ?
      [defaultUncertaintyReason(input.confidence)] :
      uncertaintyReasons;

  const normalizedClarifications = suggestedClarifications.length > 0 ?
    suggestedClarifications :
    requiresClarificationBeforeLogging ?
      [
        input.primaryUncertainty ?
          `Can you clarify ${input.primaryUncertainty}?` :
          normalizedUncertainty[0] ?
            `Can you clarify: ${normalizedUncertainty[0]}` :
            "Can you clarify the portion size or hidden ingredients?",
      ] :
      suggestedClarifications;

  return {
    ...input,
    assumptions,
    uncertaintyReasons: normalizedUncertainty,
    suggestedClarifications: normalizedClarifications,
    rangeLower: range.lower,
    rangeUpper: range.upper,
    requiresClarificationBeforeLogging,
    primaryUncertainty: input.primaryUncertainty?.trim() || normalizedUncertainty[0] || null,
  };
}

export function widenRangeForLowConfidence(
  calories: number,
  confidence: FoodConfidenceLevel,
  lower: number,
  upper: number
): FoodCalorieRange {
  const derived = deriveCalorieRange(calories, confidence);
  return {
    lower: Math.min(lower, derived.lower),
    upper: Math.max(upper, derived.upper),
  };
}
