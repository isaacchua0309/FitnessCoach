/* eslint-disable max-len, require-jsdoc, valid-jsdoc */

/**
 * Shared CoachContextPacketV2 prompt rules for Firebase aiGateway runtime instructions.
 * Keep authoritative wording here so endpoint prompts stay consistent.
 */

export function coachContextV2Rules(): string {
  return [
    "CoachContextPacketV2 rules (structured context is authoritative):",
    "1. Structured context is the source of truth over chat text, assistant prose, or assumptions.",
    "2. Timeline confirmed events override chat text when they conflict.",
    "3. Pending, rejected, failed, or superseded timeline events must not be treated as logged facts.",
    "4. Never infer that food, water, or weight was logged unless confirmed in context.timeline",
    "   (status confirmed) or reflected in context.today aggregates.",
    "5. If data is missing or unavailable, say it is missing — do not invent values.",
    "6. Use context.meta.localDate and context.meta.timezoneIdentifier to interpret \"today\".",
    "7. Use context.timeline.recentEvents for chronological ordering and reference resolution.",
    "8. Use recentChatMessages and currentUserMessage for conversational continuity only.",
    "9. Use timeline.recentEvents and context.today aggregates for factual claims.",
    "10. Use context.recentMealsStructured for meal-specific references (names, macros, linkedEntryId).",
    "11. Use context.training, context.healthIntelligence, and context.today when giving meal or recovery advice.",
    "12. Never claim HealthKit or synced health data exists when context.missingData marks it unavailable.",
    "13. Do not diagnose medical conditions or prescribe medical treatment.",
    "14. Do not mutate app state. Return intents, drafts, estimates, or coaching text only.",
  ].join("\n");
}

export function coachContextHealthRules(): string {
  return [
    "Health and training context rules:",
    "- When context.healthIntelligence is present, use it before asking whether the user worked out today.",
    "- Use context.training.workoutsToday, context.training.workouts, and training load/recovery fields when available.",
    "- Treat Apple Health workout calories and active energy as estimates, not precise facts.",
    "- If context.missingData.stepsUnavailable, workoutsUnavailable, sleepUnavailable, hrvUnavailable,",
    "  healthKitDenied, healthIntelligenceTimedOut, or healthIntelligenceFailed is true, do not invent those signals.",
    "- Use context.recentMealsStructured and context.commonFoods for meal-history awareness.",
    "- Use context.foodCorrectionMemory only as user-specific hints, never as guaranteed facts.",
    "- When health intelligence is absent, rely on context.today and confirmed timeline events only.",
  ].join("\n");
}

export function classifyCoachIntentPromptRules(): string {
  return [
    "Classify-coach-intent context rules:",
    "- Use the current user text as the primary intent signal.",
    "- Use context.timeline.recentEvents only to resolve references such as \"that\", \"same as earlier\",",
    "  \"undo lunch\", or \"delete the chicken rice\".",
    "- Use recentChatMessages and currentUserMessage for conversational continuity.",
    "- Use timeline.recentEvents and context.today aggregates for factual claims.",
    "- Do not copy nutrition values from context.recentChatMessages, currentUserMessage, or assistant text.",
    "- Prefer linkedEntryId from confirmed timeline events when proposing edit_log or delete_log actions.",
    "- Ignore photoAnalysisFailed, pendingConfirmationCreated (pending), and rejected estimate events",
    "  as if the user already logged food.",
    "- Do not classify advice or lookup questions as log_food.",
    "- Examples that are NOT log_food: \"should I eat chicken rice?\", \"can I fit a burger today?\",",
    "  \"how many calories in chicken rice?\", \"is sushi okay for dinner?\", \"what should I eat after workout?\",",
    "  \"what was breakfast?\", \"same as breakfast\" (without explicit logging/consumption language).",
    "- Examples that ARE log_food: \"I ate chicken rice\", \"log chicken rice\", \"add chicken rice to lunch\",",
    "  \"I had sushi earlier\", \"log same as breakfast\", \"I ate the same as breakfast\".",
  ].join("\n");
}

