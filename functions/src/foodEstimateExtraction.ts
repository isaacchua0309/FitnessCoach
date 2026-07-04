/* eslint-disable @typescript-eslint/no-explicit-any, require-jsdoc, max-len, operator-linebreak */

import {
  analyzeCompoundFoodPrompt,
  componentNamesMatchCompound,
  type CompoundDishSpec,
} from "./foodCompoundDish";
import {resolveCalorieRange} from "./foodCalorieRange";

export interface FoodExtractionComponent {
  name: string;
  quantity: number | null;
  unit: string | null;
  state: "raw" | "cooked" | "unknown";
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  confidence: "low" | "medium" | "high";
  source_text: string;
}

export interface FoodExtractionTotals {
  calories: number;
  protein_g: number;
  carbs_g: number;
  fat_g: number;
  calories_range_lower?: number | null;
  calories_range_upper?: number | null;
}

export interface FoodExtractionMeal {
  meal_name: string;
  meal_type: string | null;
  components: FoodExtractionComponent[];
  totals: FoodExtractionTotals;
  confidence: "low" | "medium" | "high";
  assumptions: string[];
  warnings: string[];
}

export interface FoodExtractionResponse {
  meals: FoodExtractionMeal[];
  requiresConfirmation: boolean;
  assistantMessage: string | null;
}

export interface FoodExtractionValidationResult {
  ok: boolean;
  errors: string[];
}

const TOTAL_TOLERANCE_RATIO = 0.05;
const TOTAL_TOLERANCE_ABSOLUTE = {
  calories: 3,
  protein_g: 1,
  carbs_g: 1,
  fat_g: 1,
};
const MACRO_CALORIE_TOLERANCE = 0.15;
const NORMAL_MEAL_CALORIE_MAX = 1800;
const SINGLE_ITEM_CALORIE_MAX = 900;

const FOOD_QUANTITY_UNITS = [
  "grams",
  "gram",
  "tablespoon",
  "tbsp",
  "cups",
  "cup",
  "kg",
  "ml",
  "g",
] as const;

const FOOD_CLAUSE_KEYWORDS = [
  "chicken",
  "rice",
  "beef",
  "fish",
  "egg",
  "sauce",
  "dressing",
  "salad",
  "pasta",
  "barley",
] as const;

function isDigit(character: string): boolean {
  return character >= "0" && character <= "9";
}

function isWordCharacter(character: string): boolean {
  const code = character.charCodeAt(0);
  return (code >= 48 && code <= 57)
    || (code >= 97 && code <= 122)
    || (code >= 65 && code <= 90);
}

function hasUnitAt(text: string, index: number, unit: string): boolean {
  if (!text.startsWith(unit, index)) {
    return false;
  }
  const after = index + unit.length;
  return after === text.length || !isWordCharacter(text[after]);
}

function hasQuantityWithUnit(text: string): boolean {
  const lower = text.toLowerCase();
  let index = 0;
  while (index < lower.length) {
    if (!isDigit(lower[index])) {
      index += 1;
      continue;
    }

    let cursor = index;
    while (cursor < lower.length && (isDigit(lower[cursor]) || lower[cursor] === ".")) {
      cursor += 1;
    }

    let unitIndex = cursor;
    while (unitIndex < lower.length && lower[unitIndex] === " ") {
      unitIndex += 1;
    }

    for (const unit of FOOD_QUANTITY_UNITS) {
      if (hasUnitAt(lower, unitIndex, unit)) {
        return true;
      }
    }

    index = cursor > index ? cursor : index + 1;
  }

  return false;
}

