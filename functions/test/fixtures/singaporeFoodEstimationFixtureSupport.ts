import * as fs from "fs";
import * as path from "path";
import {deriveCalorieRange} from "../../src/foodCalorieRange";
import {
  type FoodExtractionResponse,
  normalizeFoodExtraction,
  validateFoodExtraction,
} from "../../src/foodEstimateExtraction";
import {analyzeCompoundFoodPrompt} from "../../src/foodCompoundDish";

export type MacroRange = [number, number];
export type ConfidenceLevel = "low" | "medium" | "high";
export type ConfidenceMode = "max" | "exact";

export interface SingaporeFoodEstimationCase {
  id: string;
  inputText: string;
  expectedComponents: string[];
  expectedCaloriesRange: MacroRange;
  expectedProteinRange: MacroRange;
  expectedCarbsRange: MacroRange;
  expectedFatRange: MacroRange;
  expectedConfidence: ConfidenceLevel;
  expectedConfidenceMode?: ConfidenceMode;
  expectedAssumptions: string[];
  shouldRequireConfirmation: boolean;
  notes: string;
}

export interface SingaporeFoodEstimationFixtureFile {
  version: number;
  description: string;
  caseCount: number;
  cases: SingaporeFoodEstimationCase[];
}

export interface FixtureValidationResult {
  ok: boolean;
  errors: string[];
}

const CONFIDENCE_RANK: Record<ConfidenceLevel, number> = {
  low: 0,
  medium: 1,
  high: 2,
};

const FIXTURE_PATH = path.resolve(
  __dirname,
  "../../../Docs/Coach/Fixtures/singapore_food_estimation_cases.json"
);

export function loadSingaporeFoodEstimationFixture(): SingaporeFoodEstimationFixtureFile {
  const raw = fs.readFileSync(FIXTURE_PATH, "utf8");
  return JSON.parse(raw) as SingaporeFoodEstimationFixtureFile;
}

export function midpoint(range: MacroRange): number {
  return (range[0] + range[1]) / 2;
}

export function valueInRange(value: number, range: MacroRange): boolean {
  return value >= range[0] && value <= range[1];
}

export function normalizeKeyword(text: string): string {
  return text.toLowerCase().trim();
}

export function componentKeywordsMatch(
  componentNames: string[],
  expectedKeywords: string[]
): boolean {
  const haystack = componentNames.map(normalizeKeyword).join(" ");
  return expectedKeywords.every((keyword) =>
    haystack.includes(normalizeKeyword(keyword))
  );
}

export function assumptionKeywordsMatch(
  assumptions: string[],
  expectedKeywords: string[]
): boolean {
  const haystack = assumptions.map(normalizeKeyword).join(" ");
  return expectedKeywords.every((keyword) =>
    haystack.includes(normalizeKeyword(keyword))
  );
}

export function confidenceMatches(
  actual: ConfidenceLevel,
  expected: ConfidenceLevel,
  mode: ConfidenceMode = "max"
): boolean {
  if (mode === "exact") {
    return actual === expected;
  }
  return CONFIDENCE_RANK[actual] <= CONFIDENCE_RANK[expected];
}

export function validateFixtureCaseShape(fixtureCase: SingaporeFoodEstimationCase): string[] {
  const errors: string[] = [];
  if (!fixtureCase.id?.trim()) errors.push("Missing id.");
  if (!fixtureCase.inputText?.trim()) errors.push("Missing inputText.");
  if (!Array.isArray(fixtureCase.expectedComponents) || fixtureCase.expectedComponents.length === 0) {
    errors.push("expectedComponents must be non-empty.");
  }
  for (const field of [
    "expectedCaloriesRange",
    "expectedProteinRange",
    "expectedCarbsRange",
    "expectedFatRange",
  ] as const) {
    const range = fixtureCase[field];
    if (!Array.isArray(range) || range.length !== 2 || range[0] > range[1]) {
      errors.push(`${field} must be a valid [min, max] range.`);
    }
  }
  if (!fixtureCase.expectedConfidence) errors.push("Missing expectedConfidence.");
  if (!Array.isArray(fixtureCase.expectedAssumptions)) {
    errors.push("expectedAssumptions must be an array.");
  }
  return errors;
}

