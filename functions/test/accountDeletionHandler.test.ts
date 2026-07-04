import {createMockRequest, createMockResponse} from "./helpers/mockHttp";
import {resetAccountDeletionGuardrailsForTests} from "../src/accountDeletion/accountDeletionGuardrails";

const verifyIdTokenMock = jest.fn();
const deleteAccountFirestoreDataMock = jest.fn();

jest.mock("firebase-admin/app", () => ({
  initializeApp: jest.fn(),
}));

jest.mock("firebase-admin/auth", () => ({
  getAuth: jest.fn(() => ({
    verifyIdToken: verifyIdTokenMock,
  })),
}));

jest.mock("firebase-functions", () => ({
  logger: {
    info: jest.fn(),
    warn: jest.fn(),
    error: jest.fn(),
  },
  setGlobalOptions: jest.fn(),
}));

jest.mock("firebase-functions/v2/https", () => ({
  onRequest: jest.fn((_options: unknown, handler: unknown) => handler),
}));

jest.mock("../src/accountDeletion/accountDeletionService", () => ({
  deleteAccountFirestoreData: deleteAccountFirestoreDataMock,
}));

import {handleAccountDeletionRequest} from "../src/accountDeletion/accountDeletionHandler";

const DELETE_PATH = "/v1/account/delete-data";

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

describe("account deletion handler", () => {
  beforeEach(() => {
    jest.clearAllMocks();
    resetAccountDeletionGuardrailsForTests();
    verifyIdTokenMock.mockResolvedValue({uid: "user-a"});
    deleteAccountFirestoreDataMock.mockResolvedValue({
      deleted: completedDeletion,
      completed: true,
    });
  });

  it("returns 401 when unauthenticated", async () => {
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

  it("uses verified uid and ignores any client-supplied uid", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "DELETE", uid: "user-b", userId: "user-b"},
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

  it("userA cannot delete userB because only verified uid is used", async () => {
    verifyIdTokenMock.mockResolvedValue({uid: "user-a"});

    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer user-a-token"},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(200);
    expect(deleteAccountFirestoreDataMock).toHaveBeenCalledWith(
      "user-a",
      expect.any(Object)
    );
    expect(response.body).toEqual({
      ok: true,
      uid: "user-a",
      deleted: completedDeletion,
    });
  });

  it("requires the confirmation phrase", async () => {
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

  it("returns deletion counts on success", async () => {
    const request = createMockRequest({
      path: DELETE_PATH,
      headers: {Authorization: "Bearer test-token"},
      body: {confirmation: "DELETE"},
    });
    const response = createMockResponse();

    await handleAccountDeletionRequest(request, response);

    expect(response.statusCode).toBe(200);
    expect(response.body).toEqual({
      ok: true,
      uid: "user-a",
      deleted: completedDeletion,
    });
  });
});