function hasGramRange(text: string): boolean {
  const lower = text.toLowerCase();
  let index = 0;

  while (index < lower.length) {
    if (!isDigit(lower[index])) {
      index += 1;
      continue;
    }

    let firstNumberEnd = index;
    while (firstNumberEnd < lower.length && isDigit(lower[firstNumberEnd])) {
      firstNumberEnd += 1;
    }

    let dashIndex = firstNumberEnd;
    while (dashIndex < lower.length && lower[dashIndex] === " ") {
      dashIndex += 1;
    }

    if (dashIndex < lower.length && (lower[dashIndex] === "-" || lower[dashIndex] === "–")) {
      dashIndex += 1;
      while (dashIndex < lower.length && lower[dashIndex] === " ") {
        dashIndex += 1;
      }

      let secondNumberEnd = dashIndex;
      while (secondNumberEnd < lower.length && isDigit(lower[secondNumberEnd])) {
        secondNumberEnd += 1;
      }

      if (secondNumberEnd > dashIndex) {
        let unitIndex = secondNumberEnd;
        while (unitIndex < lower.length && lower[unitIndex] === " ") {
          unitIndex += 1;
        }

        for (const unit of ["grams", "gram", "g"] as const) {
          if (hasUnitAt(lower, unitIndex, unit)) {
            return true;
          }
        }
      }
    }

    index = firstNumberEnd > index ? firstNumberEnd : index + 1;
  }

  return false;
}

function containsWholeWord(text: string, word: string): boolean {
  const lower = text.toLowerCase();
  const target = word.toLowerCase();
  let index = 0;

  while (index <= lower.length - target.length) {
    const found = lower.indexOf(target, index);
    if (found === -1) {
      return false;
    }

    const beforeOk = found === 0 || !isWordCharacter(lower[found - 1]);
    const afterIndex = found + target.length;
    const afterOk = afterIndex === lower.length || !isWordCharacter(lower[afterIndex]);
    if (beforeOk && afterOk) {
      return true;
    }

    index = found + 1;
  }

  return false;
}

function hasVaguePortionPhrase(text: string): boolean {
  const lower = text.toLowerCase();
  const quantifiers = ["one", "two", "a", "an"];
  const containers = ["bowl", "plate", "cup", "serving"];

  for (const quantifier of quantifiers) {
    for (const container of containers) {
      const phrase = `${quantifier} ${container}`;
      let index = 0;
      while (index <= lower.length - phrase.length) {
        const found = lower.indexOf(phrase, index);
        if (found === -1) {
          break;
        }

        const beforeOk = found === 0 || !isWordCharacter(lower[found - 1]);
        const afterIndex = found + phrase.length;
        const afterOk = afterIndex === lower.length || !isWordCharacter(lower[afterIndex]);
        if (beforeOk && afterOk) {
          return true;
        }

        index = found + 1;
      }
    }
  }

  return false;
}

export function countListedIngredients(text: string): number {
  const lines = text
    .split(/\n/)
    .map((line) => line.trim())
    .filter(Boolean);

  let count = 0;
  for (const line of lines) {
    if (/^[-*•]\s+/.test(line) || /^\d+[.)]\s+/.test(line)) {
      count += 1;
      continue;
    }
    if (hasGramRange(line)) {
      count += 1;
      continue;
    }
    if (hasQuantityWithUnit(line)) {
      count += 1;
    }
  }

  if (count >= 2) {
    return count;
  }

  const normalized = text.replace(/\n/g, " ").trim();
  const clauses = splitClauses(normalized).filter(Boolean);
  const foodClauseCount = clauses.filter((part) => isFoodClause(part)).length;
  if (foodClauseCount >= 2) {
    return foodClauseCount;
  }

  const commaSeparated = text.split(/,| and /i).filter((part) =>
    /\d/.test(part) && /[a-z]/i.test(part)
  );
  return commaSeparated.length >= 2 ? commaSeparated.length : Math.max(count, 0);
}

function splitClauses(text: string): string[] {
  return text
    .replace(/\band\b/gi, ",")
    .split(/,|;/)
    .map((part) => part.trim())
    .filter(Boolean);
}

function isFoodClause(part: string): boolean {
  if (hasGramRange(part)) return true;
  if (hasQuantityWithUnit(part)) return true;
  if (hasVaguePortionPhrase(part)) return true;
  return FOOD_CLAUSE_KEYWORDS.some((keyword) => containsWholeWord(part, keyword));
}

