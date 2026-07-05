import * as fs from "fs";
import * as path from "path";
import {
  type FoodExtractionResponse,
  validateFoodExtraction,
} from "../../src/foodEstimateExtraction";
import {
  type MealImageAnalysisResponse,
  validateMealImageAnalysisResponse,
} from "../../src/mealImageAnalysis";
import {
  type ConfidenceLevel,
  type MacroRange,
  type SingaporeFoodEstimationCase,
  assumptionKeywordsMatch,
  buildReferenceExtraction,
  componentKeywordsMatch,
  confidenceMatches,
  loadSingaporeFoodEstimationFixture,
  midpoint,
  valueInRange,
} from "./singaporeFoodEstimationFixtureSupport";

export type BenchmarkCategory =
  | "singapore_hawker"
  | "meal_prep"
  | "drinks"
  | "desserts"
  | "photo_scenario"
  | "correction_flow";

export type BenchmarkRoute =
  | "estimate_food"
  | "log_food"
  | "clarify"
  | "photo_analysis";

export interface ConfidenceBand {
  min: ConfidenceLevel;
  max: ConfidenceLevel;
}

export interface CoachAccuracyBenchmarkCase {
  id: string;
  category: BenchmarkCategory;
  prompt: string;
  expectedRoute: BenchmarkRoute;
  shouldLogAutomatically: boolean;
  shouldRequireConfirmation: boolean;
  shouldAskClarification?: boolean;
  allowLowConfidencePending?: boolean;
  expectedConfidenceBand: ConfidenceBand;
  expectedCaloriesRange?: MacroRange;
  expectedProteinRange?: MacroRange;
  expectedCarbsRange?: MacroRange;
  expectedFatRange?: MacroRange;
  requiredUncertaintyKeywords: string[];
  requiredAssumptionKeywords: string[];
  expectedComponents: string[];
  mockImageAnalysisResponse?: MealImageAnalysisResponse;
  baselinePrompt?: string;
  singaporeFixtureId?: string;
  notes: string;
}

export interface CoachAccuracyBenchmarkFixtureFile {
  version: number;
  description: string;
  caseCount: number;
  categories: BenchmarkCategory[];
  cases: CoachAccuracyBenchmarkCase[];
}

export type BenchmarkFailureKind =
  | "route"
  | "range"
  | "missing_assumption"
  | "missing_uncertainty"
  | "overconfidence"
  | "clarification"
  | "confirmation"
  | "schema"
  | "component";

export interface BenchmarkCaseFailure {
  kind: BenchmarkFailureKind;
  message: string;
}

export interface BenchmarkCaseResult {
  id: string;
  category: BenchmarkCategory;
  passed: boolean;
  failures: BenchmarkCaseFailure[];
}

export interface BenchmarkRunSummary {
  totalCases: number;
  passedCases: number;
  failedCases: number;
  routeFailures: number;
  rangeFailures: number;
  missingAssumptionFailures: number;
  missingUncertaintyFailures: number;
  overconfidenceFailures: number;
  clarificationFailures: number;
  confirmationFailures: number;
  schemaFailures: number;
  componentFailures: number;
  results: BenchmarkCaseResult[];
}

const BENCHMARK_FIXTURE_PATH = path.resolve(
  __dirname,
  "../../../Docs/Coach/Fixtures/coach_accuracy_benchmark_v1_cases.json"
);

const CONFIDENCE_RANK: Record<ConfidenceLevel, number> = {
  low: 0,
  medium: 1,
  high: 2,
};

export function loadCoachAccuracyBenchmarkFixture(): CoachAccuracyBenchmarkFixtureFile {
  const raw = fs.readFileSync(BENCHMARK_FIXTURE_PATH, "utf8");
  return JSON.parse(raw) as CoachAccuracyBenchmarkFixtureFile;
}

