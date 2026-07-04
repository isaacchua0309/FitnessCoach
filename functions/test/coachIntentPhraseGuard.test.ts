import {
  applyCoachIntentPhraseGuard,
  hasExplicitLoggingIntent,
  isAmbiguousAdvicePhrase,
  suggestedIntentForText,
} from "../src/coachIntentPhraseGuard";
import {sanitizeCoachIntentResult} from "../src/coachIntentSanitizer";

describe("coachIntentPhraseGuard", () => {
  const misclassifiedLogFood = {
    intent: "log_food",
    confidence: 0.95,
    domain: "nutrition",
    requiresAppMutation: true,
    requiresUserContext: true,
    canAnswerWithCheapModel: true,
    requiresEscalation: false,
    entities: {food: "chicken rice"},
    action: {
      type: "log_food",
      foodDraft: {name: "chicken rice", quantity: 1, unit: "meal"},
      waterDraft: null,
      weightDraft: null,
      workoutDraft: null,
      selector: null,
      undoTarget: null,
    },
    reason: "User wants to log.",
  };

  it.each([
    ["should I eat chicken rice?", "meal_decision"],
    ["can I fit a burger today?", "meal_decision"],
    ["how many calories in chicken rice?", "nutrition_estimate_query"],
    ["is sushi okay for dinner?", "meal_decision"],
    ["what should I eat after workout?", "nutrition_advice"],
    ["what was breakfast?", "nutrition_estimate_query"],
    ["same as breakfast", "meal_decision"],
  ])("corrects misclassified log_food for advice phrase %s", (text, expectedIntent) => {
    const guarded = applyCoachIntentPhraseGuard(misclassifiedLogFood, text);
    expect(guarded.intent).toBe(expectedIntent);
    expect(guarded.requiresAppMutation).toBe(false);
    expect(guarded.action).toBeNull();
  });

  it.each([
    "I ate chicken rice",
    "log chicken rice",
    "add chicken rice to lunch",
    "I had sushi earlier",
    "log same as breakfast",
    "I ate the same as breakfast",
  ])("preserves explicit logging phrase %s", (text) => {
    const guarded = applyCoachIntentPhraseGuard(misclassifiedLogFood, text);
    expect(guarded.intent).toBe("log_food");
    expect(guarded.requiresAppMutation).toBe(true);
    expect(guarded.action).not.toBeNull();
  });

  it("detects advice and explicit logging helpers", () => {
    expect(isAmbiguousAdvicePhrase("should I eat chicken rice?")).toBe(true);
    expect(hasExplicitLoggingIntent("log chicken rice")).toBe(true);
    expect(suggestedIntentForText("how many calories in chicken rice?"))
      .toBe("nutrition_estimate_query");
  });
});

describe("coachIntentSanitizer phrase guard integration", () => {
  it("downgrades log_food sanitizer output for advice questions", () => {
    const sanitized = sanitizeCoachIntentResult({
      intent: "log_food",
      confidence: 0.91,
      domain: "nutrition",
      requiresAppMutation: true,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      entities: {food: "burger"},
      action: {
        type: "log_food",
        foodDraft: {name: "burger", quantity: 1, unit: "serving"},
        waterDraft: null,
        weightDraft: null,
        workoutDraft: null,
        selector: null,
        undoTarget: null,
      },
      reason: "Logging burger.",
    }, "can I fit a burger today?");

    expect(sanitized.intent).toBe("meal_decision");
    expect(sanitized.action).toBeNull();
    expect(sanitized.requiresAppMutation).toBe(false);
  });

  it("drops spurious log_food action for nutrition_estimate_query advice intents", () => {
    const sanitized = sanitizeCoachIntentResult({
      intent: "nutrition_estimate_query",
      confidence: 0.82,
      domain: "nutrition",
      requiresAppMutation: false,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      entities: {food: "chicken rice"},
      action: {
        type: "log_food",
        foodDraft: {name: "chicken rice", quantity: 1, unit: "meal"},
        waterDraft: null,
        weightDraft: null,
        workoutDraft: null,
        selector: null,
        undoTarget: null,
      },
      reason: "Calorie estimate request.",
    }, "how many calories in chicken rice?");

    expect(sanitized.action).toBeNull();
    expect(sanitized.intent).toBe("nutrition_estimate_query");
  });
});
