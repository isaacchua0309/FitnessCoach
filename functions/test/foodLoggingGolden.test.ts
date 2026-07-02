import {
  countListedIngredients,
  mapExtractionToGatewayPayload,
  validateFoodExtraction,
} from "../src/foodEstimateExtraction";
import {foodLoggingGoldenCases} from "./fixtures/foodLoggingGoldenCases";

describe("foodLoggingGoldenCases", () => {
  describe.each(foodLoggingGoldenCases)("$id parser", ({prompt, expectations}) => {
    it("counts listed ingredients in the prompt", () => {
      expect(countListedIngredients(prompt)).toBe(expectations.listedIngredientCount);
    });
  });

  describe.each(foodLoggingGoldenCases)("$id validator + mapping", ({
    id,
    prompt,
    validExtraction,
    collapsedExtraction,
    expectations,
  }) => {
    it("accepts the golden extraction and maps a usable gateway payload", () => {
      const validation = validateFoodExtraction(validExtraction, prompt);
      expect(validation.ok).toBe(true);

      const payload = mapExtractionToGatewayPayload(
        validExtraction,
        "aiTextEstimate",
        validation
      );
      const meal = payload.foodLogDrafts[0];
      const legacy = payload.foodDrafts[0];

      if (expectations.minComponents != null) {
        expect(meal.components.length).toBeGreaterThanOrEqual(expectations.minComponents);
      }
      if (expectations.exactComponents != null) {
        expect(meal.components.length).toBe(expectations.exactComponents);
      }
      if (expectations.singleComponent) {
        expect(meal.components.length).toBe(1);
      }

      const calories = legacy.calories;
      if (expectations.caloriesMin != null) {
        expect(calories).toBeGreaterThanOrEqual(expectations.caloriesMin);
      }
      if (expectations.caloriesMax != null) {
        expect(calories).toBeLessThanOrEqual(expectations.caloriesMax);
      }
      if (expectations.proteinMin != null) {
        expect(legacy.protein).toBeGreaterThanOrEqual(expectations.proteinMin);
      }
      if (expectations.proteinMax != null) {
        expect(legacy.protein).toBeLessThanOrEqual(expectations.proteinMax);
      }
      if (expectations.fatMin != null) {
        expect(legacy.fat).toBeGreaterThanOrEqual(expectations.fatMin);
      }
      if (expectations.forbiddenCalories != null) {
        for (const forbidden of expectations.forbiddenCalories) {
          expect(calories).not.toBe(forbidden);
        }
        if (expectations.caloriesMin != null) {
          expect(calories).toBeGreaterThanOrEqual(expectations.caloriesMin);
        }
      }
      if (expectations.maxCarbs != null) {
        expect(legacy.carbs).toBeLessThanOrEqual(expectations.maxCarbs);
      }
      if (expectations.noMealLevelQuantity) {
        expect(legacy.quantity).toBeNull();
        expect(legacy.unit).toBeNull();
      }
      if (expectations.preparationState != null) {
        expect(meal.components[0].preparationState).toBe(expectations.preparationState);
      }
      if (expectations.requiresSauceComponent) {
        expect(
          meal.components.some((component) => /sauce/i.test(component.name))
        ).toBe(true);
      }
      if (expectations.requiresPortionWarning) {
        const warningText = meal.warnings.join(" ").toLowerCase();
        expect(
          warningText.includes("vague") ||
          warningText.includes("assumption") ||
          warningText.includes("approximate") ||
          warningText.includes("estimated")
        ).toBe(true);
      }
      if (expectations.maxConfidence != null) {
        const rank = {low: 0, medium: 1, high: 2};
        expect(rank[payload.confidence]).toBeLessThanOrEqual(rank[expectations.maxConfidence]);
      }
    });

    if (collapsedExtraction) {
      it("rejects collapsed bad extraction for case1", () => {
        expect(id).toBe("case1_multi_component_bowl");
        const validation = validateFoodExtraction(collapsedExtraction, prompt);
        expect(validation.ok).toBe(false);
        expect(validation.errors.some((error) => error.includes("collapsed"))).toBe(true);

        const payload = mapExtractionToGatewayPayload(
          collapsedExtraction,
          "aiTextEstimate",
          validation
        );
        expect(payload.foodLogDrafts[0].components.length).toBe(1);
        expect(payload.foodDrafts[0].calories).toBe(430);
        expect(payload.confidence).toBe("low");
      });
    }
  });
});