export function validateBenchmarkCaseShape(benchmarkCase: CoachAccuracyBenchmarkCase): string[] {
  const errors: string[] = [];
  if (!benchmarkCase.id?.trim()) errors.push("Missing id.");
  if (!benchmarkCase.category) errors.push("Missing category.");
  if (!benchmarkCase.prompt?.trim()) errors.push("Missing prompt.");
  if (!benchmarkCase.expectedRoute) errors.push("Missing expectedRoute.");
  if (!Array.isArray(benchmarkCase.expectedComponents) || benchmarkCase.expectedComponents.length === 0) {
    errors.push("expectedComponents must be non-empty.");
  }
  if (!benchmarkCase.expectedConfidenceBand?.min || !benchmarkCase.expectedConfidenceBand?.max) {
    errors.push("expectedConfidenceBand must define min and max.");
  }
  if (benchmarkCase.shouldLogAutomatically) {
    errors.push("Benchmark v1 expects shouldLogAutomatically=false.");
  }
  if (!benchmarkCase.shouldRequireConfirmation) {
    errors.push("Benchmark v1 expects shouldRequireConfirmation=true.");
  }
  if (benchmarkCase.category === "photo_scenario" && !benchmarkCase.mockImageAnalysisResponse) {
    errors.push("photo_scenario cases require mockImageAnalysisResponse.");
  }
  if (benchmarkCase.category === "correction_flow" && !benchmarkCase.baselinePrompt?.trim()) {
    errors.push("correction_flow cases require baselinePrompt.");
  }
  return errors;
}

export function benchmarkCaseToSingaporeShape(
  benchmarkCase: CoachAccuracyBenchmarkCase
): SingaporeFoodEstimationCase {
  const calories = benchmarkCase.expectedCaloriesRange ?? [0, 9999];
  const protein = benchmarkCase.expectedProteinRange ?? [0, 9999];
  const carbs = benchmarkCase.expectedCarbsRange ?? [0, 9999];
  const fat = benchmarkCase.expectedFatRange ?? [0, 9999];

  return {
    id: benchmarkCase.id,
    inputText: benchmarkCase.prompt,
    expectedComponents: benchmarkCase.expectedComponents,
    expectedCaloriesRange: calories,
    expectedProteinRange: protein,
    expectedCarbsRange: carbs,
    expectedFatRange: fat,
    expectedConfidence: benchmarkCase.expectedConfidenceBand.max,
    expectedConfidenceMode: "max",
    expectedAssumptions: [
      ...benchmarkCase.requiredAssumptionKeywords,
      ...benchmarkCase.requiredUncertaintyKeywords,
    ],
    shouldRequireConfirmation: benchmarkCase.shouldRequireConfirmation,
    notes: benchmarkCase.notes,
  };
}

export function buildReferenceExtractionForBenchmark(
  benchmarkCase: CoachAccuracyBenchmarkCase
): FoodExtractionResponse {
  let extraction: FoodExtractionResponse;

  if (benchmarkCase.singaporeFixtureId) {
    const sgFixture = loadSingaporeFoodEstimationFixture();
    const linked = sgFixture.cases.find((item) => item.id === benchmarkCase.singaporeFixtureId);
    if (linked) {
      extraction = buildReferenceExtraction(linked);
    } else {
      extraction = buildReferenceExtraction(benchmarkCaseToSingaporeShape(benchmarkCase));
    }
  } else {
    extraction = buildReferenceExtraction(benchmarkCaseToSingaporeShape(benchmarkCase));
  }

  const meal = extraction.meals[0];
  const assumptionLines = [
    ...(meal.assumptions ?? []),
    ...benchmarkCase.requiredAssumptionKeywords.map(
      (keyword) => `Assumption (${keyword}): benchmark reference for ${benchmarkCase.id}.`
    ),
    ...benchmarkCase.requiredUncertaintyKeywords.map(
      (keyword) => `Uncertainty (${keyword}): estimate may vary for ${benchmarkCase.id}.`
    ),
  ];
  meal.assumptions = assumptionLines;

  if (benchmarkCase.category === "correction_flow" && benchmarkCase.baselinePrompt) {
    meal.assumptions.push(
      `Correction applied after baseline prompt: ${benchmarkCase.baselinePrompt}.`
    );
    extraction.assistantMessage = `Updated estimate based on: ${benchmarkCase.prompt}`;
  }

  extraction.requiresConfirmation = benchmarkCase.shouldRequireConfirmation;
  return extraction;
}

