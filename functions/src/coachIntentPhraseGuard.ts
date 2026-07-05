/* eslint-disable require-jsdoc, max-len */

const EXPLICIT_LOGGING_PATTERNS = [
  /^(log|add|track|record)\b/i,
  /\b(log this|log that|add this|add that)\b/i,
  /^(i )?(just )?(ate|had|eaten|consumed)\b/i,
  /\bi (just )?(ate|had|finished eating)\b/i,
  /\badd .+ to (breakfast|lunch|dinner|snack|my (breakfast|lunch|dinner))\b/i,
  /\blog .+ (for|to) (breakfast|lunch|dinner|snack)\b/i,
  /\b(log|add) same as\b/i,
  /\b(i ate|i had) (the )?same as\b/i,
  /\bplease log\b/i,
];

const ADVICE_LOOKUP_PATTERNS = [
  /^(should i|can i|could i|may i)\b/i,
  /\bshould i (eat|have|order|get|try|drink)\b/i,
  /\bcan i (eat|have|fit|afford|order|get|drink)\b/i,
  /\bcould i (eat|have|fit|drink)\b/i,
  /\bwould it be okay\b/i,
  /\bis it okay (to|if|for me)\b/i,
  /\bis .+ okay\b/i,
  /\bis .+ healthy\b/i,
  /\btoo much\b/i,
  /^how many calories\b/i,
  /\bcalories in\b/i,
  /\bhow much (protein|carbs|fat|calories) in\b/i,
  /^what should i eat\b/i,
  /\bwhat should i (have|order|get)\b/i,
  /\brecommend (me|a|something)\b/i,
  /\bwould .+ fit\b/i,
  /\bfit my (calories|macros|calorie|protein)\b/i,
  /\bfit my remaining calories\b/i,
  /\b vs \b/i,
  /\bversus\b/i,
  /\bwhich has more\b/i,
  /^what was (breakfast|lunch|dinner|my breakfast|my lunch|my dinner)\b/i,
  /\bwhat did i (eat|have) (for )?(breakfast|lunch|dinner)\b/i,
];

function normalizeText(text: string): string {
  return text.trim().toLowerCase().replace(/\s+/g, " ");
}

export function hasExplicitLoggingIntent(text: string): boolean {
  const normalized = normalizeText(text);
  return EXPLICIT_LOGGING_PATTERNS.some((pattern) => pattern.test(normalized));
}

export function isAmbiguousAdvicePhrase(text: string): boolean {
  if (hasExplicitLoggingIntent(text)) {
    return false;
  }
  const normalized = normalizeText(text);
  return ADVICE_LOOKUP_PATTERNS.some((pattern) => pattern.test(normalized));
}

export function isReferenceOnlyWithoutLogging(text: string): boolean {
  if (hasExplicitLoggingIntent(text)) {
    return false;
  }
  return normalizeText(text).includes("same as");
}

const ESTIMATE_WITHOUT_LOGGING_PATTERNS = [
  /\b(don't|do not|dont) log\b/i,
  /\bwithout logging\b/i,
  /\bnot log(ging)?\b/i,
  /\bestimate only\b/i,
  /\bonly estimate\b/i,
  /\bjust estimate\b/i,
];

export function isEstimateWithoutLogging(text: string): boolean {
  const normalized = normalizeText(text);
  if (ESTIMATE_WITHOUT_LOGGING_PATTERNS.some((pattern) => pattern.test(normalized))) {
    return true;
  }
  if (normalized.startsWith("estimate ")) {
    return !hasExplicitLoggingIntent(text);
  }
  return false;
}

export function suggestedIntentForText(text: string): string {
  const normalized = normalizeText(text);

  if (normalized.includes(" vs ") || normalized.includes(" versus ") || normalized.includes("which has more")) {
    return "nutrition_comparison_query";
  }
  if (normalized.includes("recommend") ||
    normalized.startsWith("what should i eat") ||
    normalized.includes("what should i have")) {
    return "nutrition_advice";
  }
  if (normalized.includes("how many") ||
    normalized.includes("how much") ||
    normalized.includes("calories in") ||
    normalized.startsWith("what was") ||
    normalized.includes("what did i eat") ||
    normalized.includes("what did i have")) {
    return "nutrition_estimate_query";
  }
  if (normalized.includes("calories") && normalized.includes("fit")) {
    return "meal_decision";
  }
  return "meal_decision";
}

export function applyCoachIntentPhraseGuard(
  raw: Record<string, unknown>,
  userText: string
): Record<string, unknown> {
  const trimmed = userText.trim();
  if (trimmed.length === 0 || hasExplicitLoggingIntent(trimmed)) {
    return raw;
  }

  const intent = typeof raw.intent === "string" ? raw.intent : "general_conversation";
  const needsCorrection =
    (isEstimateWithoutLogging(trimmed) && (intent === "log_food" || Boolean(raw.requiresAppMutation) || raw.action != null)) ||
    (intent === "log_food" && (isAmbiguousAdvicePhrase(trimmed) || isReferenceOnlyWithoutLogging(trimmed))) ||
    (isAmbiguousAdvicePhrase(trimmed) && (Boolean(raw.requiresAppMutation) || raw.action != null)) ||
    (isReferenceOnlyWithoutLogging(trimmed) && (intent === "log_food" || raw.action != null));

  if (!needsCorrection) {
    return raw;
  }

  const correctedIntent = isEstimateWithoutLogging(trimmed) ?
    "nutrition_estimate_query" :
    suggestedIntentForText(userText);
  return {
    ...raw,
    intent: correctedIntent,
    requiresAppMutation: false,
    action: null,
    reason: typeof raw.reason === "string" && raw.reason.trim().length > 0 ?
      raw.reason :
      isEstimateWithoutLogging(trimmed) ?
        "Estimate-only phrasing without logging intent." :
        "Advice or lookup phrasing without explicit logging intent.",
  };
}