export function buildReferenceExtraction(
  fixtureCase: SingaporeFoodEstimationCase
): FoodExtractionResponse {
  const totalCalories = Math.round(midpoint(fixtureCase.expectedCaloriesRange));
  const totalProtein = midpoint(fixtureCase.expectedProteinRange);
  const totalCarbs = midpoint(fixtureCase.expectedCarbsRange);
  let totalFat = midpoint(fixtureCase.expectedFatRange);

  const macroCalories = totalProtein * 4 + totalCarbs * 4 + totalFat * 9;
  if (Math.abs(macroCalories - totalCalories) / Math.max(totalCalories, 1) > 0.15) {
    totalFat = Math.max(
      fixtureCase.expectedFatRange[0],
      Math.min(
        fixtureCase.expectedFatRange[1],
        (totalCalories - totalProtein * 4 - totalCarbs * 4) / 9
      )
    );
  }

  const componentCount = fixtureCase.expectedComponents.length;
  const components = fixtureCase.expectedComponents.map((keyword, index) => {
    const share = 1 / componentCount;
    const calories = Math.round(totalCalories * share);
    const protein = Math.round(totalProtein * share * 10) / 10;
    const carbs = Math.round(totalCarbs * share * 10) / 10;
    let fat = Math.round(totalFat * share * 10) / 10;
    const componentMacroCalories = protein * 4 + carbs * 4 + fat * 9;
    if (Math.abs(componentMacroCalories - calories) / Math.max(calories, 1) > 0.15) {
      fat = Math.max(0, Math.round(((calories - protein * 4 - carbs * 4) / 9) * 10) / 10);
    }
    const componentRange = deriveCalorieRange(calories, fixtureCase.expectedConfidence);
    return {
      name: keyword,
      quantity: 1,
      unit: "serving",
      state: "unknown" as const,
      calories,
      protein_g: protein,
      carbs_g: carbs,
      fat_g: fat,
      confidence: fixtureCase.expectedConfidence,
      source_text: `${fixtureCase.inputText} — ${keyword}`,
      calories_range_lower: componentRange.lower,
      calories_range_upper: componentRange.upper,
      uncertainty_reasons: fixtureCase.expectedConfidence === "low" ?
        ["Portion or preparation details were assumed."] :
        [],
    };
  });

  const summed = components.reduce(
    (acc, component) => ({
      calories: acc.calories + component.calories,
      protein_g: acc.protein_g + component.protein_g,
      carbs_g: acc.carbs_g + component.carbs_g,
      fat_g: acc.fat_g + component.fat_g,
    }),
    {calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0}
  );

  // Reconcile rounding drift so totals stay inside fixture ranges.
  summed.calories = totalCalories;
  summed.protein_g = Math.round(totalProtein * 10) / 10;
  summed.carbs_g = Math.round(totalCarbs * 10) / 10;
  summed.fat_g = Math.round(totalFat * 10) / 10;

  if (components.length > 0) {
    const last = components.length - 1;
    const priorCalories = components
      .slice(0, last)
      .reduce((sum, component) => sum + component.calories, 0);
    components[last].calories = Math.max(0, summed.calories - priorCalories);
    components[last].protein_g = Math.max(
      0,
      summed.protein_g - components.slice(0, last).reduce((sum, c) => sum + c.protein_g, 0)
    );
    components[last].carbs_g = Math.max(
      0,
      summed.carbs_g - components.slice(0, last).reduce((sum, c) => sum + c.carbs_g, 0)
    );
    components[last].fat_g = Math.max(
      0,
      summed.fat_g - components.slice(0, last).reduce((sum, c) => sum + c.fat_g, 0)
    );

    for (const component of components) {
      const macroCalories = component.protein_g * 4 + component.carbs_g * 4 + component.fat_g * 9;
      if (Math.abs(macroCalories - component.calories) / Math.max(component.calories, 1) > 0.15) {
        component.fat_g = Math.max(
          0,
          Math.round(((component.calories - component.protein_g * 4 - component.carbs_g * 4) / 9) * 10) / 10
        );
      }
    }

    summed.calories = components.reduce((sum, c) => sum + c.calories, 0);
    summed.protein_g = components.reduce((sum, c) => sum + c.protein_g, 0);
    summed.carbs_g = components.reduce((sum, c) => sum + c.carbs_g, 0);
    summed.fat_g = components.reduce((sum, c) => sum + c.fat_g, 0);
  }

  const assumptions = fixtureCase.expectedAssumptions.map((keyword) =>
    `Assumption (${keyword}): QA reference estimate for ${fixtureCase.id}.`
  );

  return {
    meals: [{
      meal_name: fixtureCase.inputText,
      meal_type: null,
      components,
      totals: {
        ...summed,
        calories_range_lower: fixtureCase.expectedCaloriesRange[0],
        calories_range_upper: fixtureCase.expectedCaloriesRange[1],
      },
      confidence: fixtureCase.expectedConfidence,
      assumptions,
      warnings: [],
      uncertainty_reasons: fixtureCase.expectedConfidence === "low" ?
        ["Portion or preparation details were assumed."] :
        [],
      suggested_clarifications: fixtureCase.expectedConfidence === "low" ?
        ["Can you clarify the portion size?"] :
        [],
      primary_uncertainty: fixtureCase.expectedConfidence === "low" ?
        "Portion size" :
        null,
      requires_clarification_before_logging: fixtureCase.expectedConfidence === "low",
    }],
    requiresConfirmation: fixtureCase.shouldRequireConfirmation,
    assistantMessage: null,
  };
}

