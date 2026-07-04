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
  requiresAssumptions?: boolean;
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

function sumMealTotals(components: FoodExtractionResponse["meals"][0]["components"]) {
  return components.reduce(
    (acc, component) => ({
      calories: acc.calories + component.calories,
      protein_g: acc.protein_g + component.protein_g,
      carbs_g: acc.carbs_g + component.carbs_g,
      fat_g: acc.fat_g + component.fat_g,
    }),
    {calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0}
  );
}

function makeCompoundMeal(
  mealName: string,
  components: FoodExtractionResponse["meals"][0]["components"],
  confidence: "low" | "medium" | "high",
  assumptions: string[],
  warnings: string[] = []
): FoodExtractionResponse {
  return {
    meals: [{
      meal_name: mealName,
      meal_type: "lunch",
      components,
      totals: sumMealTotals(components),
      confidence,
      assumptions,
      warnings,
    }],
    requiresConfirmation: true,
    assistantMessage: null,
  };
}

const case6Prompt = "log chicken rice";
const case6Components = [
  {
    name: "fragrant rice",
    quantity: 200,
    unit: "g",
    state: "cooked" as const,
    calories: 260,
    protein_g: 5,
    carbs_g: 56,
    fat_g: 1,
    confidence: "medium" as const,
    source_text: "chicken rice rice portion",
  },
  {
    name: "poached chicken",
    quantity: 120,
    unit: "g",
    state: "cooked" as const,
    calories: 198,
    protein_g: 37,
    carbs_g: 0,
    fat_g: 4.5,
    confidence: "medium" as const,
    source_text: "chicken rice chicken portion",
  },
  {
    name: "chili sauce and chicken oil",
    quantity: 1,
    unit: "tbsp",
    state: "unknown" as const,
    calories: 70,
    protein_g: 0,
    carbs_g: 2,
    fat_g: 7,
    confidence: "low" as const,
    source_text: "chicken rice sauce/oil",
  },
];
const case6ValidExtraction = makeCompoundMeal(
  "Hainanese chicken rice",
  case6Components,
  "medium",
  [
    "Assumed standard plate with ~200g cooked rice and ~120g chicken.",
    "Included ~1 tbsp chili sauce and chicken oil.",
    "Medium confidence because exact stall portion is unknown.",
    "User can clarify white/dark meat, extra skin, or larger rice portion.",
  ],
  ["Portions estimated from typical chicken rice plate."]
);
const case6CollapsedExtraction = makeCompoundMeal(
  "chicken rice",
  [{
    name: "chicken rice",
    quantity: 1,
    unit: "plate",
    state: "cooked" as const,
    calories: 430,
    protein_g: 28,
    carbs_g: 52,
    fat_g: 10,
    confidence: "medium" as const,
    source_text: "log chicken rice",
  }],
  "medium",
  []
);

const case7Prompt = "log nasi lemak";
const case7ValidExtraction = makeCompoundMeal(
  "Nasi lemak",
  [
    {
      name: "coconut rice",
      quantity: 200,
      unit: "g",
      state: "cooked" as const,
      calories: 330,
      protein_g: 6,
      carbs_g: 58,
      fat_g: 8,
      confidence: "medium" as const,
      source_text: "nasi lemak coconut rice",
    },
    {
      name: "fried egg",
      quantity: 1,
      unit: "piece",
      state: "cooked" as const,
      calories: 90,
      protein_g: 6,
      carbs_g: 0,
      fat_g: 7,
      confidence: "medium" as const,
      source_text: "nasi lemak egg",
    },
    {
      name: "sambal",
      quantity: 1,
      unit: "tbsp",
      state: "unknown" as const,
      calories: 25,
      protein_g: 0,
      carbs_g: 3,
      fat_g: 1.5,
      confidence: "low" as const,
      source_text: "nasi lemak sambal",
    },
    {
      name: "ikan bilis and peanuts",
      quantity: 15,
      unit: "g",
      state: "cooked" as const,
      calories: 85,
      protein_g: 4,
      carbs_g: 3,
      fat_g: 6,
      confidence: "low" as const,
      source_text: "nasi lemak ikan bilis/peanuts",
    },
  ],
  "medium",
  [
    "Assumed standard packet/set with ~200g coconut rice.",
    "Included typical sambal, egg, and ikan bilis/peanuts.",
    "Medium confidence without stated add-ons like wing or otah.",
    "User can clarify protein add-on or larger rice portion.",
  ]
);

