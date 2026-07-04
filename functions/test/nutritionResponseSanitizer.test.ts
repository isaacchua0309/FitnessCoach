import {
  sanitizeNutritionEstimateResponse,
  sanitizeNutritionPayload,
  sanitizeNutritionSuggestedActions,
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
});
