/* eslint-disable require-jsdoc, max-len */

import {resolveCalorieRange, validateCalorieRangeBounds, type ConfidenceLevel} from "./foodCalorieRange";

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

export function defaultUncertaintyReason(confidence: ConfidenceLevel): string {
  switch (confidence) {
  case "low":
    return "Portion size or hidden ingredients are unclear.";
  case "medium":
    return "Some portion or preparation details were assumed.";
  default:
    return "Minor preparation details were assumed.";
  }
}

export interface NormalizeTrustInput {
  confidence: ConfidenceLevel;
  calories: number;
  rangeLower?: number;
  rangeUpper?: number;
  assumptions?: string[];
  uncertaintyReasons?: string[];
  suggestedClarifications?: string[];
  primaryUncertainty?: string | null;
  requiresClarificationBeforeLogging?: boolean;
  label: string;
}

export function normalizeTrustFields(input: NormalizeTrustInput) {
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
  if (input.confidence === "low" ||
    suggestedClarifications.length > 0 ||
    uncertaintyReasons.some((reason) => /portion|sauce|oil|unclear|ambiguous/i.test(reason))) {
    requiresClarificationBeforeLogging = true;
  }
  const normalizedUncertainty = uncertaintyReasons.length > 0 ?
    uncertaintyReasons :
    input.confidence === "low" ?
      [defaultUncertaintyReason(input.confidence)] :
      uncertaintyReasons;
  const normalizedClarifications = suggestedClarifications.length > 0 ?
    suggestedClarifications :
    requiresClarificationBeforeLogging && input.primaryUncertainty ?
      [`Can you clarify ${input.primaryUncertainty}?`] :
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

export function validateTrustFields(input: NormalizeTrustInput): string[] {
  const errors: string[] = [];
  const uncertaintyReasons = sanitizeStringList(input.uncertaintyReasons);
  const suggestedClarifications = sanitizeStringList(input.suggestedClarifications);
  const range = resolveCalorieRange(
    input.calories,
    input.confidence,
    input.rangeLower,
    input.rangeUpper
  );
  if (input.confidence === "low" && uncertaintyReasons.length === 0) {
    errors.push(`${input.label} must include uncertaintyReasons when confidence is low.`);
  }
  if (input.requiresClarificationBeforeLogging && suggestedClarifications.length === 0) {
    errors.push(`${input.label} must include suggestedClarifications when requiresClarificationBeforeLogging is true.`);
  }
  if (sanitizeStringList(input.assumptions).length === 0) {
    errors.push(`${input.label} must include assumptions.`);
  }
  errors.push(...validateCalorieRangeBounds(
    input.calories,
    range.lower,
    range.upper,
    input.confidence,
    input.label
  ));
  return errors;
}
