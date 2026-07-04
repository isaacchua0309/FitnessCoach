import {readFileSync} from "node:fs";
import {resolve} from "node:path";
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  RulesTestEnvironment,
} from "@firebase/rules-unit-testing";
import {doc, getDoc, setDoc, Timestamp} from "firebase/firestore";

const PROJECT_ID = "forma-nutrition-sync-rules-test";

describe("nutrition sync firestore rules", () => {
  let testEnv: RulesTestEnvironment;

  const baseDailyLog = {
    id: "2026-07-03",
    userId: "user-a",
    localDate: "2026-07-03",
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
    updatedAt: Timestamp.now(),
    createdAt: Timestamp.now(),
    source: "ios_forma",
  };

  const baseFoodEntry = {
    id: "food-entry-1",
    userId: "user-a",
    dailyLogId: "daily-log-1",
    localDate: "2026-07-03",
    name: "Oatmeal",
    calories: 320,
    protein: 12,
    carbs: 54,
    fat: 6,
    source: "manual",
    confidence: "high",
    schemaVersion: 1,
    updatedAt: Timestamp.now(),
    createdAt: Timestamp.now(),
  };

  beforeAll(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: readFileSync(resolve(__dirname, "../../firestore.rules"), "utf8"),
        host: "127.0.0.1",
        port: 8080,
      },
    });
  });

  afterAll(async () => {
    await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
  });

  it("allows owner read/write on own daily log", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const ref = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03"
    );

    await assertSucceeds(setDoc(ref, baseDailyLog));
    await assertSucceeds(getDoc(ref));
  });

  it("denies cross-user read on daily logs", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const bob = testEnv.authenticatedContext("user-b");
    const ref = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03"
    );

    await assertSucceeds(setDoc(ref, baseDailyLog));
    await assertFails(getDoc(doc(bob.firestore(), "users/user-a/dailyLogs/2026-07-03")));
  });

  it("denies writes when userId does not match auth uid", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const ref = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03"
    );

    await assertFails(
      setDoc(ref, {
        ...baseDailyLog,
        userId: "user-b",
      })
    );
  });

  it("allows owner read/write on food subcollection", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const dailyRef = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03"
    );
    const foodRef = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03/foodEntries/food-entry-1"
    );

    await assertSucceeds(setDoc(dailyRef, baseDailyLog));
    await assertSucceeds(setDoc(foodRef, baseFoodEntry));
    await assertSucceeds(getDoc(foodRef));
  });

  it("denies cross-user read on food subcollection", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const bob = testEnv.authenticatedContext("user-b");
    const foodRef = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03/foodEntries/food-entry-1"
    );

    await assertSucceeds(setDoc(foodRef, baseFoodEntry));
    await assertFails(
      getDoc(
        doc(
          bob.firestore(),
          "users/user-a/dailyLogs/2026-07-03/foodEntries/food-entry-1"
        )
      )
    );
  });

  it("allows owner read/write on sync metadata", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const ref = doc(alice.firestore(), "users/user-a/syncMetadata/current");

    await assertSucceeds(
      setDoc(ref, {
        userId: "user-a",
        schemaVersion: 1,
        lastDeviceId: "test-device",
        clientVersion: "1.0.0",
        updatedAt: Timestamp.now(),
      })
    );
    await assertSucceeds(getDoc(ref));
  });

  it("denies unauthenticated access to nutrition collections", async () => {
    const unauth = testEnv.unauthenticatedContext();
    const ref = doc(
      unauth.firestore(),
      "users/user-a/dailyLogs/2026-07-03"
    );

    await assertFails(setDoc(ref, baseDailyLog));
    await assertFails(getDoc(ref));
  });

  it("denies daily log writes with invalid date document id", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const ref = doc(alice.firestore(), "users/user-a/dailyLogs/not-a-date");

    await assertFails(setDoc(ref, {
      ...baseDailyLog,
      id: "not-a-date",
      localDate: "not-a-date",
    }));
  });

  it("denies daily log writes when localDate does not match document id", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const ref = doc(alice.firestore(), "users/user-a/dailyLogs/2026-07-03");

    await assertFails(setDoc(ref, {
      ...baseDailyLog,
      localDate: "2026-07-04",
    }));
  });

  it("allows owner read/write on water subcollection", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const waterRef = doc(
      alice.firestore(),
      "users/user-a/dailyLogs/2026-07-03/waterEntries/water-entry-1"
    );

    await assertSucceeds(setDoc(waterRef, {
      id: "water-entry-1",
      userId: "user-a",
      dailyLogId: "daily-log-1",
      localDate: "2026-07-03",
      amountMl: 250,
      schemaVersion: 1,
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    }));
    await assertSucceeds(getDoc(waterRef));
  });

  it("allows owner read/write on weight entries and daily reviews", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const weightRef = doc(alice.firestore(), "users/user-a/weightEntries/weight-1");
    const reviewRef = doc(alice.firestore(), "users/user-a/dailyReviews/2026-07-03");

    await assertSucceeds(setDoc(weightRef, {
      id: "weight-1",
      userId: "user-a",
      localDate: "2026-07-03",
      weightKg: 68.2,
      schemaVersion: 1,
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    }));
    await assertSucceeds(setDoc(reviewRef, {
      id: "review-1",
      userId: "user-a",
      dailyLogId: "daily-log-1",
      localDate: "2026-07-03",
      summaryText: "Solid day",
      caloriesSummary: "On target",
      proteinSummary: "High",
      hydrationSummary: "Good",
      tomorrowRecommendation: "Repeat",
      schemaVersion: 1,
      updatedAt: Timestamp.now(),
      createdAt: Timestamp.now(),
    }));
  });

  it("preserves owner profile read/write", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const bob = testEnv.authenticatedContext("user-b");
    const profileRef = doc(alice.firestore(), "users/user-a/profile/current");

    await assertSucceeds(setDoc(profileRef, {
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
    }));
    await assertSucceeds(getDoc(profileRef));
    await assertFails(getDoc(doc(bob.firestore(), "users/user-a/profile/current")));
  });

  it("allows owner read/write on health daily summaries", async () => {
    const alice = testEnv.authenticatedContext("user-a");
    const bob = testEnv.authenticatedContext("user-b");
    const ref = doc(alice.firestore(), "users/user-a/healthDaily/2026-07-03");

    await assertSucceeds(setDoc(ref, {
      id: "2026-07-03",
      userId: "user-a",
      localDate: "2026-07-03",
      schemaVersion: 1,
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(getDoc(ref));
    await assertFails(getDoc(doc(bob.firestore(), "users/user-a/healthDaily/2026-07-03")));
  });
});