export function normalizeFoodExtraction(
  extraction: FoodExtractionResponse,
  userText: string
): FoodExtractionResponse {
  const promptAnalysis = analyzeCompoundFoodPrompt(userText);

  const meals = extraction.meals.map((meal) => {
    const components = meal.components.map((component) => clampComponentMacros(component));
    const summed = sumComponents(components);
    const warnings = [...(meal.warnings ?? [])];

    if (
      summed.calories > NORMAL_MEAL_CALORIE_MAX &&
      !promptAnalysis.hasHugePortionHint
    ) {
      warnings.push(
        "Total calories look high for a normal portion; review before logging."
      );
    }

    let confidence = meal.confidence;
    if (promptAnalysis.isAmbiguousServing && confidence === "high") {
      confidence = "medium";
    }
    if (
      promptAnalysis.matchedDishes.length > 0 &&
      components.length < promptAnalysis.minRequiredComponents &&
      confidence !== "low"
    ) {
      confidence = "low";
    }

    return {
      ...meal,
      components,
      totals: {
        ...summed,
        calories_range_lower: resolveCalorieRange(
          summed.calories,
          confidence
        ).lower,
        calories_range_upper: resolveCalorieRange(
          summed.calories,
          confidence
        ).upper,
      },
      confidence,
      warnings: Array.from(new Set(warnings)),
    };
  });

  return {
    ...extraction,
    meals,
  };
}

export function validateFoodExtraction(
  extraction: FoodExtractionResponse,
  userText: string
): FoodExtractionValidationResult {
  const errors: string[] = [];
  const listedIngredients = countListedIngredients(userText);
  const promptAnalysis = analyzeCompoundFoodPrompt(userText);

  if (!Array.isArray(extraction.meals) || extraction.meals.length === 0) {
    return {ok: false, errors: ["Response is missing meals."]};
  }

  for (const meal of extraction.meals) {
    if (!meal.components || meal.components.length === 0) {
      errors.push(`Meal "${meal.meal_name}" is missing components.`);
      continue;
    }

    if (listedIngredients >= 2 && meal.components.length < 2) {
      errors.push(
        `Meal "${meal.meal_name}" collapsed ${listedIngredients} listed ingredients into ` +
        `${meal.components.length} component(s).`
      );
    }

    validateCompoundDishDecomposition(
      meal,
      promptAnalysis.matchedDishes,
      promptAnalysis.minRequiredComponents,
      errors
    );

    const summed = sumComponents(meal.components);
    const totals = meal.totals ?? summed;

    if (!withinTolerance(totals.calories, summed.calories, TOTAL_TOLERANCE_ABSOLUTE.calories)) {
      errors.push(
        `Meal "${meal.meal_name}" total calories ${totals.calories} do not match ` +
        `component sum ${summed.calories}.`
      );
    }
    if (!withinTolerance(totals.protein_g, summed.protein_g, TOTAL_TOLERANCE_ABSOLUTE.protein_g)) {
      errors.push(
        `Meal "${meal.meal_name}" total protein does not match component sum.`
      );
    }
    if (!withinTolerance(totals.carbs_g, summed.carbs_g, TOTAL_TOLERANCE_ABSOLUTE.carbs_g)) {
      errors.push(
        `Meal "${meal.meal_name}" total carbs do not match component sum.`
      );
    }
    if (!withinTolerance(totals.fat_g, summed.fat_g, TOTAL_TOLERANCE_ABSOLUTE.fat_g)) {
      errors.push(
        `Meal "${meal.meal_name}" total fat does not match component sum.`
      );
    }

    validateMacroCalorieBalance(
      "meal totals",
      totals.calories,
      totals.protein_g,
      totals.carbs_g,
      totals.fat_g,
      errors
    );

    if (
      summed.calories > NORMAL_MEAL_CALORIE_MAX &&
      !promptAnalysis.hasHugePortionHint
    ) {
      errors.push(
        `Meal "${meal.meal_name}" calories ${Math.round(summed.calories)} look too high for a normal portion.`
      );
    }

    if (
      meal.components.length === 1 &&
      summed.calories > SINGLE_ITEM_CALORIE_MAX &&
      !promptAnalysis.hasHugePortionHint
    ) {
      errors.push(
        `Meal "${meal.meal_name}" single-component calories look too high for a normal portion.`
      );
    }

    if (promptAnalysis.requiresAssumptions && (!meal.assumptions || meal.assumptions.length === 0)) {
      errors.push(
        `Meal "${meal.meal_name}" must include assumptions for portion, oil/sauce, confidence, and clarifications.`
      );
    }

    for (const component of meal.components) {
      if (!component.source_text?.trim()) {
        errors.push(`Component "${component.name}" is missing source_text.`);
      }
      if (!component.name?.trim()) {
        errors.push("A component is missing name.");
      }
      validateComponentMacros(component, errors);
    }
  }

  return {ok: errors.length === 0, errors};
}

