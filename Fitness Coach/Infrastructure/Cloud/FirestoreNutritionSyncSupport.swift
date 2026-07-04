//
//  FirestoreNutritionSyncSupport.swift
//  Fitness Coach
//
//  Forma — Shared Firestore helpers for nutrition remote clients (Phase 2).
//

import FirebaseFirestore
import Foundation

enum FirestoreNutritionSyncSupport {

    static func normalizedUID(_ uid: String) throws -> String {
        let trimmed = uid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw NutritionSyncError.invalidUID }
        return trimmed
    }

    static func resolveUID(_ uid: String?, operation: String) throws -> String {
        guard let uid else { throw NutritionSyncError.notAuthenticated }
        return try normalizedUID(uid)
    }

    static func validateDocumentUID(_ documentUID: String, sessionUID: String) throws {
        let normalizedDocumentUID = documentUID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSessionUID = try normalizedUID(sessionUID)
        guard normalizedDocumentUID == normalizedSessionUID else {
            throw NutritionSyncError.ownerMismatch(
                expectedUID: normalizedSessionUID,
                documentUID: normalizedDocumentUID
            )
        }
    }

    static func validate<T: CloudNutritionRemoteSyncDocument>(_ document: T, sessionUID: String) throws {
        try validateDocumentUID(document.userId, sessionUID: sessionUID)
        guard document.schemaVersion > 0 else {
            throw NutritionSyncError.invalidDocument("schemaVersion must be positive")
        }
    }

    static func usersDocument(_ firestore: Firestore, uid: String) -> DocumentReference {
        firestore
            .collection(NutritionRemoteSyncCollection.usersRoot)
            .document(uid)
    }

    static func userCollection(_ firestore: Firestore, uid: String, name: String) -> CollectionReference {
        usersDocument(firestore, uid: uid).collection(name)
    }

    static func syncMetadataReference(_ firestore: Firestore, uid: String) -> DocumentReference {
        userCollection(firestore, uid: uid, name: NutritionRemoteSyncCollection.syncMetadata)
            .document(NutritionRemoteSyncCollection.currentDocumentID)
    }

    static func dailyLogReference(_ firestore: Firestore, uid: String, dayId: String) -> DocumentReference {
        userCollection(firestore, uid: uid, name: NutritionRemoteSyncCollection.dailyLogs)
            .document(dayId)
    }

    static func foodEntryReference(
        _ firestore: Firestore,
        uid: String,
        dayId: String,
        entryId: String
    ) -> DocumentReference {
        dailyLogReference(firestore, uid: uid, dayId: dayId)
            .collection(NutritionRemoteSyncCollection.foodEntries)
            .document(entryId)
    }

    static func waterEntryReference(
        _ firestore: Firestore,
        uid: String,
        dayId: String,
        entryId: String
    ) -> DocumentReference {
        dailyLogReference(firestore, uid: uid, dayId: dayId)
            .collection(NutritionRemoteSyncCollection.waterEntries)
            .document(entryId)
    }

    static func weightEntryReference(_ firestore: Firestore, uid: String, entryId: String) -> DocumentReference {
        userCollection(firestore, uid: uid, name: NutritionRemoteSyncCollection.weightEntries)
            .document(entryId)
    }

    static func dailyReviewReference(_ firestore: Firestore, uid: String, dayId: String) -> DocumentReference {
        userCollection(firestore, uid: uid, name: NutritionRemoteSyncCollection.dailyReviews)
            .document(dayId)
    }

    static func mapFirestoreError(_ error: Error, collection: String, operation: String) -> NutritionSyncError {
        let reason = (error as NSError).localizedDescription
        switch operation {
        case "fetch":
            return .fetchFailed(collection: collection, reason: reason)
        case "write":
            return .writeFailed(collection: collection, reason: reason)
        default:
            return .writeFailed(collection: collection, reason: reason)
        }
    }
}
