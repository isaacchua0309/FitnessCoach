import {minimalCoachContextV2} from "./fixtures/coachContextPacketV2";
import {
  mealImageAnalysisInstructions,
  parseMealImageAnalysisResponse,
  validateAnalyzeMealImagePayload,
  validateMealImageAnalysisResponse,
} from "../src/mealImageAnalysis";

const tinyPngBase64 =
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==";

const validAnalysisResponse = {
  summary: "Grilled chicken with rice and broccoli.",
  items: [
    {
      name: "Grilled chicken breast",
      quantity: "150 g",
      calories: 248,
      protein: 46,
      carbs: 0,
      fat: 5,
      confidence: "high",
      assumptions: ["Skinless portion"],
    },
    {
      name: "Cooked white rice",
      quantity: "1 cup",
      calories: 205,
      protein: 4,
      carbs: 45,
      fat: 0.4,
      confidence: "medium",
      assumptions: ["Steamed, no butter"],
    },
  ],
  total: {
    calories: 453,
    protein: 50,
    carbs: 45,
    fat: 5.4,
  },
  needsUserReview: true,
  clarifyingQuestion: null,
};

describe("mealImageAnalysis instructions", () => {
  it("prioritizes visible food and forbids hidden context inference", () => {
    const instructions = mealImageAnalysisInstructions();
    expect(instructions).toContain("primary source of truth");
    expect(instructions).toContain("Do NOT add foods from context.recentMealsStructured");
    expect(instructions).toContain("needsUserReview");
    expect(instructions).toContain("assumptions");
  });
});

describe("mealImageAnalysis validation", () => {
  it("accepts a valid JPEG payload and normalizes base64", () => {
    const body = {
      message: "Lunch bowl",
      context: {...minimalCoachContextV2},
      image: {
        mimeType: "image/jpeg",
        base64: "/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAgGBgcGBQgHBwcJCQgKDBQNDAsLDBkSEw8UHRofHh0aHBwgJC4nICIsIxwcKDcpLDAxNDQ0Hyc5PTgyPC4zNDL/2wBDAQkJCQwLDBgNDRgyIRwhMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjIyMjL/wAARCAABAAEDASIAAhEBAxEB/8QAFQABAQAAAAAAAAAAAAAAAAAAAAn/xAAUEAEAAAAAAAAAAAAAAAAAAAAA/8QAFQEBAQAAAAAAAAAAAAAAAAAAAAX/xAAUEQEAAAAAAAAAAAAAAAAAAAAA/9oADAMBAAIRAxEAPwCwAA//2Q==",
      },
    };

    validateAnalyzeMealImagePayload(body);

    expect(body.image.mimeType).toBe("image/jpeg");
    expect(body.image.base64).not.toContain("data:");
    expect(body.message).toBe("Lunch bowl");
  });

  it("accepts PNG with matching magic bytes", () => {
    const body = {
      context: {...minimalCoachContextV2},
      image: {
        mimeType: "image/png",
        base64: tinyPngBase64,
      },
    };

    expect(() => validateAnalyzeMealImagePayload(body)).not.toThrow();
  });

  it("rejects empty image base64", () => {
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/jpeg", base64: "   "},
    })).toThrow("Missing or invalid image.base64.");
  });

  it("rejects missing context", () => {
    expect(() => validateAnalyzeMealImagePayload({
      image: {mimeType: "image/png", base64: tinyPngBase64},
    })).toThrow("Missing or invalid context.");
  });

  it("rejects unsupported HEIC mime type", () => {
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/heic", base64: tinyPngBase64},
    })).toThrow("image/heic is not supported");
  });

  it("rejects unsupported mime types", () => {
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/webp", base64: tinyPngBase64},
    })).toThrow('Unsupported image.mimeType "image/webp"');
  });

  it("rejects base64 that does not match declared mime type", () => {
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/jpeg", base64: tinyPngBase64},
    })).toThrow("image.base64 does not match image.mimeType.");
  });

  it("rejects oversized base64 payloads with 413", () => {
    process.env.FORMA_AI_MAX_IMAGE_B64_CHARS = "16";
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/png", base64: tinyPngBase64},
    })).toThrow("image.base64 exceeds maximum length.");
    delete process.env.FORMA_AI_MAX_IMAGE_B64_CHARS;
  });

  it("rejects invalid width and height", () => {
    expect(() => validateAnalyzeMealImagePayload({
      context: {...minimalCoachContextV2},
      image: {
        mimeType: "image/png",
        base64: tinyPngBase64,
        width: 0,
      },
    })).toThrow("Invalid image.width.");
  });

  it("accepts recommission clarification and previousAnalysis", () => {
    const body = {
      context: {...minimalCoachContextV2},
      image: {mimeType: "image/png", base64: tinyPngBase64},
      clarification: "It was barley.",
      previousAnalysis: {
        summary: "Grain bowl",
        items: [{
          name: "Grain bowl",
          calories: 400,
          protein: 16,
          carbs: 52,
          fat: 10,
          confidence: "low",
          assumptions: [],
        }],
        total: {calories: 400, protein: 16, carbs: 52, fat: 10},
      },
    };

    expect(() => validateAnalyzeMealImagePayload(body)).not.toThrow();
    expect(body.clarification).toBe("It was barley.");
  });
});

