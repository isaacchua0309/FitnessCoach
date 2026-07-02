import {
  type FoodExtractionResponse,
} from "../src/foodEstimateExtraction";

export interface FoodLoggingGoldenExpectations {
  listedIngredientCount: number;
  minComponents?: number;
  exactComponents?: number;
  caloriesMin?: number;
  caloriesMax?: number;
  proteinMin?: number;
  proteinMax?: number;
  fatMin?: number;
  forbiddenCalories?: number[];
  noMealLevelQuantity?: boolean;
  maxConfidence?: "low" | "medium" | "high";
  requiresSauceComponent?: boolean;
  requiresPortionWarning?: boolean;
  singleComponent?: boolean;
  preparationState?: string;
  maxCarbs?: number;
}

export interface FoodLoggingGoldenCase {
  id: string;
  prompt: string;
  validExtraction: FoodExtractionResponse;
  collapsedExtraction?: FoodExtractionResponse;
  expectations: FoodLoggingGoldenExpectations;
}

const case1Prompt = `log this bowl:
150g cooked chicken breast
150g cooked barley rice
1 tbsp creamy sesame/mayo dressing
50-60g tiramisu`;

const case1ValidExtraction: FoodExtractionResponse = {
  meals: [{
    meal_name: "bowl with chicken breast, barley rice mix, dressing, tiramisu",
    meal_type: "lunch",
    components: [
      {
        name: "cooked chicken breast",
        quantity: 150,
        unit: "g",
        state: "cooked",
        calories: 248,
        protein_g: 44,
        carbs_g: 0,
        fat_g: 5.4,
        confidence: "high",
        source_text: "150g cooked chicken breast",
      },
      {
        name: "cooked barley rice",
        quantity: 150,
        unit: "g",
        state: "cooked",
        calories: 165,
        protein_g: 4.5,
        carbs_g: 36,
        fat_g: 1.1,
        confidence: "high",
        source_text: "150g cooked barley rice",
      },
      {
        name: "creamy sesame/mayo dressing",
        quantity: 1,
        unit: "tbsp",
        state: "unknown",
        calories: 95,
        protein_g: 0.5,
        carbs_g: 2,
        fat_g: 8,
        confidence: "medium",
        source_text: "1 tbsp creamy sesame/mayo dressing",
      },
      {
        name: "tiramisu",
        quantity: 55,
        unit: "g",
        state: "unknown",
        calories: 162,
        protein_g: 3,
        carbs_g: 22,
        fat_g: 7.9,
        confidence: "medium",
        source_text: "50-60g tiramisu",
      },
    ],
    totals: {
      calories: 670,
      protein_g: 52,
      carbs_g: 60,
      fat_g: 22.4,
    },
    confidence: "high",
    assumptions: [],
    warnings: [],
  }],
  requiresConfirmation: true,
  assistantMessage: "Estimated per ingredient.",
};

const case1CollapsedExtraction: FoodExtractionResponse = {
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

const case2Prompt = "100g chicken breast and one bowl of rice";

const case2ValidExtraction: FoodExtractionResponse = {
  meals: [{
    meal_name: "Chicken breast with rice",
    meal_type: null,
    components: [
      {
        name: "cooked chicken breast",
        quantity: 100,
        unit: "g",
        state: "cooked",
        calories: 165,
        protein_g: 31,
        carbs_g: 0,
        fat_g: 3.6,
        confidence: "high",
        source_text: "100g chicken breast",
      },
      {
        name: "cooked rice",
        quantity: 200,
        unit: "g",
        state: "cooked",
        calories: 260,
        protein_g: 5,
        carbs_g: 56,
        fat_g: 0.5,
        confidence: "medium",
        source_text: "one bowl of rice",
      },
    ],
    totals: {
      calories: 425,
      protein_g: 36,
      carbs_g: 56,
      fat_g: 4.1,
    },
    confidence: "medium",
    assumptions: ["Assumed one bowl of cooked rice is about 200g."],
    warnings: [],
  }],
  requiresConfirmation: true,
  assistantMessage: null,
};

const case3Prompt = "one chicken breast, one bowl rice, sauce";

const case3ValidExtraction: FoodExtractionResponse = {
  meals: [{
    meal_name: "Chicken breast with rice and sauce",
    meal_type: null,
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
        confidence: "low",
        source_text: "one chicken breast",
      },
      {
        name: "rice",
        quantity: 200,
        unit: "g",
        state: "cooked",
        calories: 260,
        protein_g: 5,
        carbs_g: 56,
        fat_g: 0.5,
        confidence: "low",
        source_text: "one bowl rice",
      },
      {
        name: "sauce",
        quantity: 1,
        unit: "tbsp",
        state: "unknown",
        calories: 45,
        protein_g: 0,
        carbs_g: 2,
        fat_g: 4,
        confidence: "low",
        source_text: "sauce",
      },
    ],
    totals: {
      calories: 553,
      protein_g: 51,
      carbs_g: 58,
      fat_g: 9.5,
    },
    confidence: "medium",
    assumptions: [
      "Estimated one chicken breast at 150g cooked.",
      "Estimated one bowl of rice at 200g cooked.",
      "Estimated one tablespoon of sauce.",
    ],
    warnings: ["Portions were estimated from vague descriptions."],
  }],
  requiresConfirmation: true,
  assistantMessage: "Portions are approximate — please review before logging.",
};

