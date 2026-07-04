/**
 * Phase 6 account deletion — backend endpoint, Firestore deletion service, and logging security.
 *
 * Security model:
 * - Client Firestore rules enforce owner-only access; cross-user deletes are denied
 *   (see accountPersistenceFirestoreRules.test.ts — "account deletion client rules security").
 * - Backend POST /v1/account/delete-data uses firebase-admin (service account IAM), not client rules.
 * - The handler always deletes using the verified Firebase ID token uid; client-supplied uid is rejected.
 * - Logs use privacy-safe uid hashes and deletion counts only — never raw document payloads.
 */
import {createMockRequest, createMockResponse} from "./helpers/mockHttp";
import {resetAccountDeletionGuardrailsForTests} from "../src/accountDeletion/accountDeletionGuardrails";
import {
  AccountDeletionCollection,
  CURRENT_DOCUMENT_ID,
  userCollectionPath,
  userDocumentPath,
} from "../src/accountDeletion/accountDeletionPaths";
import {createInMemoryFirestoreHarness} from "./helpers/inMemoryFirestore";

const verifyIdTokenMock = jest.fn();

jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: jest.fn(() => ({
    verifyIdToken: verifyIdTokenMock,
  })),
}));

const loggerInfoMock = jest.fn();
const loggerErrorMock = jest.fn();

jest.mock("firebase-functions", () => ({
  logger: {
    info: loggerInfoMock,
    warn: jest.fn(),
    error: loggerErrorMock,
  },
  setGlobalOptions: jest.fn(),
}));

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn((_options: unknown, handler: unknown) => handler),
}));

import * as AccountDeletionService from "../src/accountDeletion/accountDeletionService";
import {handleAccountDeletionRequest} from "../src/accountDeletion/accountDeletionHandler";

const DELETE_PATH = "/v1/account/delete-data";
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

const completedDeletion = {
  profile: true,
  dailyLogs: 2,
  foodEntries: 3,
  waterEntries: 1,
  weightEntries: 1,
  dailyReviews: 1,
  syncMetadata: true,
  healthDaily: 0,
  healthWorkouts: 0,
  healthRecovery: 0,
  healthWeeklyReviews: 0,
  healthSyncMetadata: false,
};

const SENSITIVE_FOOD_NAME = "Secret-Oatmeal-Payload-9f3a";

describe("account deletion backend endpoint", () => {
  let deleteAccountFirestoreDataMock: jest.SpiedFunction<
    typeof AccountDeletionService.deleteAccountFirestoreData
  >;

  beforeEach(() => {
    jest.clearAllMocks();
    resetAccountDeletionGuardrailsForTests();
    verifyIdTokenMock.mockResolvedValue({uid: USER_A});
    deleteAccountFirestoreDataMock = jest
      .spyOn(AccountDeletionService, "deleteAccountFirestoreData")
      .mockResolvedValue({
        deleted: completedDeletion,
        completed: true,
      });
  });

  afterEach(() => {
    deleteAccountFirestoreDataMock.mockRestore();
  });

  it("unauthenticatedRequestIsDenied", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(401);
    expect(response.body).toEqual({
      error: "Missing Firebase ID token.",
      backendErrorCategory: "authentication",
    });
    expect(deleteAccountFirestoreDataMock).not.toHaveBeenCalled();
  });

  it("missingConfirmationIsDenied", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      error: 'Confirmation phrase must be exactly "DELETE".',
      backendErrorCategory: "validation",
    });
    expect(deleteAccountFirestoreDataMock).not.toHaveBeenCalled();
  });

  it("wrongConfirmationIsDenied", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "delete"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      error: 'Confirmation phrase must be exactly "DELETE".',
      backendErrorCategory: "validation",
    });
    expect(deleteAccountFirestoreDataMock).not.toHaveBeenCalled();
  });

  it("deleteUsesVerifiedAuthUidNotClientUid", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "DELETE", uid: USER_B, userId: USER_B},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(400);
    expect(response.body).toEqual({
      error: "Client-supplied uid is not accepted.",
      backendErrorCategory: "validation",
    });
    expect(deleteAccountFirestoreDataMock).not.toHaveBeenCalled();
  });

  it("userACannotDeleteUserBData", async () => {
    verifyIdTokenMock.mockResolvedValue({uid: USER_A});

    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer user-a-token"},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(200);
    expect(deleteAccountFirestoreDataMock).toHaveBeenCalledWith(
      USER_A,
      expect.any(Object)
    );
    expect(deleteAccountFirestoreDataMock).not.toHaveBeenCalledWith(
      USER_B,
      expect.any(Object)
    );
  });

  it("partialFailureReturnsSafePartialResult", async () => {
    deleteAccountFirestoreDataMock.mockResolvedValue({
      deleted: {
        ...completedDeletion,
        profile: false,
        weightEntries: 0,
        dailyReviews: 0,
        syncMetadata: false,
      },
      completed: false,
    });

    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(503);
    expect(response.body).toEqual({
      ok: false,
      uid: USER_A,
      deleted: {
        ...completedDeletion,
        profile: false,
        weightEntries: 0,
        dailyReviews: 0,
        syncMetadata: false,
      },
      backendErrorCategory: "timeout",
    });
  });

  it("logsDoNotIncludeDocumentPayloads", async () => {
    deleteAccountFirestoreDataMock.mockResolvedValue({
      deleted: completedDeletion,
      completed: true,
    });

    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(200);

    const serializedLogs = JSON.stringify([
      ...loggerInfoMock.mock.calls,
      ...loggerErrorMock.mock.calls,
    ]);

    expect(serializedLogs).not.toContain(SENSITIVE_FOOD_NAME);
    expect(serializedLogs).not.toContain(USER_A);
    expect(serializedLogs).not.toContain(USER_B);
    expect(serializedLogs).not.toContain("users/");
    expect(serializedLogs).toContain("uidHash");
    expect(serializedLogs).toContain("deletedCounts");
  });
});

