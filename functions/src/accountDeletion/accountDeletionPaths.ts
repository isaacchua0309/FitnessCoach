/* eslint-disable max-len, require-jsdoc */
/** Canonical Firestore paths under `users/{uid}/` for account deletion. */
export const ACCOUNT_DELETION_CONFIRMATION_PHRASE = "DELETE";

export const ACCOUNT_DELETE_DATA_PATH = "/v1/account/delete-data";

export const AccountDeletionCollection = {
  profile: "profile",
  syncMetadata: "syncMetadata",
  dailyLogs: "dailyLogs",
  foodEntries: "foodEntries",
  waterEntries: "waterEntries",
  weightEntries: "weightEntries",
  dailyReviews: "dailyReviews",
  healthDaily: "healthDaily",
  healthWorkouts: "healthWorkouts",
  healthRecovery: "healthRecovery",
  healthWeeklyReviews: "healthWeeklyReviews",
  healthSyncMetadata: "healthSyncMetadata",
} as const;

export const CURRENT_DOCUMENT_ID = "current";

export function userRootPath(uid: string): string {
  return `users/${uid}`;
}

export function userCollectionPath(uid: string, collection: string): string {
  return `${userRootPath(uid)}/${collection}`;
}

export function userDocumentPath(
  uid: string,
  collection: string,
  documentId: string
): string {
  return `${userCollectionPath(uid, collection)}/${documentId}`;
}

export function profileDocumentPath(uid: string): string {
  return userDocumentPath(uid, AccountDeletionCollection.profile, CURRENT_DOCUMENT_ID);
}

export function syncMetadataDocumentPath(uid: string): string {
  return userDocumentPath(
    uid,
    AccountDeletionCollection.syncMetadata,
    CURRENT_DOCUMENT_ID
  );
}

export function healthSyncMetadataDocumentPath(uid: string): string {
  return userDocumentPath(
    uid,
    AccountDeletionCollection.healthSyncMetadata,
    CURRENT_DOCUMENT_ID
  );
}
