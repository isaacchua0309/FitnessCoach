import {sanitizeCoachAction, sanitizeCoachIntentResult} from "../src/coachIntentSanitizer";

describe("coachIntentSanitizer", () => {
  it("drops log_food actions without a populated foodDraft", () => {
    const sanitized = sanitizeCoachIntentResult({
      intent: "general_conversation",
      confidence: 0.9,
      domain: "general",
      requiresAppMutation: false,
      requiresUserContext: true,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      entities: {},
      action: {
        type: "log_food",
        foodDraft: null,
        waterDraft: null,
        weightDraft: null,
        workoutDraft: null,
        selector: null,
        undoTarget: null,
      },
      reason: "Greeting.",
    });

    expect(sanitized.action).toBeNull();
    expect(sanitized.intent).toBe("general_conversation");
    expect(sanitized.entities).toEqual({
      food: null,
      meal: null,
      amountMl: null,
      weightKg: null,
      durationMinutes: null,
      distanceKm: null,
      calories: null,
      proteinGrams: null,
      carbsGrams: null,
      fatGrams: null,
      quantity: null,
      unit: null,
      notes: null,
    });
  });

  it("keeps status actions with null drafts", () => {
    const action = sanitizeCoachAction({
      type: "status",
      foodDraft: null,
      waterDraft: null,
      weightDraft: null,
      workoutDraft: null,
      selector: null,
      undoTarget: null,
    });

    expect(action).toEqual({
      type: "status",
      foodDraft: null,
      waterDraft: null,
      weightDraft: null,
      workoutDraft: null,
      selector: null,
      undoTarget: null,
    });
  });

  it("coerces numeric confidence and fills missing entities", () => {
    const sanitized = sanitizeCoachIntentResult({
      intent: "general_conversation",
      confidence: "0.8",
      domain: "general",
      requiresAppMutation: false,
      requiresUserContext: false,
      canAnswerWithCheapModel: true,
      requiresEscalation: false,
      action: null,
      reason: null,
    });

    expect(sanitized.confidence).toBe(0.8);
    expect(sanitized.entities).toEqual({
      food: null,
      meal: null,
      amountMl: null,
      weightKg: null,
      durationMinutes: null,
      distanceKm: null,
      calories: null,
      proteinGrams: null,
      carbsGrams: null,
      fatGrams: null,
      quantity: null,
      unit: null,
      notes: null,
    });
  });
});