describe("mealImageAnalysis response parsing", () => {
  it("parses a valid model response", () => {
    const parsed = parseMealImageAnalysisResponse(validAnalysisResponse);

    expect(parsed.summary).toContain("chicken");
    expect(parsed.items).toHaveLength(2);
    expect(parsed.total.calories).toBe(453);
    expect(parsed.needsUserReview).toBe(true);
    expect(parsed.clarifyingQuestion).toBeUndefined();
  });

  it("rejects generic fallback food names", () => {
    const result = validateMealImageAnalysisResponse({
      ...validAnalysisResponse,
      items: [{
        name: "Generic mixed meal",
        calories: 500,
        protein: 20,
        carbs: 50,
        fat: 15,
        confidence: "low",
        assumptions: [],
      }],
      total: {calories: 500, protein: 20, carbs: 50, fat: 15},
    });

    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("too generic"))).toBe(true);
  });

  it("rejects totals that do not match item sums", () => {
    const result = validateMealImageAnalysisResponse({
      ...validAnalysisResponse,
      total: {
        calories: 100,
        protein: 50,
        carbs: 45,
        fat: 5.4,
      },
    });

    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("total.calories"))).toBe(true);
  });

  it("rejects empty item lists", () => {
    const result = validateMealImageAnalysisResponse({
      ...validAnalysisResponse,
      items: [],
      total: {calories: 0, protein: 0, carbs: 0, fat: 0},
    });

    expect(result.ok).toBe(false);
    expect(result.errors).toContain("items must contain at least one identified food.");
  });

  it("parseMealImageAnalysisResponse throws 422 for invalid extraction", () => {
    expect(() => parseMealImageAnalysisResponse({
      ...validAnalysisResponse,
      items: [],
      total: {calories: 0, protein: 0, carbs: 0, fat: 0},
    })).toThrow("items must contain at least one identified food.");
  });

  it("parses ambiguous analysis with clarifyingQuestion and trust metadata", () => {
    const parsed = parseMealImageAnalysisResponse({
      ...validAnalysisResponse,
      items: [{
        name: "Grain bowl",
        quantity: "1 bowl",
        calories: 400,
        protein: 16,
        carbs: 52,
        fat: 10,
        confidence: "low",
        assumptions: ["Grain type unclear"],
        uncertaintyReasons: ["Grain type unclear"],
        suggestedClarifications: ["Was this rice or barley?"],
        primaryUncertainty: "Grain type",
        calorieRangeLower: 340,
        calorieRangeUpper: 480,
      }],
      total: {
        calories: 400,
        protein: 16,
        carbs: 52,
        fat: 10,
        calorieRangeLower: 340,
        calorieRangeUpper: 480,
      },
      needsUserReview: true,
      clarifyingQuestion: "Was this rice or barley?",
      primaryUncertainty: "Grain type",
    });

    expect(parsed.needsUserReview).toBe(true);
    expect(parsed.clarifyingQuestion).toBe("Was this rice or barley?");
    expect(parsed.primaryUncertainty).toBe("Grain type");
    expect(parsed.items[0].assumptions).toContain("Grain type unclear");
    expect(parsed.items[0].uncertaintyReasons).toContain("Grain type unclear");
    expect(parsed.total.calorieRangeLower).toBeLessThanOrEqual(400);
    expect(parsed.total.calorieRangeUpper).toBeGreaterThanOrEqual(400);
  });

  it("fills clarification path for low-confidence image analysis during validation", () => {
    const result = validateMealImageAnalysisResponse({
      summary: "Unclear hawker plate",
      items: [{
        name: "Mixed hawker plate",
        calories: 650,
        protein: 20,
        carbs: 70,
        fat: 25,
        confidence: "low",
        assumptions: ["Standard plate"],
        uncertaintyReasons: [],
        suggestedClarifications: [],
        primaryUncertainty: null,
        calorieRangeLower: null,
        calorieRangeUpper: null,
      }],
      total: {
        calories: 650,
        protein: 20,
        carbs: 70,
        fat: 25,
        calorieRangeLower: null,
        calorieRangeUpper: null,
      },
      needsUserReview: true,
      clarifyingQuestion: null,
      primaryUncertainty: null,
    });

    expect(result.ok).toBe(true);
    const parsed = parseMealImageAnalysisResponse({
      summary: "Unclear hawker plate",
      items: [{
        name: "Mixed hawker plate",
        calories: 650,
        protein: 20,
        carbs: 70,
        fat: 25,
        confidence: "low",
        assumptions: ["Standard plate"],
        uncertaintyReasons: [],
        suggestedClarifications: [],
        primaryUncertainty: null,
        calorieRangeLower: null,
        calorieRangeUpper: null,
      }],
      total: {
        calories: 650,
        protein: 20,
        carbs: 70,
        fat: 25,
        calorieRangeLower: null,
        calorieRangeUpper: null,
      },
      needsUserReview: true,
      clarifyingQuestion: null,
      primaryUncertainty: null,
    });
    expect(parsed.items[0].suggestedClarifications.length).toBeGreaterThan(0);
    expect(parsed.items[0].uncertaintyReasons.length).toBeGreaterThan(0);
  });
});