export function validateBenchmarkReferencePipeline(
  benchmarkCase: CoachAccuracyBenchmarkCase
): {ok: boolean; errors: string[]} {
  let extraction: FoodExtractionResponse;
  let photoResponse: MealImageAnalysisResponse | undefined;

  if (benchmarkCase.category === "photo_scenario" &&
    benchmarkCase.mockImageAnalysisResponse) {
    photoResponse = benchmarkCase.mockImageAnalysisResponse;
    extraction = mealImageResponseToExtraction(photoResponse, benchmarkCase.prompt);
  } else {
    extraction = buildReferenceExtractionForBenchmark(benchmarkCase);
  }

  const scored = scoreBenchmarkCase(benchmarkCase, extraction, {
    actualRoute: benchmarkCase.category === "photo_scenario" ?
      "photo_analysis" :
      benchmarkCase.expectedRoute,
    photoResponse,
  });
  if (!scored.passed) {
    return {ok: false, errors: scored.failures.map((failure) => failure.message)};
  }

  const structural = validateFoodExtraction(extraction, benchmarkCase.prompt);
  if (!structural.ok) {
    const relaxed = structural.errors.filter((error) => {
      if (error.includes("Macro calories")) return false;
      if (error.includes("do not match component sum")) return false;
      if (benchmarkCase.category === "correction_flow") {
        return !error.includes("compound dish") && !error.includes("decomposition");
      }
      return true;
    });
    if (relaxed.length > 0) {
      return {ok: false, errors: relaxed.map((error) => `Structural validation: ${error}`)};
    }
  }

  return {ok: true, errors: []};
}

export function mealImageResponseToExtraction(
  response: MealImageAnalysisResponse,
  prompt: string
): FoodExtractionResponse {
  const components = response.items.map((item) => ({
    name: item.name,
    quantity: 1,
    unit: item.quantity ?? "serving",
    state: "unknown" as const,
    calories: item.calories,
    protein_g: item.protein,
    carbs_g: item.carbs,
    fat_g: item.fat,
    confidence: item.confidence,
    source_text: item.assumptions.join("; "),
  }));

  const assumptions = response.items.flatMap((item) => item.assumptions);

  return {
    meals: [{
      meal_name: response.summary,
      meal_type: null,
      components,
      totals: {
        calories: response.total.calories,
        protein_g: response.total.protein,
        carbs_g: response.total.carbs,
        fat_g: response.total.fat,
      },
      confidence: response.items.some((item) => item.confidence === "low") ?
        "low" :
        response.items.every((item) => item.confidence === "high") ?
          "high" :
          "medium",
      assumptions,
      warnings: response.clarifyingQuestion ? [response.clarifyingQuestion] : [],
    }],
    requiresConfirmation: true,
    assistantMessage: response.clarifyingQuestion ?? null,
  };
}

export function confidenceWithinBand(
  actual: ConfidenceLevel,
  band: ConfidenceBand
): boolean {
  const actualRank = CONFIDENCE_RANK[actual];
  return actualRank >= CONFIDENCE_RANK[band.min] &&
    actualRank <= CONFIDENCE_RANK[band.max];
}

export function uncertaintyKeywordsPresent(
  extraction: FoodExtractionResponse,
  requiredKeywords: string[]
): boolean {
  if (requiredKeywords.length === 0) return true;
  const meal = extraction.meals[0];
  const haystack = [
    ...(meal?.assumptions ?? []),
    ...(meal?.warnings ?? []),
    extraction.assistantMessage ?? "",
    meal?.components.map((component) => component.source_text ?? "").join(" ") ?? "",
  ].join(" ").toLowerCase();
  return requiredKeywords.every((keyword) => haystack.includes(keyword.toLowerCase()));
}