describe("account deletion firestore service", () => {
  const {deleteAccountFirestoreData} = AccountDeletionService;

  it("backendDeletionUsesAdminFirestoreNotClientRules", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.profile(USER_A), {name: "Admin path"});

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.completed).toBe(true);
    expect(result.deleted.profile).toBe(true);
    expect(harness.documentExists(accountPersistencePaths.profile(USER_A))).toBe(false);
  });

  it("deleteRemovesProfile", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.profile(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.profile).toBe(true);
    expect(harness.documentExists(accountPersistencePaths.profile(USER_A))).toBe(false);
  });

  it("deleteRemovesDailyLogs", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.dailyLog(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.dailyLogs).toBe(1);
    expect(harness.documentExists(accountPersistencePaths.dailyLog(USER_A))).toBe(false);
  });

  it("deleteRemovesFoodSubcollections", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.dailyLog(USER_A));
    harness.seedDocument(accountPersistencePaths.foodEntry(USER_A), {
      name: SENSITIVE_FOOD_NAME,
    });

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.foodEntries).toBe(1);
    expect(harness.documentExists(accountPersistencePaths.foodEntry(USER_A))).toBe(false);
  });

  it("deleteRemovesWaterSubcollections", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.dailyLog(USER_A));
    harness.seedDocument(accountPersistencePaths.waterEntry(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.waterEntries).toBe(1);
    expect(harness.documentExists(accountPersistencePaths.waterEntry(USER_A))).toBe(false);
  });

  it("deleteRemovesWeightEntries", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.weightEntry(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.weightEntries).toBe(1);
    expect(harness.documentExists(accountPersistencePaths.weightEntry(USER_A))).toBe(false);
  });

  it("deleteRemovesDailyReviews", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.dailyReview(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.dailyReviews).toBe(1);
    expect(harness.documentExists(accountPersistencePaths.dailyReview(USER_A))).toBe(false);
  });

  it("deleteRemovesSyncMetadata", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.syncMetadata(USER_A));

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted.syncMetadata).toBe(true);
    expect(harness.documentExists(accountPersistencePaths.syncMetadata(USER_A))).toBe(false);
  });

  it("deleteRemovesHealthSummaryCollections", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(
      userDocumentPath(USER_A, AccountDeletionCollection.healthDaily, LOCAL_DATE)
    );
    harness.seedDocument(
      userDocumentPath(USER_A, AccountDeletionCollection.healthWorkouts, "workout-1")
    );
    harness.seedDocument(
      userDocumentPath(USER_A, AccountDeletionCollection.healthRecovery, LOCAL_DATE)
    );
    harness.seedDocument(
      userDocumentPath(USER_A, AccountDeletionCollection.healthWeeklyReviews, "2026-W27")
    );
    harness.seedDocument(
      userDocumentPath(USER_A, AccountDeletionCollection.healthSyncMetadata, CURRENT_DOCUMENT_ID)
    );

    const result = await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expect(result.deleted).toMatchObject({
      healthDaily: 1,
      healthWorkouts: 1,
      healthRecovery: 1,
      healthWeeklyReviews: 1,
      healthSyncMetadata: true,
    });
    expect(
      harness.listDirectChildDocumentPaths(
        userCollectionPath(USER_A, AccountDeletionCollection.healthDaily)
      )
    ).toHaveLength(0);
    expect(
      harness.listDirectChildDocumentPaths(
        userCollectionPath(USER_A, AccountDeletionCollection.healthWorkouts)
      )
    ).toHaveLength(0);
    expect(
      harness.documentExists(
        userDocumentPath(USER_A, AccountDeletionCollection.healthSyncMetadata, CURRENT_DOCUMENT_ID)
      )
    ).toBe(false);
  });

  it("deleteLeavesOtherUserDataIntact", async () => {
    const harness = createInMemoryFirestoreHarness();
    seedFullUserAccountData(harness, USER_A);
    seedFullUserAccountData(harness, USER_B);

    await deleteAccountFirestoreData(USER_A, {}, harness.db);

    expectUserAccountDataAbsent(harness, USER_A);
    expectUserAccountDataPresent(harness, USER_B);
  });

  it("deleteMissingDataReturnsSuccess", async () => {
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

  it("partialFailureKeepsUnprocessedDataWhenDeadlineExpires", async () => {
    const harness = createInMemoryFirestoreHarness();
    harness.seedDocument(accountPersistencePaths.weightEntry(USER_A));
    harness.seedDocument(accountPersistencePaths.profile(USER_A));

    const result = await deleteAccountFirestoreData(
      USER_A,
      {
        startedAtMs: Date.now() - 60_000,
        deadlineMs: 1,
      },
      harness.db
    );

    expect(result.completed).toBe(false);
    expect(harness.documentExists(accountPersistencePaths.weightEntry(USER_A))).toBe(true);
    expect(harness.documentExists(accountPersistencePaths.profile(USER_A))).toBe(true);
  });
});

function seedFullUserAccountData(
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