const case8Prompt = "log cai fan with sweet sour pork and broccoli";
const case8ValidExtraction = makeCompoundMeal(
  "Cai fan with sweet sour pork and broccoli",
  [
    {
      name: "steamed rice",
      quantity: 180,
      unit: "g",
      state: "cooked" as const,
      calories: 234,
      protein_g: 4.5,
      carbs_g: 50,
      fat_g: 0.5,
      confidence: "medium" as const,
      source_text: "cai fan rice",
    },
    {
      name: "sweet sour pork",
      quantity: 120,
      unit: "g",
      state: "cooked" as const,
      calories: 220,
      protein_g: 14,
      carbs_g: 18,
      fat_g: 10,
      confidence: "medium" as const,
      source_text: "sweet sour pork",
    },
    {
      name: "broccoli",
      quantity: 80,
      unit: "g",
      state: "cooked" as const,
      calories: 35,
      protein_g: 2,
      carbs_g: 5,
      fat_g: 1,
      confidence: "medium" as const,
      source_text: "broccoli",
    },
  ],
  "medium",
  [
    "Assumed 2 dishes plus standard rice scoop.",
    "Included stir-fry oil in pork estimate.",
    "Medium confidence because exact scoop size varies.",
    "User can clarify rice amount or extra gravy.",
  ]
);

const case9Prompt = "log mala bowl with beef and vegetables";
const case9ValidExtraction = makeCompoundMeal(
  "Mala bowl with beef and vegetables",
  [
    {
      name: "mala noodles",
      quantity: 180,
      unit: "g",
      state: "cooked" as const,
      calories: 250,
      protein_g: 7,
      carbs_g: 42,
      fat_g: 5,
      confidence: "medium" as const,
      source_text: "mala noodles base",
    },
    {
      name: "beef slices",
      quantity: 100,
      unit: "g",
      state: "cooked" as const,
      calories: 190,
      protein_g: 22,
      carbs_g: 0,
      fat_g: 11,
      confidence: "medium" as const,
      source_text: "mala beef",
    },
    {
      name: "mixed vegetables",
      quantity: 120,
      unit: "g",
      state: "cooked" as const,
      calories: 45,
      protein_g: 2,
      carbs_g: 7,
      fat_g: 1,
      confidence: "medium" as const,
      source_text: "mala vegetables",
    },
    {
      name: "mala oil and sauce",
      quantity: 2,
      unit: "tbsp",
      state: "unknown" as const,
      calories: 180,
      protein_g: 0,
      carbs_g: 2,
      fat_g: 19,
      confidence: "low" as const,
      source_text: "mala oil/sauce",
    },
  ],
  "medium",
  [
    "Assumed medium bowl with noodles, beef, and veg.",
    "Included ~2 tbsp mala oil/sauce.",
    "Medium confidence because spice/oil level varies.",
    "User can clarify soup vs dry, rice instead of noodles, or portion size.",
  ]
);

const case10Prompt = "log ban mian";
const case10ValidExtraction = makeCompoundMeal(
  "Ban mian",
  [
    {
      name: "hand-pulled noodles",
      quantity: 220,
      unit: "g",
      state: "cooked" as const,
      calories: 310,
      protein_g: 10,
      carbs_g: 58,
      fat_g: 3,
      confidence: "medium" as const,
      source_text: "ban mian noodles",
    },
    {
      name: "minced meat, egg, and broth",
      quantity: 1,
      unit: "bowl",
      state: "cooked" as const,
      calories: 180,
      protein_g: 12,
      carbs_g: 2,
      fat_g: 12,
      confidence: "medium" as const,
      source_text: "ban mian toppings and broth",
    },
  ],
  "medium",
  [
    "Assumed standard bowl with noodles, egg, minced meat, and broth.",
    "Included cooking oil in topping estimate.",
    "Medium confidence without stated dry/soup preference.",
    "User can clarify extra egg, ikan bilis, or larger bowl.",
  ]
);

