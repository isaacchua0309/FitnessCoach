/* eslint-disable require-jsdoc, valid-jsdoc, max-len */

/** Built-in defaults when env vars are unset (see `functions/.env.example`). */
export const DEFAULT_MODELS = {
  cheap: "gpt-5-nano",
  default: "gpt-5-nano",
  strong: "gpt-5.4-nano",
  fallback: "gpt-5.4-mini",
} as const;

export interface ModelConfig {
  cheap: string;
  default: string;
  strong: string;
  fallback: string;
}

/** Reads OpenAI model names from process env with stable fallbacks. */
export function readModelConfig(
  env: NodeJS.ProcessEnv = process.env
): ModelConfig {
  return {
    cheap:
      env.OPENAI_CLASSIFIER_MODEL ||
      env.OPENAI_MODEL ||
      DEFAULT_MODELS.cheap,
    default: env.OPENAI_MODEL || DEFAULT_MODELS.default,
    strong: env.OPENAI_STRONG_MODEL || DEFAULT_MODELS.strong,
    fallback: env.OPENAI_FALLBACK_MODEL || DEFAULT_MODELS.fallback,
  };
}

/** All model ids the gateway may select (env-configured + defaults). */
export function allowedModelNames(
  env: NodeJS.ProcessEnv = process.env
): ReadonlySet<string> {
  return new Set(Object.values(readModelConfig(env)));
}

/**
 * Resolves the OpenAI model for a gateway call.
 * Client `modelName` is honored only when it matches an allowed configured model.
 */
export function resolveModel(
  {tier, modelName}: {tier?: string; modelName?: string} = {},
  env: NodeJS.ProcessEnv = process.env
): string {
  const configured = readModelConfig(env);
  if (tier === "cheap") return configured.cheap;
  if (tier === "strong") return configured.strong;

  const allowed = allowedModelNames(env);
  if (typeof modelName === "string" && allowed.has(modelName)) {
    return modelName;
  }

  return configured.default;
}
