import fs from "fs";
import path from "path";

const FIXTURE_DIR = __dirname;

function loadJsonFixture<T>(filename: string): T {
  const filePath = path.join(FIXTURE_DIR, filename);
  const raw = fs.readFileSync(filePath, "utf8");
  return JSON.parse(raw) as T;
}

export const coachContextV2Fixtures = {
  minimal: loadJsonFixture<Record<string, unknown>>("minimal-context.json"),
  rich: loadJsonFixture<Record<string, unknown>>("rich-context.json"),
  degraded: loadJsonFixture<Record<string, unknown>>("degraded-context.json"),
  sanitizationProbe: loadJsonFixture<Record<string, unknown>>(
    "sanitization-probe-context.json"
  ),
  analyzeMealImageRequest: loadJsonFixture<Record<string, unknown>>(
    "analyze-meal-image-request.json"
  ),
} as const;

export const COACH_CONTEXT_V2_SCHEMA_VERSION = 2;

export const dailyReviewInputFixture = {
  date: "2026-07-02T12:00:00.000Z",
  calorieTarget: 2000,
  caloriesConsumed: 1500,
  caloriesRemaining: 500,
  isOverCalorieTarget: false,
  proteinTarget: 150,
  proteinConsumed: 120,
  proteinRemaining: 30,
  hasMetProteinTarget: false,
  carbsTarget: 200,
  carbsConsumed: 180,
  carbsRemaining: 20,
  fatTarget: 65,
  fatConsumed: 50,
  fatRemaining: 15,
  waterTargetMl: 2500,
  waterConsumedMl: 1800,
  waterRemainingMl: 700,
  hasMetWaterTarget: false,
  weightKg: null,
  latestWeightKg: null,
  steps: null,
  workoutCount: 0,
  workoutCaloriesBurned: 0,
  foodEntryCount: 2,
  lowConfidenceFoodCount: 0,
  topProteinFoodNames: [],
  deterministicNotes: [],
} as const;

/** Coach endpoint request bodies using canonical v2 context fixtures. */
export const coachEndpointRequestFixtures = {
  "classify-coach-intent": {
    path: "/v1/ai/classify-coach-intent",
    body: {
      text: "log 2 eggs",
      context: structuredClone(coachContextV2Fixtures.minimal),
      modelName: "gpt-5-nano",
      modelConfig: {
        cheapClassifierModel: "gpt-5-nano",
        cheapAnswerModel: "gpt-5-nano",
        strongCoachModel: "gpt-5.4-nano",
      },
    },
  },
  "estimate-food": {
    path: "/v1/ai/estimate-food",
    body: {
      text: "2 eggs",
      context: structuredClone(coachContextV2Fixtures.minimal),
    },
  },
  "generate-meal-advice": {
    path: "/v1/ai/generate-meal-advice",
    body: {
      question: "Should I eat pasta tonight?",
      context: structuredClone(coachContextV2Fixtures.rich),
    },
  },
  "generate-daily-review": {
    path: "/v1/ai/generate-daily-review",
    body: {
      input: {...dailyReviewInputFixture},
      context: structuredClone(coachContextV2Fixtures.minimal),
    },
  },
  "parse-edit-delete": {
    path: "/v1/ai/parse-edit-delete",
    body: {
      text: "delete my last meal",
      context: structuredClone(coachContextV2Fixtures.rich),
    },
  },
  "parse-multi-action": {
    path: "/v1/ai/parse-multi-action",
    body: {
      text: "log water and log weight",
      context: structuredClone(coachContextV2Fixtures.minimal),
    },
  },
  "analyze-meal-image": {
    path: "/v1/ai/analyze-meal-image",
    body: structuredClone(coachContextV2Fixtures.analyzeMealImageRequest),
  },
} as const;

/** Legacy v1 / AIContext-shaped payloads that must be rejected. */
export const rejectedContextFixtures = {
  schemaVersionOne: {
    meta: {schemaVersion: 1},
  },
  legacyAIContextShape: {
    date: "2026-07-03T12:00:00.000Z",
    timezoneIdentifier: "UTC",
    commonFoods: [],
    recentMessages: [],
    healthIntelligenceAwarenessAvailable: false,
  },
  emptyObject: {},
} as const;
