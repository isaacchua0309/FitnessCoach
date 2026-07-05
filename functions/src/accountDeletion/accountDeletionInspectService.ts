/* eslint-disable max-len, require-jsdoc, valid-jsdoc */
import {getFirestore, type Firestore} from "firebase-admin/firestore";
import {
  AccountDeletionCollection,
  healthSyncMetadataDocumentPath,
  profileDocumentPath,
  syncMetadataDocumentPath,
  userCollectionPath,
} from "./accountDeletionPaths";
import {
  ACCOUNT_DELETION_WOULD_DELETE_GROUPS,
  type AccountDeletionWouldDeleteGroup,
} from "./accountDeletionTypes";

const DEFAULT_PAGE_SIZE = 400;

async function countCollectionDocuments(
  collectionRef: FirebaseFirestore.CollectionReference,
  pageSize: number = DEFAULT_PAGE_SIZE
): Promise<number> {
  let total = 0;

  while (true) {
    const snapshot = await collectionRef.limit(pageSize).get();
    if (snapshot.empty) {
      break;
    }

    total += snapshot.size;
    if (snapshot.size < pageSize) {
      break;
    }
  }

  return total;
}

async function singletonDocumentExists(
  documentRef: FirebaseFirestore.DocumentReference
): Promise<boolean> {
  const snapshot = await documentRef.get();
  return snapshot.exists;
}

async function countDailyLogSubcollections(
  db: Firestore,
  uid: string,
  pageSize: number = DEFAULT_PAGE_SIZE
): Promise<{dailyLogs: number; foodEntries: number; waterEntries: number}> {
  const dailyLogsRef = db.collection(userCollectionPath(uid, AccountDeletionCollection.dailyLogs));
  let dailyLogs = 0;
  let foodEntries = 0;
  let waterEntries = 0;

  while (true) {
    const snapshot = await dailyLogsRef.limit(pageSize).get();
    if (snapshot.empty) {
      break;
    }

    for (const dailyLogDocument of snapshot.docs) {
      foodEntries += await countCollectionDocuments(
        dailyLogDocument.ref.collection(AccountDeletionCollection.foodEntries),
        pageSize
      );
      waterEntries += await countCollectionDocuments(
        dailyLogDocument.ref.collection(AccountDeletionCollection.waterEntries),
        pageSize
      );
      dailyLogs += 1;
    }

    if (snapshot.size < pageSize) {
      break;
    }
  }

  return {dailyLogs, foodEntries, waterEntries};
}

export interface AccountDeletionInspectResult {
  wouldDeleteGroups: AccountDeletionWouldDeleteGroup[];
}

/**
 * Counts UID-scoped Firestore account data that would be deleted without mutating documents.
 */
export async function inspectAccountFirestoreData(
  uid: string,
  db: Firestore = getFirestore()
): Promise<AccountDeletionInspectResult> {
  const wouldDeleteGroups: AccountDeletionWouldDeleteGroup[] = [];

  const [
    profileExists,
    syncMetadataExists,
    dailyLogCounts,
    weightEntries,
    dailyReviews,
    healthDaily,
    healthWorkouts,
    healthRecovery,
    healthWeeklyReviews,
    healthSyncMetadataExists,
  ] = await Promise.all([
    singletonDocumentExists(db.doc(profileDocumentPath(uid))),
    singletonDocumentExists(db.doc(syncMetadataDocumentPath(uid))),
    countDailyLogSubcollections(db, uid),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.weightEntries))
    ),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.dailyReviews))
    ),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.healthDaily))
    ),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.healthWorkouts))
    ),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.healthRecovery))
    ),
    countCollectionDocuments(
      db.collection(userCollectionPath(uid, AccountDeletionCollection.healthWeeklyReviews))
    ),
    singletonDocumentExists(db.doc(healthSyncMetadataDocumentPath(uid))),
  ]);

  if (profileExists) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.profile);
  }
  if (syncMetadataExists) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.syncMetadata);
  }
  if (
    dailyLogCounts.dailyLogs > 0 ||
    dailyLogCounts.foodEntries > 0 ||
    dailyLogCounts.waterEntries > 0
  ) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.dailyLogs);
  }
  if (weightEntries > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.weightEntries);
  }
  if (dailyReviews > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.dailyReviews);
  }
  if (healthDaily > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.healthDaily);
  }
  if (healthWorkouts > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.healthWorkouts);
  }
  if (healthRecovery > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.healthRecovery);
  }
  if (healthWeeklyReviews > 0) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.healthWeeklyReviews);
  }
  if (healthSyncMetadataExists) {
    wouldDeleteGroups.push(ACCOUNT_DELETION_WOULD_DELETE_GROUPS.healthSyncMetadata);
  }

  return {wouldDeleteGroups};
}
