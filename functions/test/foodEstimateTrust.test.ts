import {
  capConfidenceForRisk,
  isGenericFoodName,
  isHighRiskFoodText,
  validateTrustFields,
} from "../src/foodEstimateTrust";

describe("foodEstimateTrust", () => {
  it("detects high-risk local foods", () => {
    expect(isHighRiskFoodText("I ate chicken rice")).toBe(true);
    expect(isHighRiskFoodText("caifan with 3 sides")).toBe(true);
    expect(isHighRiskFoodText("2 boiled eggs")).toBe(false);
  });

  it("caps confidence for high-risk foods without explicit portions", () => {
    expect(capConfidenceForRisk("high", "chicken rice")).toBe("medium");
    expect(capConfidenceForRisk("high", "150g chicken rice")).toBe("high");
  });

  it("rejects generic food names", () => {
    expect(isGenericFoodName("food")).toBe(true);
    expect(isGenericFoodName("meal")).toBe(true);
    expect(isGenericFoodName("Chicken rice")).toBe(false);
  });

  it("requires uncertainty reasons for low confidence", () => {
    const errors = validateTrustFields({
      confidence: "low",
      calories: 500,
      rangeLower: 400,
      rangeUpper: 650,
      assumptions: ["Regular portion"],
      uncertaintyReasons: [],
      suggestedClarifications: [],
      primaryUncertainty: null,
      requiresClarificationBeforeLogging: false,
      label: "meal",
    });
    expect(errors.some((error) => error.includes("uncertaintyReasons"))).toBe(true);
  });

  it("requires clarifications when clarification is required", () => {
    const errors = validateTrustFields({
      confidence: "medium",
      calories: 500,
      rangeLower: 430,
      rangeUpper: 580,
      assumptions: ["Regular portion"],
      uncertaintyReasons: ["Portion unclear"],
      suggestedClarifications: [],
      primaryUncertainty: "Portion",
      requiresClarificationBeforeLogging: true,
      label: "meal",
    });
    expect(errors.some((error) => error.includes("suggestedClarifications"))).toBe(true);
  });
});