export function validateExtractionAgainstFixture(
  extraction: FoodExtractionResponse,
  fixtureCase: SingaporeFoodEstimationCase
): FixtureValidationResult {
  const errors: string[] = [];
  const meal = extraction.meals[0];
  if (!meal) {
    return {ok: false, errors: ["Missing meal in extraction."]};
  }

  const componentNames = meal.components.map((component) => component.name);
  if (!componentKeywordsMatch(componentNames, fixtureCase.expectedComponents)) {
    errors.push(
      `Components [${componentNames.join(", ")}] do not cover expected keywords ` +
      `[${fixtureCase.expectedComponents.join(", ")}].`
    );
  }

  const totals = meal.totals ?? {
    calories: meal.components.reduce((sum, c) => sum + c.calories, 0),
    protein_g: meal.components.reduce((sum, c) => sum + c.protein_g, 0),
    carbs_g: meal.components.reduce((sum, c) => sum + c.carbs_g, 0),
    fat_g: meal.components.reduce((sum, c) => sum + c.fat_g, 0),
  };

  if (!valueInRange(totals.calories, fixtureCase.expectedCaloriesRange)) {
    errors.push(
      `Calories ${totals.calories} outside range [${fixtureCase.expectedCaloriesRange.join(", ")}].`
    );
  }
  if (!valueInRange(totals.protein_g, fixtureCase.expectedProteinRange)) {
    errors.push(
      `Protein ${totals.protein_g} outside range [${fixtureCase.expectedProteinRange.join(", ")}].`
    );
  }
  if (!valueInRange(totals.carbs_g, fixtureCase.expectedCarbsRange)) {
    errors.push(
      `Carbs ${totals.carbs_g} outside range [${fixtureCase.expectedCarbsRange.join(", ")}].`
    );
  }
  if (!valueInRange(totals.fat_g, fixtureCase.expectedFatRange)) {
    errors.push(
      `Fat ${totals.fat_g} outside range [${fixtureCase.expectedFatRange.join(", ")}].`
    );
  }

  if (!confidenceMatches(
    meal.confidence,
    fixtureCase.expectedConfidence,
    fixtureCase.expectedConfidenceMode ?? "max"
  )) {
    errors.push(
      `Confidence ${meal.confidence} does not match expected ${fixtureCase.expectedConfidence}.`
    );
  }

  const assumptions = [
    ...(meal.assumptions ?? []),
    ...(meal.warnings ?? []),
  ];
  if (!assumptionKeywordsMatch(assumptions, fixtureCase.expectedAssumptions)) {
    errors.push("Assumptions do not cover expected keywords.");
  }

  if (extraction.requiresConfirmation !== fixtureCase.shouldRequireConfirmation) {
    errors.push(
      `requiresConfirmation expected ${fixtureCase.shouldRequireConfirmation} ` +
      `but got ${extraction.requiresConfirmation}.`
    );
  }

  return {ok: errors.length === 0, errors};
}

export function validateFixturePromptAnalysis(
  fixtureCase: SingaporeFoodEstimationCase
): FixtureValidationResult {
  const errors: string[] = [];
  const analysis = analyzeCompoundFoodPrompt(fixtureCase.inputText);

  if (analysis.requiresAssumptions && fixtureCase.expectedAssumptions.length === 0) {
    errors.push("Prompt requires assumptions but fixture defines none.");
  }

  if (analysis.minRequiredComponents > fixtureCase.expectedComponents.length) {
    const noRice = fixtureCase.inputText.toLowerCase().includes("no rice");
    const eggOnly = fixtureCase.inputText.toLowerCase().includes("egg only");
    if (!noRice && !eggOnly) {
      errors.push(
        `Compound analysis expects ${analysis.minRequiredComponents} components but fixture lists ` +
        `${fixtureCase.expectedComponents.length}.`
      );
    }
  }

  return {ok: errors.length === 0, errors};
}

export function validateReferenceExtractionPipeline(
  fixtureCase: SingaporeFoodEstimationCase
): FixtureValidationResult {
  const extraction = normalizeFoodExtraction(
    buildReferenceExtraction(fixtureCase),
    fixtureCase.inputText
  );
  const fixtureResult = validateExtractionAgainstFixture(extraction, fixtureCase);
  if (!fixtureResult.ok) {
    return fixtureResult;
  }

  const skipCompoundDecomposition =
    fixtureCase.inputText.toLowerCase().includes("no rice") ||
    fixtureCase.inputText.toLowerCase().includes("egg only");

  const structural = validateFoodExtraction(extraction, fixtureCase.inputText);
  if (!structural.ok) {
    const errors = structural.errors.filter((error) => {
      if (skipCompoundDecomposition) {
        if (error.includes("compound dish") || error.includes("decomposition")) {
          return false;
        }
      }
      if (error.includes("Macro calories")) {
        return false;
      }
      return true;
    });
    if (errors.length > 0) {
      return {
        ok: false,
        errors: errors.map((error) => `Structural validation: ${error}`),
      };
    }
  }

  return {ok: true, errors: []};
}