const case4Prompt = "150g cooked chicken breast";

const case4ValidExtraction: FoodExtractionResponse = {
  meals: [{
    meal_name: "Cooked chicken breast",
    meal_type: null,
    components: [{
      name: "cooked chicken breast",
      quantity: 150,
      unit: "g",
      state: "cooked",
      calories: 248,
      protein_g: 46.5,
      carbs_g: 0,
      fat_g: 5.4,
      confidence: "high",
      source_text: "150g cooked chicken breast",
    }],
    totals: {
      calories: 248,
      protein_g: 46.5,
      carbs_g: 0,
      fat_g: 5.4,
    },
    confidence: "high",
    assumptions: [],
    warnings: [],
  }],
  requiresConfirmation: true,
  assistantMessage: null,
};

const case5Prompt = "barley rice 150g";

const case5ValidExtraction: FoodExtractionResponse = {
  meals: [{
    meal_name: "Cooked barley rice",
    meal_type: null,
    components: [{
      name: "cooked barley rice",
      quantity: 150,
      unit: "g",
      state: "cooked",
      calories: 180,
      protein_g: 4.5,
      carbs_g: 36,
      fat_g: 1.1,
      confidence: "high",
      source_text: "barley rice 150g",
    }],
    totals: {
      calories: 180,
      protein_g: 4.5,
      carbs_g: 36,
      fat_g: 1.1,
    },
    confidence: "high",
    assumptions: ["Interpreted as 150g cooked barley rice."],
    warnings: [],
  }],
  requiresConfirmation: true,
  assistantMessage: null,
};

export const foodLoggingGoldenCases: FoodLoggingGoldenCase[] = [
  {
    id: "case1_multi_component_bowl",
    prompt: case1Prompt,
    validExtraction: case1ValidExtraction,
    collapsedExtraction: case1CollapsedExtraction,
    expectations: {
      listedIngredientCount: 4,
      minComponents: 4,
      caloriesMin: 650,
      caloriesMax: 700,
      proteinMin: 45,
      proteinMax: 60,
      fatMin: 18,
      forbiddenCalories: [430],
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case2_chicken_and_rice",
    prompt: case2Prompt,
    validExtraction: case2ValidExtraction,
    expectations: {
      listedIngredientCount: 2,
      exactComponents: 2,
      caloriesMin: 300,
      caloriesMax: 500,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case3_vague_portions_with_sauce",
    prompt: case3Prompt,
    validExtraction: case3ValidExtraction,
    expectations: {
      listedIngredientCount: 3,
      exactComponents: 3,
      maxConfidence: "medium",
      requiresSauceComponent: true,
      requiresPortionWarning: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case4_single_chicken_breast",
    prompt: case4Prompt,
    validExtraction: case4ValidExtraction,
    expectations: {
      listedIngredientCount: 1,
      exactComponents: 1,
      singleComponent: true,
      caloriesMin: 240,
      caloriesMax: 260,
      proteinMin: 45,
      proteinMax: 48,
      preparationState: "cooked",
    },
  },
  {
    id: "case5_cooked_barley_rice",
    prompt: case5Prompt,
    validExtraction: case5ValidExtraction,
    expectations: {
      listedIngredientCount: 1,
      exactComponents: 1,
      singleComponent: true,
      caloriesMin: 170,
      caloriesMax: 200,
      preparationState: "cooked",
      maxCarbs: 45,
    },
  },
];
