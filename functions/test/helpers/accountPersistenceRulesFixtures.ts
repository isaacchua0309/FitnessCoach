import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {Timestamp} from "firebase/firestore";

export const ACCOUNT_PERSISTENCE_RULES_PROJECT_ID =
  "forma-account-persistence-rules-test";

export const USER_A = "userA";
export const USER_B = "userB";
export const LOCAL_DATE = "2026-07-04";

export async function initializeAccountPersistenceRulesTestEnvironment():
  Promise<RulesTestEnvironment> {
  return initializeTestEnvironment({
    projectId: ACCOUNT_PERSISTENCE_RULES_PROJECT_ID,
    firestore: {
      rules: readFileSync(resolve(__dirname, "../../../firestore.rules"), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
}

export function accountTimestamps() {
  const now = Timestamp.now();
  return {
    updatedAt: now,
    createdAt: now,
  };
}

export function dailyLogPayload(userId: string, localDate: string = LOCAL_DATE) {
  return {
    id: localDate,
    userId,
    localDate,
    timezone: "America/Los_Angeles",
    calorieTarget: 2000,
    proteinTarget: 140,
    carbTarget: 180,
    fatTarget: 65,
    waterTargetMl: 2500,
    aggressiveness: "moderate",
    caloriesConsumed: 0,
    proteinConsumed: 0,
    carbsConsumed: 0,
    fatConsumed: 0,
    waterConsumedMl: 0,
    workoutCaloriesBurned: 0,
    schemaVersion: 1,
    source: "ios_forma",
    ...accountTimestamps(),
  };
}

export function foodEntryPayload(userId: string, localDate: string = LOCAL_DATE) {
  return {
    id: "food-entry-1",
    userId,
    dailyLogId: "daily-log-1",
    localDate,
    name: "Oatmeal",
    calories: 320,
    protein: 12,
    carbs: 54,
    fat: 6,
    source: "manual",
    confidence: "high",
    schemaVersion: 1,
    ...accountTimestamps(),
  };
}

export function waterEntryPayload(userId: string, localDate: string = LOCAL_DATE) {
  return {
    id: "water-entry-1",
    userId,
    dailyLogId: "daily-log-1",
    localDate,
    amountMl: 250,
    schemaVersion: 1,
    ...accountTimestamps(),
  };
}

export function weightEntryPayload(userId: string, localDate: string = LOCAL_DATE) {
  return {
    id: "weight-entry-1",
    userId,
    localDate,
    weightKg: 68.2,
    schemaVersion: 1,
    ...accountTimestamps(),
  };
}

export function dailyReviewPayload(userId: string, localDate: string = LOCAL_DATE) {
  return {
    id: "review-1",
    userId,
    dailyLogId: "daily-log-1",
    localDate,
    summaryText: "Solid day",
    caloriesSummary: "On target",
    proteinSummary: "High",
    hydrationSummary: "Good",
    tomorrowRecommendation: "Repeat",
    schemaVersion: 1,
    ...accountTimestamps(),
  };
}

export function syncMetadataPayload(userId: string) {
  return {
    userId,
    schemaVersion: 1,
    lastDeviceId: "test-device",
    clientVersion: "1.0.0",
    updatedAt: Timestamp.now(),
  };
}

export function profilePayload() {
  return {
    age: 30,
    sex: "female",
    heightCm: 165,
    currentWeightKg: 68,
    goalWeightKg: 62,
    activityLevel: "moderatelyActive",
    trainingFrequencyPerWeek: 3,
    averageSteps: 8000,
    unitSystem: "metric",
    targets: {
      calorieTarget: 2000,
      proteinTarget: 140,
      carbTarget: 180,
      fatTarget: 65,
      waterTargetMl: 2500,
      aggressiveness: "moderate",
    },
    onboardingCompletedAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
}

export const accountPersistencePaths = {
  profile: (userId: string) => `users/${userId}/profile/current`,
  dailyLog: (userId: string, localDate: string = LOCAL_DATE) =>
    `users/${userId}/dailyLogs/${localDate}`,
  foodEntry: (userId: string, localDate: string = LOCAL_DATE) =>
    `users/${userId}/dailyLogs/${localDate}/foodEntries/food-entry-1`,
  waterEntry: (userId: string, localDate: string = LOCAL_DATE) =>
    `users/${userId}/dailyLogs/${localDate}/waterEntries/water-entry-1`,
  weightEntry: (userId: string) => `users/${userId}/weightEntries/weight-entry-1`,
  dailyReview: (userId: string, localDate: string = LOCAL_DATE) =>
    `users/${userId}/dailyReviews/${localDate}`,
  syncMetadata: (userId: string) => `users/${userId}/syncMetadata/current`,
};