const case11Prompt = "log yong tau foo soup with tofu and fishball";
const case11ValidExtraction = makeCompoundMeal(
  "Yong tau foo soup",
  [
    {
      name: "selected yong tau foo items",
      quantity: 180,
      unit: "g",
      state: "cooked" as const,
      calories: 210,
      protein_g: 14,
      carbs_g: 12,
      fat_g: 10,
      confidence: "medium" as const,
      source_text: "tofu and fishball items",
    },
    {
      name: "clear soup base",
      quantity: 1,
      unit: "bowl",
      state: "cooked" as const,
      calories: 35,
      protein_g: 2,
      carbs_g: 2,
      fat_g: 2,
      confidence: "low" as const,
      source_text: "yong tau foo soup",
    },
  ],
  "medium",
  [
    "Assumed soup version with tofu and fishball pieces.",
    "Included light soup oil estimate.",
    "Medium confidence because item count/weight varies.",
    "User can clarify extra items, noodles, or dry version.",
  ]
);

const case12Prompt = "log prata with curry";
const case12ValidExtraction = makeCompoundMeal(
  "Prata with curry",
  [
    {
      name: "plain prata",
      quantity: 1,
      unit: "piece",
      state: "cooked" as const,
      calories: 210,
      protein_g: 5,
      carbs_g: 28,
      fat_g: 9,
      confidence: "medium" as const,
      source_text: "prata",
    },
    {
      name: "curry dip",
      quantity: 0.5,
      unit: "cup",
      state: "unknown" as const,
      calories: 90,
      protein_g: 2,
      carbs_g: 6,
      fat_g: 6,
      confidence: "low" as const,
      source_text: "curry",
    },
  ],
  "medium",
  [
    "Assumed one plain prata with half cup curry.",
    "Included prata frying oil and curry coconut fat.",
    "Medium confidence because prata size varies.",
    "User can clarify kosong, egg, or extra prata.",
  ]
);

const case13Prompt = "log bubble tea with pearls";
const case13ValidExtraction = makeCompoundMeal(
  "Bubble tea with pearls",
  [
    {
      name: "milk tea base",
      quantity: 500,
      unit: "ml",
      state: "unknown" as const,
      calories: 220,
      protein_g: 4,
      carbs_g: 34,
      fat_g: 7,
      confidence: "medium" as const,
      source_text: "bubble tea drink base",
    },
    {
      name: "tapioca pearls",
      quantity: 50,
      unit: "g",
      state: "cooked" as const,
      calories: 80,
      protein_g: 0,
      carbs_g: 20,
      fat_g: 0,
      confidence: "medium" as const,
      source_text: "pearls",
    },
  ],
  "medium",
  [
    "Assumed regular 500ml with normal sweetness and full pearls.",
    "Included milk and sugar in drink estimate.",
    "Medium confidence because sugar level and ice affect calories.",
    "User can clarify size, sugar level, or less pearls.",
  ]
);

const case14Prompt = "log protein shake";
const case14ValidExtraction = makeCompoundMeal(
  "Protein shake",
  [{
    name: "protein shake",
    quantity: 350,
    unit: "ml",
    state: "unknown" as const,
    calories: 180,
    protein_g: 30,
    carbs_g: 6,
    fat_g: 3,
    confidence: "medium" as const,
    source_text: "protein shake",
  }],
  "medium",
  [
    "Assumed one scoop whey with water or low-fat milk.",
    "No added nut butter unless stated.",
    "Medium confidence without brand or mix-ins.",
    "User can clarify brand, milk type, or added fruit/peanut butter.",
  ]
);

const case15Prompt = "small bowl rice and chicken breast";
const case15ValidExtraction = makeCompoundMeal(
  "Small bowl rice and chicken breast",
  [
    {
      name: "cooked rice",
      quantity: 150,
      unit: "g",
      state: "cooked" as const,
      calories: 195,
      protein_g: 4,
      carbs_g: 42,
      fat_g: 0.5,
      confidence: "medium" as const,
      source_text: "small bowl rice",
    },
    {
      name: "chicken breast",
      quantity: 120,
      unit: "g",
      state: "cooked" as const,
      calories: 198,
      protein_g: 37,
      carbs_g: 0,
      fat_g: 4.5,
      confidence: "medium" as const,
      source_text: "chicken breast",
    },
  ],
  "medium",
  [
    "Assumed small rice bowl ~150g cooked rice.",
    "Assumed ~120g cooked chicken breast without heavy sauce.",
    "Medium confidence because small bowl size varies.",
    "User can clarify grams or skin/sauce.",
  ]
);

