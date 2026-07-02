import {
  countListedIngredients,
  mapExtractionToGatewayPayload,
  validateFoodExtraction,
  type FoodExtractionResponse,
} from "../src/foodEstimateExtraction";

const bowlPrompt = `log this bowl:
- 150 g cooked skinless chicken breast
- 150 g cooked barley rice
- 1 tbsp creamy sesame/mayo dressing
- 50-60 g tiramisu`;

describe("foodEstimateExtraction", () => {
  it("counts listed ingredients from bullet lines", () => {
    expect(countListedIngredients(bowlPrompt)).toBe(4);
  });

  it("rejects collapsed single-component meal for multi-ingredient prompt", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "bowl",
        meal_type: null,
        components: [{
          name: "bowl with chicken and rice",
          quantity: 150,
          unit: "g",
          state: "cooked",
          calories: 430,
          protein_g: 38,
          carbs_g: 42,
          fat_g: 9,
          confidence: "medium",
          source_text: "log this bowl",
        }],
        totals: {
          calories: 430,
          protein_g: 38,
          carbs_g: 42,
          fat_g: 9,
        },
        confidence: "medium",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: null,
    };

    const result = validateFoodExtraction(extraction, bowlPrompt);
    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("collapsed"))).toBe(true);
  });

  it("rejects totals that do not match component sums", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "Chicken barley bowl",
        meal_type: null,
        components: [
          {
            name: "chicken",
            quantity: 150,
            unit: "g",
            state: "cooked",
            calories: 248,
            protein_g: 46,
            carbs_g: 0,
            fat_g: 5,
            confidence: "high",
            source_text: "150 g cooked chicken",
          },
          {
            name: "rice",
            quantity: 150,
            unit: "g",
            state: "cooked",
            calories: 165,
            protein_g: 4,
            carbs_g: 34,
            fat_g: 1,
            confidence: "high",
            source_text: "150 g cooked rice",
          },
        ],
        totals: {
          calories: 300,
          protein_g: 50,
          carbs_g: 34,
          fat_g: 6,
        },
        confidence: "high",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: null,
    };

    const result = validateFoodExtraction(extraction, bowlPrompt);
    expect(result.ok).toBe(false);
    expect(result.errors.some((error) => error.includes("total calories"))).toBe(true);
  });

  it("maps valid extraction to gateway payload without meal-level quantity", () => {
    const extraction: FoodExtractionResponse = {
      meals: [{
        meal_name: "Chicken barley bowl",
        meal_type: "lunch",
        components: [
          {
            name: "chicken breast",
            quantity: 150,
            unit: "g",
            state: "cooked",
            calories: 248,
            protein_g: 46,
            carbs_g: 0,
            fat_g: 5,
            confidence: "high",
            source_text: "150 g cooked chicken breast",
          },
          {
            name: "barley rice",
            quantity: 150,
            unit: "g",
            state: "cooked",
            calories: 165,
            protein_g: 4,
            carbs_g: 34,
            fat_g: 1,
            confidence: "high",
            source_text: "150 g cooked barley rice",
          },
        ],
        totals: {
          calories: 413,
          protein_g: 50,
          carbs_g: 34,
          fat_g: 6,
        },
        confidence: "high",
        assumptions: [],
        warnings: [],
      }],
      requiresConfirmation: true,
      assistantMessage: "Estimated per ingredient.",
    };

    const validation = validateFoodExtraction(extraction, bowlPrompt);
    expect(validation.ok).toBe(true);

    const payload = mapExtractionToGatewayPayload(extraction, "aiTextEstimate", validation);
    expect(payload.foodLogDrafts).toHaveLength(1);
    expect(payload.foodLogDrafts[0].components).toHaveLength(2);
    expect(payload.foodDrafts[0].quantity).toBeNull();
    expect(payload.foodDrafts[0].calories).toBe(413);
  });
});
