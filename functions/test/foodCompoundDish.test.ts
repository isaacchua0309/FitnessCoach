import {
  analyzeCompoundFoodPrompt,
  isKnownCompoundDish,
  matchCompoundDishes,
} from "../src/foodCompoundDish";
import {
  normalizeFoodExtraction,
  validateFoodExtraction,
  type FoodExtractionResponse,
} from "../src/foodEstimateExtraction";

describe("foodCompoundDish", () => {
  it("detects chicken rice as compound dish requiring decomposition", () => {
    const analysis = analyzeCompoundFoodPrompt("log chicken rice");
    expect(isKnownCompoundDish("log chicken rice")).toBe(true);
    expect(analysis.minRequiredComponents).toBeGreaterThanOrEqual(3);
    expect(analysis.requiresAssumptions).toBe(true);
  });

  it("detects cai fan with two named dishes", () => {
    const analysis = analyzeCompoundFoodPrompt(
      "log cai fan with sweet sour pork and broccoli"
    );
    expect(matchCompoundDishes("log cai fan with sweet sour pork and broccoli")).toHaveLength(1);
    expect(analysis.minRequiredComponents).toBe(3);
  });

  it("treats protein shake as simple food", () => {
    expect(isKnownCompoundDish("log protein shake")).toBe(false);
  });

  it("flags ambiguous rice bowl", () => {
    const analysis = analyzeCompoundFoodPrompt("rice bowl");
    expect(analysis.isAmbiguousServing).toBe(true);
    expect(analysis.requiresAssumptions).toBe(true);
  });

  it("flags same as breakfast context reference", () => {
    const analysis = analyzeCompoundFoodPrompt("same as breakfast");
    expect(analysis.isContextReference).toBe(true);
    expect(analysis.requiresAssumptions).toBe(true);
  });
});

describe("compound food validation", () => {
  it("rejects collapsed chicken rice", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "chicken rice",
        meal_type: null,
        components: [{
          name: "chicken rice",
          quantity: 1,
          unit: "plate",
          state: "cooked",
          calories: 430,
          protein_g: 28,
          carbs_g: 52,
          fat_g: 10,
          confidence: "medium",
          source_text: "log chicken rice",
        }],
        totals: {
          calories: 430,
          protein_g: 28,
          carbs_g: 52,
          fat_g: 10,
        },
        confidence: "medium",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: null,
    };

    const result = validateFoodExtraction(extraction, "log chicken rice");
    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("compound dish"))).toBe(true);
  });

  it("rejects negative macros", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "Eggs",
        meal_type: null,
        components: [{
          name: "eggs",
          quantity: 2,
          unit: "count",
          state: "unknown",
          calories: 140,
          protein_g: -2,
          carbs_g: 1,
          fat_g: 10,
          confidence: "high",
          source_text: "2 eggs",
        }],
        totals: {
          calories: 140,
          protein_g: -2,
          carbs_g: 1,
          fat_g: 10,
        },
        confidence: "high",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: null,
    };

    const result = validateFoodExtraction(extraction, "2 eggs");
    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("negative protein"))).toBe(true);
  });

  it("normalizes totals from component sums", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "Rice and chicken",
        meal_type: null,
        components: [
          {
            name: "rice",
            quantity: 150,
            unit: "g",
            state: "cooked",
            calories: 195,
            protein_g: 4,
            carbs_g: 42,
            fat_g: 0.5,
            confidence: "medium",
            source_text: "rice",
          },
          {
            name: "chicken",
            quantity: 120,
            unit: "g",
            state: "cooked",
            calories: 198,
            protein_g: 37,
            carbs_g: 0,
            fat_g: 4.5,
            confidence: "medium",
            source_text: "chicken",
          },
        ],
        totals: {
          calories: 300,
          protein_g: 41,
          carbs_g: 42,
          fat_g: 5,
        },
        confidence: "high",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: null,
    };

    const normalized = normalizeFoodExtraction(extraction, "small bowl rice and chicken breast");
    expect(normalized.meals[0].totals.calories).toBe(393);
  });
});