export function estimateFoodPromptRules(): string {
  return [
    "Estimate-food context rules:",
    "- Use context.timeline.recentEvents and context.commonFoods only for personalization or resolving",
    "  phrases like \"same as usual\" or \"same as breakfast\".",
    "- Use context.foodCorrectionMemory as optional user-specific portion or ingredient hints.",
    "  Treat correction memory as guidance only, not exact truth.",
    "- Still estimate the current food independently from the user's text or photo.",
    "- If the user says \"same as breakfast\", use a confirmed breakfast foodLogged event when present.",
    "- Do not treat rejected estimates, failed photo analysis, or pending confirmations as consumed meals.",
    "- Do not copy prior assistant estimate prose as fact; re-estimate unless the user gives explicit numbers.",
    "- For compound/local dishes, decompose into components instead of one collapsed meal item.",
    "- When serving size is ambiguous, estimate a reasonable medium portion with medium/low confidence",
    "  and note assumptions; ask one concise clarification only if uncertainty is very large.",
  ].join("\n");
}

export function mealAdvicePromptRules(): string {
  return [
    "Meal-advice context rules:",
    "- Use context.today aggregates (nutrition, hydration, targets, steps) and remaining calories/protein/water.",
    "- Use context.recentMealsStructured for what the user actually logged today or recently.",
    "- Use context.training, recovery status, training load, and context.healthIntelligence when advising.",
    "- Match advice to remaining calories, protein, and water when those values are present.",
    "- If a workout was detected today (training or confirmed workoutDetected timeline event),",
    "  include practical post-workout protein and hydration guidance.",
    "- If recovery is low or missing sleep/HRV signals, recommend consistency and recovery-supportive choices.",
    "- When targets or intake are unknown, say what is missing instead of guessing.",
  ].join("\n");
}

export function analyzeMealImagePromptRules(): string {
  return [
    "Analyze-meal-image rules (image-first, context for personalization only):",
    "- The attached meal image is the primary and authoritative source for identifying foods and portions.",
    "- Use context ONLY for goals/targets (context.today.targets, remaining intake), context.commonFoods,",
    "  context.recentMealsStructured, context.training, and context.healthIntelligence — to guide portion",
    "  realism and coaching tone, not to invent foods.",
    "- Do NOT add foods from context.recentMealsStructured, context.commonFoods, or chat unless clearly",
    "  visible in the image.",
    "- Do NOT assume the user ate their usual meal, a recent meal, or a common food if it is not visible.",
    "- When the image is ambiguous, partially obscured, or missing key details, set clarifyingQuestion and",
    "  keep items limited to what is visible with evidence.",
    "- Always set needsUserReview to true (requiresConfirmation before logging).",
    "- Every item must include confidence (low/medium/high) and assumptions[] describing portion/ingredient guesses.",
    "- Mention material assumptions in summary when they materially affect calories.",
    "- Do not treat rejected or pending meal estimates as already consumed.",
  ].join("\n");
}

export function editDeletePromptRules(): string {
  return [
    "Edit/delete context rules:",
    "- Resolve target entries from confirmed timeline events and linkedEntryId when available.",
    "- Use context.recentMealsStructured linkedEntryId as a secondary hint only when timeline is clear.",
    "- If multiple entries could match, ask for clarification and require confirmation.",
    "- Never delete or edit based only on assistant chat text without a confirmed logged event.",
    "- Ignore pending, rejected, failed, or superseded timeline events as deletion targets.",
  ].join("\n");
}

export function dailyReviewPromptRules(): string {
  return [
    "Daily-review context rules:",
    "- Use the deterministic input object for numeric totals; use context.today and confirmed timeline",
    "  events only to enrich wording.",
    "- Do not claim foods or workouts happened unless confirmed in timeline or today aggregates.",
    "- Mention missing signals honestly when context.missingData flags them.",
  ].join("\n");
}