export function foodEstimateRepairInstructions(errors: string[]): string {
  return [
    "REPAIR REQUIRED. The previous JSON failed validation.",
    ...errors.map((error) => `- ${error}`),
    "Return corrected JSON only.",
    "You MUST keep every listed ingredient as its own component with quantity, unit, state, and source_text.",
    "totals must exactly equal the sum of component calories, protein_g, carbs_g, and fat_g.",
    "Never collapse multiple listed ingredients or compound dishes into one generic component.",
    "Do not use the first ingredient quantity as a meal-level quantity.",
    "Include assumptions for portion, oil/sauce, confidence reason, and what the user can clarify.",
    "Prefer realistic or slightly conservative calorie estimates.",
    "All macros must be non-negative and macro calories must match displayed calories within 15%.",
  ].join("\n");
}

export function normalizeMealType(value: string | null | undefined): string | null {
  if (value == null) {
    return null;
  }
  const trimmed = value.trim().toLowerCase();
  if (!trimmed || trimmed === "null") {
    return null;
  }
  const allowed = new Set(["breakfast", "lunch", "dinner", "snack", "unknown"]);
  return allowed.has(trimmed) ? trimmed : "unknown";
}

export function mapExtractionToGatewayPayload(
  extraction: FoodExtractionResponse,
  source: "aiTextEstimate" | "aiPhotoEstimate",
  validation: FoodExtractionValidationResult
) {
  const confidence = validation.ok ?
    highestConfidence(extraction.meals) :
    "low";

  const foodLogDrafts = extraction.meals.map((meal) => {
    const summed = sumComponents(meal.components);
    const calorieRange = resolveCalorieRange(
      summed.calories,
      meal.confidence,
      meal.totals?.calories_range_lower,
      meal.totals?.calories_range_upper
    );
    const mealAssumptions = (meal.assumptions ?? [])
      .map((item) => item.trim())
      .filter(Boolean);
    const warnings = [...(meal.warnings ?? [])];
    if (!validation.ok) {
      warnings.push(
        "Estimate failed strict extraction validation. Review portions before logging."
      );
    }

    return {
      id: null,
      displayName: meal.meal_name,
      mealType: normalizeMealType(meal.meal_type),
      components: meal.components.map((component) => ({
        id: null,
        name: component.name,
        quantity: component.quantity,
        unit: component.unit,
        preparationState: component.state === "unknown" ? null : component.state,
        calories: Math.round(component.calories),
        protein: component.protein_g,
        carbs: component.carbs_g,
        fat: component.fat_g,
        confidence: component.confidence,
        sourceText: component.source_text,
      })),
      confidence,
      source,
      notes: null,
      warnings,
      assumptions: mealAssumptions,
      caloriesRangeLower: calorieRange.lower,
      caloriesRangeUpper: calorieRange.upper,
      imageUrl: null,
    };
  });

  const foodDrafts = foodLogDrafts.map((meal) => {
    const totals = sumMappedComponents(meal.components);
    const multi = meal.components.length > 1;
    return {
      mealType: meal.mealType,
      name: meal.displayName,
      quantity: multi ? null : meal.components[0]?.quantity ?? null,
      unit: multi ? null : meal.components[0]?.unit ?? null,
      calories: totals.calories,
      protein: totals.protein,
      carbs: totals.carbs,
      fat: totals.fat,
      fiber: null,
      sodium: null,
      source,
      confidence,
      imageUrl: null,
      notes: null,
    };
  });

  return {
    foodLogDrafts,
    foodDrafts,
    confidence,
    requiresConfirmation: extraction.requiresConfirmation ?? true,
    assistantMessage: extraction.assistantMessage,
  };
}