const case16Prompt = "same as breakfast";
const case16ValidExtraction = makeCompoundMeal(
  "Same as breakfast",
  [
    {
      name: "oats with banana",
      quantity: 1,
      unit: "bowl",
      state: "cooked" as const,
      calories: 280,
      protein_g: 10,
      carbs_g: 48,
      fat_g: 6,
      confidence: "medium" as const,
      source_text: "same as breakfast from commonFoods",
    },
    {
      name: "black coffee",
      quantity: 250,
      unit: "ml",
      state: "unknown" as const,
      calories: 5,
      protein_g: 0,
      carbs_g: 0,
      fat_g: 0,
      confidence: "medium" as const,
      source_text: "same as breakfast coffee",
    },
  ],
  "medium",
  [
    "Matched prior confirmed breakfast from context.commonFoods.",
    "No extra cooking oil assumed beyond logged breakfast.",
    "Medium confidence because context match may be stale.",
    "User can clarify if breakfast differed today.",
  ]
);

const case17Prompt = "rice bowl";
const case17ValidExtraction = makeCompoundMeal(
  "Rice bowl",
  [
    {
      name: "cooked rice",
      quantity: 200,
      unit: "g",
      state: "cooked" as const,
      calories: 260,
      protein_g: 5,
      carbs_g: 56,
      fat_g: 0.5,
      confidence: "low" as const,
      source_text: "rice bowl",
    },
    {
      name: "cooking oil or topping allowance",
      quantity: 1,
      unit: "tsp",
      state: "unknown" as const,
      calories: 40,
      protein_g: 0,
      carbs_g: 0,
      fat_g: 4.5,
      confidence: "low" as const,
      source_text: "possible topping/oil",
    },
  ],
  "low",
  [
    "Assumed plain medium rice bowl ~200g without stated topping.",
    "Included small oil/topping allowance because bowl type is unclear.",
    "Low confidence because protein/toppings were not specified.",
    "User can clarify topping, protein, or smaller/larger bowl.",
  ],
  ["Serving size is ambiguous."]
);

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
      requiresAssumptions: true,
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
      requiresAssumptions: true,
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
  {
    id: "case6_chicken_rice",
    prompt: case6Prompt,
    validExtraction: case6ValidExtraction,
    collapsedExtraction: case6CollapsedExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 3,
      caloriesMin: 450,
      caloriesMax: 650,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case7_nasi_lemak",
    prompt: case7Prompt,
    validExtraction: case7ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 4,
      caloriesMin: 450,
      caloriesMax: 650,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case8_cai_fan_two_dishes",
    prompt: case8Prompt,
    validExtraction: case8ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 3,
      caloriesMin: 400,
      caloriesMax: 650,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case9_mala_bowl",
    prompt: case9Prompt,
    validExtraction: case9ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 3,
      caloriesMin: 550,
      caloriesMax: 850,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case10_ban_mian",
    prompt: case10Prompt,
    validExtraction: case10ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 2,
      caloriesMin: 400,
      caloriesMax: 650,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case11_yong_tau_foo_soup",
    prompt: case11Prompt,
    validExtraction: case11ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 2,
      caloriesMin: 200,
      caloriesMax: 400,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case12_prata_with_curry",
    prompt: case12Prompt,
    validExtraction: case12ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      exactComponents: 2,
      caloriesMin: 250,
      caloriesMax: 400,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case13_bubble_tea_pearls",
    prompt: case13Prompt,
    validExtraction: case13ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 2,
      caloriesMin: 250,
      caloriesMax: 450,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case14_protein_shake",
    prompt: case14Prompt,
    validExtraction: case14ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      singleComponent: true,
      exactComponents: 1,
      caloriesMin: 120,
      caloriesMax: 350,
    },
  },
  {
    id: "case15_small_bowl_rice_chicken",
    prompt: case15Prompt,
    validExtraction: case15ValidExtraction,
    expectations: {
      listedIngredientCount: 2,
      exactComponents: 2,
      caloriesMin: 350,
      caloriesMax: 500,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case16_same_as_breakfast",
    prompt: case16Prompt,
    validExtraction: case16ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 1,
      caloriesMin: 200,
      caloriesMax: 500,
      maxConfidence: "medium",
      requiresAssumptions: true,
      noMealLevelQuantity: true,
    },
  },
  {
    id: "case17_ambiguous_rice_bowl",
    prompt: case17Prompt,
    validExtraction: case17ValidExtraction,
    expectations: {
      listedIngredientCount: 0,
      minComponents: 1,
      caloriesMin: 250,
      caloriesMax: 450,
      maxConfidence: "low",
      requiresAssumptions: true,
      requiresPortionWarning: true,
      noMealLevelQuantity: true,
    },
  },
];
