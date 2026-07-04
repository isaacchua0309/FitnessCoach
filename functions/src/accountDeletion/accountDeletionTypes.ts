/* eslint-disable max-len, require-jsdoc, valid-jsdoc */
/** Counts returned after deleting UID-scoped Firestore account data. */
export interface AccountDeletionDeletedCounts {
  profile: boolean;
  dailyLogs: number;
  foodEntries: number;
  waterEntries: number;
  weightEntries: number;
  dailyReviews: number;
  syncMetadata: boolean;
  healthDaily: number;
  healthWorkouts: number;
  healthRecovery: number;
  healthWeeklyReviews: number;
  healthSyncMetadata: boolean;
}

export interface AccountDeletionSuccessResponse {
  ok: true;
  uid: string;
  deleted: AccountDeletionDeletedCounts;
}

export interface AccountDeletionPartialResponse {
  ok: false;
  uid: string;
  deleted: AccountDeletionDeletedCounts;
  backendErrorCategory: string;
}

export type AccountDeletionResponse =
  | AccountDeletionSuccessResponse
  | AccountDeletionPartialResponse;

export interface DeleteAccountDataRequest {
  confirmation: string;
}

export interface DeletionRunOptions {
  startedAtMs?: number;
  deadlineMs?: number;
  pageSize?: number;
  dailyLogPageSize?: number;
}

export function emptyDeletionCounts(): AccountDeletionDeletedCounts {
  return {
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
  };
}