function sumComponents(components: FoodExtractionComponent[]): FoodExtractionTotals {
  return components.reduce(
    (acc, component) => ({
      calories: acc.calories + (component.calories ?? 0),
      protein_g: acc.protein_g + (component.protein_g ?? 0),
      carbs_g: acc.carbs_g + (component.carbs_g ?? 0),
      fat_g: acc.fat_g + (component.fat_g ?? 0),
    }),
    {calories: 0, protein_g: 0, carbs_g: 0, fat_g: 0}
  );
}

function sumMappedComponents(components: Array<Record<string, any>>) {
  return components.reduce(
    (acc, component) => ({
      calories: acc.calories + (component.calories ?? 0),
      protein: acc.protein + (component.protein ?? 0),
      carbs: acc.carbs + (component.carbs ?? 0),
      fat: acc.fat + (component.fat ?? 0),
    }),
    {calories: 0, protein: 0, carbs: 0, fat: 0}
  );
}

function clampComponentMacros(component: FoodExtractionComponent): FoodExtractionComponent {
  return {
    ...component,
    calories: Math.max(0, component.calories ?? 0),
    protein_g: Math.max(0, component.protein_g ?? 0),
    carbs_g: Math.max(0, component.carbs_g ?? 0),
    fat_g: Math.max(0, component.fat_g ?? 0),
  };
}

function validateCompoundDishDecomposition(
  meal: FoodExtractionMeal,
  matchedDishes: CompoundDishSpec[],
  minRequiredComponents: number,
  errors: string[]
): void {
  if (matchedDishes.length === 0 || minRequiredComponents <= 1) {
    return;
  }

  if (meal.components.length < minRequiredComponents) {
    const labels = matchedDishes.map((dish) => dish.label).join(", ");
    errors.push(
      `Meal "${meal.meal_name}" collapsed compound dish (${labels}) into ` +
      `${meal.components.length} component(s); expected at least ${minRequiredComponents}.`
    );
    return;
  }

  const componentNames = meal.components.map((component) => component.name);
  for (const dish of matchedDishes) {
    if (dish.minComponents > 1 && !componentNamesMatchCompound(componentNames, dish)) {
      errors.push(
        `Meal "${meal.meal_name}" components do not reflect expected ${dish.label} decomposition.`
      );
    }
  }
}

function validateComponentMacros(
  component: FoodExtractionComponent,
  errors: string[]
): void {
  const label = component.name ?? "component";
  if ((component.calories ?? 0) < 0) {
    errors.push(`Component "${label}" has negative calories.`);
  }
  if ((component.protein_g ?? 0) < 0) {
    errors.push(`Component "${label}" has negative protein.`);
  }
  if ((component.carbs_g ?? 0) < 0) {
    errors.push(`Component "${label}" has negative carbs.`);
  }
  if ((component.fat_g ?? 0) < 0) {
    errors.push(`Component "${label}" has negative fat.`);
  }

  validateMacroCalorieBalance(
    label,
    component.calories ?? 0,
    component.protein_g ?? 0,
    component.carbs_g ?? 0,
    component.fat_g ?? 0,
    errors
  );
}

function validateMacroCalorieBalance(
  label: string,
  calories: number,
  protein: number,
  carbs: number,
  fat: number,
  errors: string[]
): void {
  if (calories <= 0) {
    return;
  }
  const computed = protein * 4 + carbs * 4 + fat * 9;
  if (computed <= 0) {
    return;
  }
  const delta = Math.abs(computed - calories) / calories;
  if (delta > MACRO_CALORIE_TOLERANCE) {
    errors.push(`Macro calories for ${label} do not match displayed calories.`);
  }
}

function withinTolerance(actual: number, expected: number, absolute: number): boolean {
  const delta = Math.abs(actual - expected);
  if (delta <= absolute) {
    return true;
  }
  if (expected === 0) {
    return actual === 0;
  }
  return delta / Math.abs(expected) <= TOTAL_TOLERANCE_RATIO;
}

function highestConfidence(
  meals: FoodExtractionMeal[]
): "low" | "medium" | "high" {
  const order = {low: 0, medium: 1, high: 2};
  return meals.reduce<"low" | "medium" | "high">((lowest, meal) => {
    return order[meal.confidence] < order[lowest] ? meal.confidence : lowest;
  }, "high");
}
