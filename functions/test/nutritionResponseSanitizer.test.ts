import {
  sanitizeNutritionEstimateResponse,
  sanitizeNutritionPayload,
  sanitizeNutritionSuggestedActions,
  sanitizeNutritionTrustFields,
} from "../src/nutritionResponseSanitizer";

describe("nutritionResponseSanitizer", () => {
  it("strips null and empty payload values", () => {
    expect(
      sanitizeNutritionPayload({
        foodName: "Big Mac",
        caloriesKcal: "550",
        proteinGrams: null,
        carbsGrams: null,
        fatGrams: null,
        leftFoodName: null,
        rightFoodName: null,
        query: null,
      })
    ).toEqual({
      foodName: "Big Mac",
      caloriesKcal: "550",
    });
  });

  it("drops literal null strings and whitespace-only values", () => {
    expect(
      sanitizeNutritionPayload({
        foodName: "  ",
        query: "null",
        caloriesKcal: " 480 ",
      })
    ).toEqual({
      caloriesKcal: "480",
    });
  });

  it("sanitizes suggested actions on estimate responses", () => {
    const sanitized = sanitizeNutritionEstimateResponse({
      type: "nutrition_estimate",
      foodName: "Big Mac",
      suggestedActions: [
        {
          id: "log",
          title: "Log Big Mac",
          type: "logMeal",
          payload: {
            foodName: "Big Mac",
            caloriesKcal: "550",
            proteinGrams: null,
            carbsGrams: null,
            fatGrams: null,
            leftFoodName: null,
            rightFoodName: null,
            query: null,
          },
        },
      ],
    });

    expect(sanitizeNutritionSuggestedActions).toBeDefined();
    expect(sanitized.suggestedActions).toEqual([
      {
        id: "log",
        title: "Log Big Mac",
        type: "logMeal",
        payload: {
          foodName: "Big Mac",
          caloriesKcal: "550",
        },
      },
    ]);
  });

  it("sanitizes trust metadata arrays and primary uncertainty", () => {
    const sanitized = sanitizeNutritionTrustFields({
      assumptions: [" Regular portion ", "Regular portion", ""],
      uncertaintyReasons: ["Hidden sauce", "null"],
      suggestedClarifications: ["  Was this a large bowl?  "],
      primaryUncertainty: "  Portion size ",
      requiresClarificationBeforeLogging: true,
      caveats: ["Values may vary"],
    });

    expect(sanitized.assumptions).toEqual(["Regular portion"]);
    expect(sanitized.uncertaintyReasons).toEqual(["Hidden sauce"]);
    expect(sanitized.suggestedClarifications).toEqual(["Was this a large bowl?"]);
    expect(sanitized.primaryUncertainty).toBe("Portion size");
    expect(sanitized.requiresClarificationBeforeLogging).toBe(true);
  });
});