export function scoreBenchmarkCase(
  benchmarkCase: CoachAccuracyBenchmarkCase,
  extraction: FoodExtractionResponse,
  options?: {
    actualRoute?: BenchmarkRoute;
    photoResponse?: MealImageAnalysisResponse;
  }
): BenchmarkCaseResult {
  const failures: BenchmarkCaseFailure[] = [];
  const meal = extraction.meals[0];

  if (options?.actualRoute && options.actualRoute !== benchmarkCase.expectedRoute) {
    failures.push({
      kind: "route",
      message: `Expected route ${benchmarkCase.expectedRoute} but got ${options.actualRoute}.`,
    });
  }

  if (!meal) {
    failures.push({kind: "schema", message: "Missing meal in extraction."});
    return {id: benchmarkCase.id, category: benchmarkCase.category, passed: false, failures};
  }

  const structural = validateFoodExtraction(extraction, benchmarkCase.prompt);
  if (!structural.ok) {
    for (const error of structural.errors) {
      if (error.includes("Macro calories")) continue;
      if (error.includes("do not match component sum")) continue;
      failures.push({kind: "schema", message: error});
    }
  }

  const componentNames = meal.components.map((component) => component.name);
  const componentHaystack = [
    meal.meal_name ?? "",
    ...componentNames,
    ...(meal.assumptions ?? []),
  ].join(" ");
  if (!componentKeywordsMatch([componentHaystack], benchmarkCase.expectedComponents)) {
    failures.push({
      kind: "component",
      message:
        `Components [${componentNames.join(", ")}] do not cover ` +
        `[${benchmarkCase.expectedComponents.join(", ")}].`,
    });
  }

  const totals = meal.totals ?? {
    calories: meal.components.reduce((sum, c) => sum + c.calories, 0),
    protein_g: meal.components.reduce((sum, c) => sum + c.protein_g, 0),
    carbs_g: meal.components.reduce((sum, c) => sum + c.carbs_g, 0),
    fat_g: meal.components.reduce((sum, c) => sum + c.fat_g, 0),
  };

  if (benchmarkCase.expectedCaloriesRange &&
    !valueInRange(totals.calories, benchmarkCase.expectedCaloriesRange)) {
    failures.push({
      kind: "range",
      message:
        `Calories ${totals.calories} outside ` +
        `[${benchmarkCase.expectedCaloriesRange.join(", ")}].`,
    });
  }
  if (benchmarkCase.expectedProteinRange &&
    !valueInRange(totals.protein_g, benchmarkCase.expectedProteinRange)) {
    failures.push({
      kind: "range",
      message:
        `Protein ${totals.protein_g} outside ` +
        `[${benchmarkCase.expectedProteinRange.join(", ")}].`,
    });
  }

  const assumptions = [...(meal.assumptions ?? []), ...(meal.warnings ?? [])];
  if (!assumptionKeywordsMatch(assumptions, benchmarkCase.requiredAssumptionKeywords)) {
    failures.push({
      kind: "missing_assumption",
      message: "Assumptions do not cover required keywords.",
    });
  }

  if (!uncertaintyKeywordsPresent(extraction, benchmarkCase.requiredUncertaintyKeywords)) {
    failures.push({
      kind: "missing_uncertainty",
      message: "Uncertainty keywords missing from assumptions/warnings/assistant message.",
    });
  }

  if (!confidenceWithinBand(meal.confidence, benchmarkCase.expectedConfidenceBand)) {
    failures.push({
      kind: "overconfidence",
      message:
        `Confidence ${meal.confidence} outside band ` +
        `[${benchmarkCase.expectedConfidenceBand.min}, ${benchmarkCase.expectedConfidenceBand.max}].`,
    });
  } else if (!confidenceMatches(
    meal.confidence,
    benchmarkCase.expectedConfidenceBand.max,
    "max"
  )) {
    failures.push({
      kind: "overconfidence",
      message:
        `Confidence ${meal.confidence} exceeds max band ${benchmarkCase.expectedConfidenceBand.max}.`,
    });
  }

  if (extraction.requiresConfirmation !== benchmarkCase.shouldRequireConfirmation) {
    failures.push({
      kind: "confirmation",
      message:
        `requiresConfirmation expected ${benchmarkCase.shouldRequireConfirmation} ` +
        `but got ${extraction.requiresConfirmation}.`,
    });
  }

  const clarifyingQuestion = options?.photoResponse?.clarifyingQuestion ??
    extraction.assistantMessage;
  const hasClarification = Boolean(
    clarifyingQuestion && clarifyingQuestion.trim().length > 0
  );

  if (benchmarkCase.shouldAskClarification && !hasClarification) {
    failures.push({
      kind: "clarification",
      message: "Expected clarifying question but none was provided.",
    });
  }

  if (!benchmarkCase.shouldAskClarification &&
    !benchmarkCase.allowLowConfidencePending &&
    hasClarification &&
    benchmarkCase.category !== "correction_flow") {
    failures.push({
      kind: "clarification",
      message: "Unexpected clarifying question for this scenario.",
    });
  }

  if (options?.photoResponse) {
    const photoValidation = validateMealImageAnalysisResponse(options.photoResponse);
    if (!photoValidation.ok) {
      for (const error of photoValidation.errors) {
        failures.push({kind: "schema", message: `Photo schema: ${error}`});
      }
    }
    if (options.photoResponse.needsUserReview !== true) {
      failures.push({
        kind: "confirmation",
        message: "Photo analysis must set needsUserReview=true.",
      });
    }
  }

  return {
    id: benchmarkCase.id,
    category: benchmarkCase.category,
    passed: failures.length === 0,
    failures,
  };
}

