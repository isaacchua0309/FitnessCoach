/* eslint-disable require-jsdoc */

import {logger} from "firebase-functions";
import {GatewayError} from "./gatewayGuardrails";

export type ReasoningEffort = "none" | "low" | "medium" | "high" | "xhigh";

const GPT5_SUPPORTED_EFFORTS: ReadonlySet<ReasoningEffort> = new Set([
  "none",
  "low",
  "medium",
  "high",
  "xhigh",
]);

const LEGACY_EFFORT_ALIASES: Record<string, ReasoningEffort> = {
  minimal: "low",
};

export const MODEL_CONFIG_INVALID_MESSAGE =
  "Meal image analysis is temporarily unavailable due to model configuration.";

export function supportedReasoningEffortsForModel(
  model: string
): ReadonlySet<ReasoningEffort> | undefined {
  if (!/^gpt-5/i.test(model)) {
    return undefined;
  }
  return GPT5_SUPPORTED_EFFORTS;
}

export function normalizeReasoningEffort(
  model: string,
  requestedEffort: string
): ReasoningEffort | undefined {
  const supported = supportedReasoningEffortsForModel(model);
  if (!supported) {
    return undefined;
  }

  const trimmed = requestedEffort.trim().toLowerCase();
  const alias = LEGACY_EFFORT_ALIASES[trimmed];
  if (alias) {
    logger.warn("Normalizing unsupported reasoning effort", {
      model,
      requestedEffort: trimmed,
      normalizedEffort: alias,
    });
    return alias;
  }

  if (!supported.has(trimmed as ReasoningEffort)) {
    throw new GatewayError(
      500,
      MODEL_CONFIG_INVALID_MESSAGE,
      "model_config_invalid"
    );
  }

  return trimmed as ReasoningEffort;
}

export function reasoningConfigForModel(
  model: string
): {effort: ReasoningEffort} | undefined {
  const supported = supportedReasoningEffortsForModel(model);
  if (!supported) {
    return undefined;
  }

  const requested = process.env.OPENAI_REASONING_EFFORT?.trim() || "low";
  const effort = normalizeReasoningEffort(model, requested);
  return effort ? {effort} : undefined;
}

export function isOpenAIModelConfigError(message: string): boolean {
  const normalized = message.toLowerCase();
  if (normalized.includes("unsupported value") &&
    normalized.includes("is not supported with the")) {
    return true;
  }
  return normalized.includes("is not supported with the") &&
    (normalized.includes("reasoning") || normalized.includes("effort"));
}
