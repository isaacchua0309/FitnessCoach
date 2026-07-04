import {
  AccountDeletionCollection,
  CURRENT_DOCUMENT_ID,
  userCollectionPath,
  userDocumentPath,
} from "../src/accountDeletion/accountDeletionPaths";
import {deleteAccountFirestoreData} from "../src/accountDeletion/accountDeletionService";
import {createInMemoryFirestoreHarness} from "./helpers/inMemoryFirestore";

const USER_A = "userA";
const USER_B = "userB";
const LOCAL_DATE = "2026-07-04";

const accountPersistencePaths = {
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

describe("account deletion service", () => {
  it("deletes all expected subcollections for userA", async () => {
    const harness = createInMemoryFirestoreHarness();
    seedUserAccountData(harness, USER_A);

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.completed).toBe(true);
    expect(result.deleted).toEqual({
      profile: true,
      dailyLogs: 1,
      foodEntries: 1,
      waterEntries: 1,
      weightEntries: 1,
      dailyReviews: 1,
      syncMetadata: true,
      healthDaily: 1,
      healthWorkouts: 1,
      healthRecovery: 1,
      healthWeeklyReviews: 1,
      healthSyncMetadata: true,
    });
    expectUserAccountDataAbsent(harness, USER_A);
  });

  it("leaves userB data intact when deleting userA", async () => {
    const harness = createInMemoryFirestoreHarness();
    seedUserAccountData(harness, USER_A);
    seedUserAccountData(harness, USER_B);

    await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expectUserAccountDataAbsent(harness, USER_A);
    expectUserAccountDataPresent(harness, USER_B);
  });

  it("treats missing data as success", async () => {
    const harness = createInMemoryFirestoreHarness();

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.completed).toBe(true);
    expect(result.deleted).toEqual({
      profile: false,
      dailyLogs: 0,
      foodEntries: 0,
      waterEntries: 0,
      weightEntries: 0,
      dailyReviews: 0,
      syncMetadata: false,
      healthDaily: 0,
      healthWorkouts: 0,
      healthRecovery: 0,
      healthWeeklyReviews: 0,
      healthSyncMetadata: false,
    });
  });
});

function seedUserAccountData(
  harness: ReturnType<typeof createInMemoryFirestoreHarness>,
  uid: string
): void {
  harness.seedDocument(accountPersistencePaths.profile(uid));
  harness.seedDocument(accountPersistencePaths.dailyLog(uid, LOCAL_DATE));
  harness.seedDocument(accountPersistencePaths.foodEntry(uid, LOCAL_DATE));
  harness.seedDocument(accountPersistencePaths.waterEntry(uid, LOCAL_DATE));
  harness.seedDocument(accountPersistencePaths.weightEntry(uid));
  harness.seedDocument(accountPersistencePaths.dailyReview(uid, LOCAL_DATE));
  harness.seedDocument(accountPersistencePaths.syncMetadata(uid));
  harness.seedDocument(
    userDocumentPath(uid, AccountDeletionCollection.healthDaily, LOCAL_DATE)
  );
  harness.seedDocument(
    userDocumentPath(uid, AccountDeletionCollection.healthWorkouts, "workout-1")
  );
  harness.seedDocument(
    userDocumentPath(uid, AccountDeletionCollection.healthRecovery, LOCAL_DATE)
  );
  harness.seedDocument(
    userDocumentPath(uid, AccountDeletionCollection.healthWeeklyReviews, "2026-W27")
  );
  harness.seedDocument(
    userDocumentPath(uid, AccountDeletionCollection.healthSyncMetadata, CURRENT_DOCUMENT_ID)
  );
}

function expectUserAccountDataAbsent(
  harness: ReturnType<typeof createInMemoryFirestoreHarness>,
  uid: string
): void {
  expect(harness.documentExists(accountPersistencePaths.profile(uid))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.dailyLog(uid, LOCAL_DATE))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.foodEntry(uid, LOCAL_DATE))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.waterEntry(uid, LOCAL_DATE))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.weightEntry(uid))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.dailyReview(uid, LOCAL_DATE))).toBe(false);
  expect(harness.documentExists(accountPersistencePaths.syncMetadata(uid))).toBe(false);
  expect(
    harness.listDirectChildDocumentPaths(
      userCollectionPath(uid, AccountDeletionCollection.healthDaily)
    )
  ).toHaveLength(0);
  expect(
    harness.listDirectChildDocumentPaths(
      userCollectionPath(uid, AccountDeletionCollection.healthWorkouts)
    )
  ).toHaveLength(0);
}

function expectUserAccountDataPresent(
  harness: ReturnType<typeof createInMemoryFirestoreHarness>,
  uid: string
): void {
  expect(harness.documentExists(accountPersistencePaths.profile(uid))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.dailyLog(uid, LOCAL_DATE))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.foodEntry(uid, LOCAL_DATE))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.waterEntry(uid, LOCAL_DATE))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.weightEntry(uid))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.dailyReview(uid, LOCAL_DATE))).toBe(true);
  expect(harness.documentExists(accountPersistencePaths.syncMetadata(uid))).toBe(true);
}
