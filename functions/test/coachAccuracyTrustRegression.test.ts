import {
  applyCoachIntentPhraseGuard,
  isEstimateWithoutLogging,
  suggestedIntentForText,
} from "../src/coachIntentPhraseGuard";
import {normalizeTrustFields, validateTrustFields} from "../src/foodEstimateTrust";
import {minimumRangeWidth} from "../src/foodCalorieRange";

describe("coach accuracy trust regression matrix", () => {
  const misclassifiedLogFood = {
    intent: "log_food",
    confidence: 0.95,
    domain: "nutrition",
    requiresAppMutation: true,
    requiresUserContext: true,
    canAnswerWithCheapModel: true,
    requiresEscalation: false,
    entities: {food: "pad thai"},
    action: {
      type: "log_food",
      foodDraft: {name: "pad thai", quantity: 1, unit: "plate"},
      waterDraft: null,
      weightDraft: null,
      workoutDraft: null,
      selector: null,
      undoTarget: null,
    },
    reason: "User wants to log.",
  };

  // Flow 3
  it("flow 03: how many calories routes to nutrition_estimate_query without mutation", () => {
    const guarded = applyCoachIntentPhraseGuard(misclassifiedLogFood, "how many calories in chicken rice?");
    expect(guarded.intent).toBe("nutrition_estimate_query");
    expect(guarded.requiresAppMutation).toBe(false);
    expect(guarded.action).toBeNull();
    expect(suggestedIntentForText("how many calories in chicken rice?"))
      .toBe("nutrition_estimate_query");
  });

  // Flow 4
  it("flow 04: estimate pad thai but don't log blocks mutation", () => {
    expect(isEstimateWithoutLogging("estimate pad thai but don't log")).toBe(true);
    const guarded = applyCoachIntentPhraseGuard(
      misclassifiedLogFood,
      "estimate pad thai but don't log"
    );
    expect(guarded.intent).toBe("nutrition_estimate_query");
    expect(guarded.requiresAppMutation).toBe(false);
    expect(guarded.action).toBeNull();
  });

  // Flow 1 trust fields — low confidence vague dish
  it("flow 01: low-confidence chicken rice trust fields widen range", () => {
    const trust = normalizeTrustFields({
      confidence: "low",
      calories: 280,
      assumptions: ["Standard hawker plate"],
      uncertaintyReasons: ["Portion size unclear."],
      suggestedClarifications: ["Was this a small or regular portion?"],
      primaryUncertainty: "Portion size unclear.",
      requiresClarificationBeforeLogging: true,
      label: "chicken rice",
    });

    expect(trust.requiresClarificationBeforeLogging).toBe(true);
    expect(trust.assumptions.length).toBeGreaterThan(0);
    expect(trust.uncertaintyReasons.length).toBeGreaterThan(0);
    expect(trust.rangeUpper - trust.rangeLower)
      .toBeGreaterThanOrEqual(minimumRangeWidth(280, "low"));
  });

  // Flow 2 — exact grams high confidence narrower range
  it("flow 02: high-confidence 200g chicken breast has narrower range than low", () => {
    const high = normalizeTrustFields({
      confidence: "high",
      calories: 330,
      assumptions: ["Skinless grilled chicken breast"],
      uncertaintyReasons: ["Minor preparation details assumed."],
      label: "200g grilled chicken breast",
    });
    const low = normalizeTrustFields({
      confidence: "low",
      calories: 330,
      assumptions: ["Estimated portion"],
      uncertaintyReasons: ["Portion unclear."],
      suggestedClarifications: ["How much chicken was on the plate?"],
      requiresClarificationBeforeLogging: true,
      label: "chicken breast",
    });

    const highWidth = high.rangeUpper - high.rangeLower;
    const lowWidth = low.rangeUpper - low.rangeLower;
    expect(highWidth).toBeLessThan(lowWidth);
    expect(validateTrustFields({
      confidence: "high",
      calories: 330,
      assumptions: high.assumptions,
      uncertaintyReasons: high.uncertaintyReasons,
      rangeLower: high.rangeLower,
      rangeUpper: high.rangeUpper,
      label: "200g grilled chicken breast",
    })).toEqual([]);
  });
});
