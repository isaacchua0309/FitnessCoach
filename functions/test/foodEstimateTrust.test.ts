import {
  defaultUncertaintyReason,
  normalizeTrustFields,
  sanitizeStringList,
  validateTrustFields,
} from "../src/foodEstimateTrust";

describe("foodEstimateTrust", () => {
  it("sanitizes duplicate and empty strings", () => {
    expect(sanitizeStringList([" Portion unclear. ", "portion unclear.", "", "null"]))
      .toEqual(["Portion unclear."]);
  });

  it("fills default uncertainty for low confidence", () => {
    const normalized = normalizeTrustFields({
      confidence: "low",
      calories: 500,
      assumptions: ["Standard plate"],
      label: "meal",
    });
    expect(normalized.uncertaintyReasons).toContain(defaultUncertaintyReason("low"));
    expect(normalized.requiresClarificationBeforeLogging).toBe(true);
  });

  it("requires clarifications when flagged", () => {
    const errors = validateTrustFields({
      confidence: "medium",
      calories: 500,
      assumptions: ["Assumed regular portion"],
      uncertaintyReasons: ["Hidden oil possible."],
      requiresClarificationBeforeLogging: true,
      label: "meal",
    });
    expect(errors.some((error) => error.includes("suggestedClarifications"))).toBe(true);
  });

  it("requires assumptions on every estimate", () => {
    const errors = validateTrustFields({
      confidence: "high",
      calories: 330,
      assumptions: [],
      uncertaintyReasons: ["Minor prep assumed."],
      label: "chicken",
    });
    expect(errors).toContain("chicken must include assumptions.");
  });
});
