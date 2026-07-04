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
});