function countFailuresByKind(
  results: BenchmarkCaseResult[],
  kind: BenchmarkFailureKind
): number {
  return results.reduce(
    (count, result) => count + result.failures.filter((failure) => failure.kind === kind).length,
    0
  );
}

export function summarizeBenchmarkRun(results: BenchmarkCaseResult[]): BenchmarkRunSummary {
  const passedCases = results.filter((result) => result.passed).length;
  return {
    totalCases: results.length,
    passedCases,
    failedCases: results.length - passedCases,
    routeFailures: countFailuresByKind(results, "route"),
    rangeFailures: countFailuresByKind(results, "range"),
    missingAssumptionFailures: countFailuresByKind(results, "missing_assumption"),
    missingUncertaintyFailures: countFailuresByKind(results, "missing_uncertainty"),
    overconfidenceFailures: countFailuresByKind(results, "overconfidence"),
    clarificationFailures: countFailuresByKind(results, "clarification"),
    confirmationFailures: countFailuresByKind(results, "confirmation"),
    schemaFailures: countFailuresByKind(results, "schema"),
    componentFailures: countFailuresByKind(results, "component"),
    results,
  };
}

export function runDeterministicBenchmark(
  fixture: CoachAccuracyBenchmarkFixtureFile = loadCoachAccuracyBenchmarkFixture()
): BenchmarkRunSummary {
  const results = fixture.cases.map((benchmarkCase) => {
    if (benchmarkCase.category === "photo_scenario" &&
      benchmarkCase.mockImageAnalysisResponse) {
      const photoResponse = benchmarkCase.mockImageAnalysisResponse;
      const extraction = mealImageResponseToExtraction(photoResponse, benchmarkCase.prompt);
      return scoreBenchmarkCase(benchmarkCase, extraction, {
        actualRoute: "photo_analysis",
        photoResponse,
      });
    }

    const extraction = buildReferenceExtractionForBenchmark(benchmarkCase);
    return scoreBenchmarkCase(benchmarkCase, extraction, {
      actualRoute: benchmarkCase.expectedRoute,
    });
  });

  return summarizeBenchmarkRun(results);
}

export function formatBenchmarkSummary(summary: BenchmarkRunSummary): string {
  return [
    `Coach Accuracy Benchmark v1`,
    `total=${summary.totalCases} passed=${summary.passedCases} failed=${summary.failedCases}`,
    `route=${summary.routeFailures} range=${summary.rangeFailures} ` +
    `assumption=${summary.missingAssumptionFailures} uncertainty=${summary.missingUncertaintyFailures}`,
    `overconfidence=${summary.overconfidenceFailures} clarification=${summary.clarificationFailures} ` +
    `confirmation=${summary.confirmationFailures} schema=${summary.schemaFailures} ` +
    `component=${summary.componentFailures}`,
  ].join("\n");
}

export function isLiveBenchmarkEnabled(): boolean {
  return process.env.RUN_LIVE_FOOD_BENCHMARK === "1";
}

export function liveBenchmarkCredentialsAvailable(): boolean {
  return Boolean(
    process.env.OPENAI_API_KEY ||
    process.env.FORMA_AI_GATEWAY_URL
  );
}

export {midpoint, valueInRange};
