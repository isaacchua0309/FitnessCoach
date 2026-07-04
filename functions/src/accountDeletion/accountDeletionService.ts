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
  type AccountDeletionDeletedCounts,
  type DeletionRunOptions,
  emptyDeletionCounts,
} from "./accountDeletionTypes";

const DEFAULT_PAGE_SIZE = 400;
const DEFAULT_DAILY_LOG_PAGE_SIZE = 25;
const DEFAULT_DEADLINE_MS = 50_000;

type CollectionReference = FirebaseFirestore.CollectionReference;
type DocumentReference = FirebaseFirestore.DocumentReference;

function resolveDeadline(options: DeletionRunOptions): number {
  if (options.deadlineMs !== undefined) {
    return (options.startedAtMs ?? Date.now()) + options.deadlineMs;
  }
  return (options.startedAtMs ?? Date.now()) + DEFAULT_DEADLINE_MS;
}

function isPastDeadline(deadlineMs: number): boolean {
  return Date.now() >= deadlineMs;
}

async function deleteCollectionDocuments(
  db: Firestore,
  collectionRef: CollectionReference,
  pageSize: number,
  deadlineMs: number
): Promise<number> {
  let deleted = 0;

  while (!isPastDeadline(deadlineMs)) {
    const snapshot = await collectionRef.limit(pageSize).get();
    if (snapshot.empty) {
      break;
    }

    const batch = db.batch();
    for (const document of snapshot.docs) {
      batch.delete(document.ref);
    }
    await batch.commit();
    deleted += snapshot.size;

    if (snapshot.size < pageSize) {
      break;
    }
  }

  return deleted;
}

async function deleteSingletonDocument(
  documentRef: DocumentReference
): Promise<boolean> {
  const snapshot = await documentRef.get();
  if (!snapshot.exists) {
    return false;
  }
  await documentRef.delete();
  return true;
}

async function deleteDailyLogsWithSubcollections(
  db: Firestore,
  uid: string,
  pageSize: number,
  dailyLogPageSize: number,
  deadlineMs: number
): Promise<Pick<AccountDeletionDeletedCounts, "dailyLogs" | "foodEntries" | "waterEntries">> {
  const dailyLogsRef = db.collection(userCollectionPath(uid, AccountDeletionCollection.dailyLogs));
  let dailyLogs = 0;
  let foodEntries = 0;
  let waterEntries = 0;

  while (!isPastDeadline(deadlineMs)) {
    const snapshot = await dailyLogsRef.limit(dailyLogPageSize).get();
    if (snapshot.empty) {
      break;
    }

    for (const dailyLogDocument of snapshot.docs) {
      if (isPastDeadline(deadlineMs)) {
        break;
      }

      foodEntries += await deleteCollectionDocuments(
        db,
        dailyLogDocument.ref.collection(AccountDeletionCollection.foodEntries),
        pageSize,
        deadlineMs
      );
      waterEntries += await deleteCollectionDocuments(
        db,
        dailyLogDocument.ref.collection(AccountDeletionCollection.waterEntries),
        pageSize,
        deadlineMs
      );
      await dailyLogDocument.ref.delete();
      dailyLogs += 1;
    }

    if (snapshot.size < dailyLogPageSize) {
      break;
    }
  }

  return {dailyLogs, foodEntries, waterEntries};
}

export interface AccountDeletionRunResult {
  deleted: AccountDeletionDeletedCounts;
  completed: boolean;
}

/**
 * Deletes all UID-scoped Forma account Firestore data for the authenticated user.
 * Uses paginated batched deletes and stops when the deadline is reached.
 */
export async function deleteAccountFirestoreData(
  uid: string,
  options: DeletionRunOptions = {},
  db: Firestore = getFirestore()
): Promise<AccountDeletionRunResult> {
  const pageSize = options.pageSize ?? DEFAULT_PAGE_SIZE;
  const dailyLogPageSize = options.dailyLogPageSize ?? DEFAULT_DAILY_LOG_PAGE_SIZE;
  const deadlineMs = resolveDeadline(options);
  const deleted = emptyDeletionCounts();

  const dailyLogCounts = await deleteDailyLogsWithSubcollections(
    db,
    uid,
    pageSize,
    dailyLogPageSize,
    deadlineMs
  );
  deleted.dailyLogs = dailyLogCounts.dailyLogs;
  deleted.foodEntries = dailyLogCounts.foodEntries;
  deleted.waterEntries = dailyLogCounts.waterEntries;

  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.weightEntries = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.weightEntries)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.dailyReviews = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.dailyReviews)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.profile = await deleteSingletonDocument(db.doc(profileDocumentPath(uid)));
  deleted.syncMetadata = await deleteSingletonDocument(
    db.doc(syncMetadataDocumentPath(uid))
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.healthDaily = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.healthDaily)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.healthWorkouts = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.healthWorkouts)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.healthRecovery = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.healthRecovery)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.healthWeeklyReviews = await deleteCollectionDocuments(
    db,
    db.collection(userCollectionPath(uid, AccountDeletionCollection.healthWeeklyReviews)),
    pageSize,
    deadlineMs
  );
  if (isPastDeadline(deadlineMs)) {
    return {deleted, completed: false};
  }

  deleted.healthSyncMetadata = await deleteSingletonDocument(
    db.doc(healthSyncMetadataDocumentPath(uid))
  );

  return {deleted, completed: true};
}
