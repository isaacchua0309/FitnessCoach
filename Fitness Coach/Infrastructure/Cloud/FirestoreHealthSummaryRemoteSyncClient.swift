//
//  FirestoreHealthSummaryRemoteSyncClient.swift
//  Fitness Coach
//
//  Forma — Firestore-backed remote sync for normalized Health Summary payloads.
//
//  Uses the shared Firebase app configuration (Firestore.firestore()). Uploads only
//  typed summary payloads — never raw HealthKit samples or secret values.
//

import FirebaseFirestore
import Foundation

final class FirestoreHealthSummaryRemoteSyncClient: HealthSummaryRemoteSyncing, @unchecked Sendable {

    private let userProvider: any HealthCacheUserProviding
    private let batchOperationLimit: Int
    private lazy var firestore: Firestore = Firestore.firestore()
    private lazy var encoder: Firestore.Encoder = Firestore.Encoder()

    init(
        userProvider: any HealthCacheUserProviding,
        batchOperationLimit: Int = HealthSummaryRemoteSyncSupport.defaultBatchOperationLimit
    ) {
        self.userProvider = userProvider
        self.batchOperationLimit = batchOperationLimit
    }

    func uploadDailySummaries(_ summaries: [HealthDailySummarySyncPayload]) async throws {
        try await uploadDocuments(
            summaries,
            collection: HealthSummaryRemoteSyncCollection.daily,
            encode: Self.encodeFirestoreFields
        )
    }

    func uploadWorkoutSummaries(_ workouts: [HealthWorkoutSummarySyncPayload]) async throws {
        try await uploadDocuments(
            workouts,
            collection: HealthSummaryRemoteSyncCollection.workouts,
            encode: Self.encodeFirestoreFields
        )
    }

    func uploadRecoverySummaries(_ recovery: [RecoverySummarySyncPayload]) async throws {
        try await uploadDocuments(
            recovery,
            collection: HealthSummaryRemoteSyncCollection.recovery,
            encode: Self.encodeFirestoreFields
        )
    }

    func uploadWeeklyReviews(_ reviews: [WeeklyHealthReviewSyncPayload]) async throws {
        try await uploadDocuments(
            reviews,
            collection: HealthSummaryRemoteSyncCollection.weeklyReviews,
            encode: Self.encodeFirestoreFields
        )
    }

    func uploadSyncMetadata(_ metadata: HealthSyncMetadataPayload) async throws {
        let authUid = try HealthSummaryRemoteSyncSupport.resolveAuthenticatedUserID(from: userProvider)
        try HealthSummaryRemoteSyncSupport.validateMetadata(metadata, authUid: authUid)

        HealthSummaryRemoteSyncLogger.uploadStarted(
            collection: HealthSummaryRemoteSyncCollection.metadata,
            count: 1,
            uid: authUid
        )

        do {
            let reference = metadataDocumentReference(uid: authUid)
            let data = try encoder.encode(metadata)
            try await reference.setData(data, merge: false)
            HealthSummaryRemoteSyncLogger.uploadFinished(
                collection: HealthSummaryRemoteSyncCollection.metadata,
                count: 1,
                uid: authUid
            )
        } catch let error as HealthSummarySyncError {
            HealthSummaryRemoteSyncLogger.uploadFailed(
                collection: HealthSummaryRemoteSyncCollection.metadata,
                uid: authUid,
                error: error
            )
            throw error
        } catch {
            let mapped = mapUploadError(error, collection: HealthSummaryRemoteSyncCollection.metadata)
            HealthSummaryRemoteSyncLogger.uploadFailed(
                collection: HealthSummaryRemoteSyncCollection.metadata,
                uid: authUid,
                error: mapped
            )
            throw mapped
        }
    }

    func deleteRemoteHealthSummaries() async throws {
        let authUid = try HealthSummaryRemoteSyncSupport.resolveAuthenticatedUserID(from: userProvider)
        HealthSummaryRemoteSyncLogger.deleteStarted(uid: authUid)

        var deletedCount = 0
        do {
            deletedCount += try await deleteAllDocuments(
                in: HealthSummaryRemoteSyncCollection.daily,
                uid: authUid
            )
            deletedCount += try await deleteAllDocuments(
                in: HealthSummaryRemoteSyncCollection.workouts,
                uid: authUid
            )
            deletedCount += try await deleteAllDocuments(
                in: HealthSummaryRemoteSyncCollection.recovery,
                uid: authUid
            )
            deletedCount += try await deleteAllDocuments(
                in: HealthSummaryRemoteSyncCollection.weeklyReviews,
                uid: authUid
            )

            let metadataRef = metadataDocumentReference(uid: authUid)
            let metadataSnapshot = try await metadataRef.getDocument()
            if metadataSnapshot.exists {
                try await metadataRef.delete()
                deletedCount += 1
            }

            HealthSummaryRemoteSyncLogger.deleteFinished(uid: authUid, deletedDocumentCount: deletedCount)
        } catch let error as HealthSummarySyncError {
            HealthSummaryRemoteSyncLogger.warn(
                "Remote health summary delete failed",
                fields: [
                    "uidSuffix": String(authUid.suffix(4)),
                    "error": error.localizedDescription
                ]
            )
            throw error
        } catch {
            let mapped = HealthSummarySyncError.deleteFailed(reason: firestoreReason(from: error))
            HealthSummaryRemoteSyncLogger.warn(
                "Remote health summary delete failed",
                fields: [
                    "uidSuffix": String(authUid.suffix(4)),
                    "error": mapped.localizedDescription
                ]
            )
            throw mapped
        }
    }

    // MARK: - Upload

    private func uploadDocuments<Payload: HealthSummaryRemoteSyncDocumentPayload>(
        _ payloads: [Payload],
        collection: String,
        encode: (Payload) throws -> [String: Any]
    ) async throws {
        guard !payloads.isEmpty else { return }

        let authUid = try HealthSummaryRemoteSyncSupport.resolveAuthenticatedUserID(from: userProvider)
        try HealthSummaryRemoteSyncSupport.validatePayloads(payloads, authUid: authUid)

        HealthSummaryRemoteSyncLogger.uploadStarted(
            collection: collection,
            count: payloads.count,
            uid: authUid
        )

        do {
            let chunks = HealthSummaryRemoteSyncSupport.chunked(payloads, size: batchOperationLimit)
            for chunk in chunks {
                try await commitBatchWrite(chunk, collection: collection, uid: authUid, encode: encode)
            }
            HealthSummaryRemoteSyncLogger.uploadFinished(
                collection: collection,
                count: payloads.count,
                uid: authUid
            )
        } catch let error as HealthSummarySyncError {
            HealthSummaryRemoteSyncLogger.uploadFailed(
                collection: collection,
                uid: authUid,
                error: error
            )
            throw error
        } catch {
            let mapped = mapUploadError(error, collection: collection)
            HealthSummaryRemoteSyncLogger.uploadFailed(
                collection: collection,
                uid: authUid,
                error: mapped
            )
            throw mapped
        }
    }

    private func commitBatchWrite<Payload: HealthSummaryRemoteSyncDocumentPayload>(
        _ payloads: [Payload],
        collection: String,
        uid: String,
        encode: (Payload) throws -> [String: Any]
    ) async throws {
        let batch = firestore.batch()
        let collectionReference = userCollection(uid: uid, name: collection)

        for payload in payloads {
            let reference = collectionReference.document(payload.id)
            let encoded = try encode(payload)
            batch.setData(encoded, forDocument: reference, merge: false)
        }

        do {
            try await batch.commit()
        } catch {
            throw HealthSummarySyncError.batchWriteFailed(
                collection: collection,
                reason: firestoreReason(from: error)
            )
        }
    }

    private static func encodeFirestoreFields(_ payload: HealthDailySummarySyncPayload) throws -> [String: Any] {
        try encodeJSONPayload(payload)
    }

    private static func encodeFirestoreFields(_ payload: HealthWorkoutSummarySyncPayload) throws -> [String: Any] {
        try encodeJSONPayload(payload)
    }

    private static func encodeFirestoreFields(_ payload: RecoverySummarySyncPayload) throws -> [String: Any] {
        try encodeJSONPayload(payload)
    }

    private static func encodeFirestoreFields(_ payload: WeeklyHealthReviewSyncPayload) throws -> [String: Any] {
        try encodeJSONPayload(payload)
    }

    private static func encodeJSONPayload<Payload: Encodable>(_ payload: Payload) throws -> [String: Any] {
        let data = try JSONEncoder().encode(payload)
        guard let encoded = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw HealthSummarySyncError.batchWriteFailed(
                collection: "unknown",
                reason: "payload_encoding_failed"
            )
        }
        return encoded
    }

    // MARK: - Delete

    private func deleteAllDocuments(in collection: String, uid: String) async throws -> Int {
        let collectionReference = userCollection(uid: uid, name: collection)
        var deletedCount = 0

        while true {
            let snapshot = try await collectionReference.limit(to: batchOperationLimit).getDocuments()
            guard !snapshot.documents.isEmpty else { break }

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            try await batch.commit()
            deletedCount += snapshot.documents.count

            if snapshot.documents.count < batchOperationLimit {
                break
            }
        }

        return deletedCount
    }

    // MARK: - References

    private func userCollection(uid: String, name: String) -> CollectionReference {
        firestore
            .collection("users")
            .document(uid)
            .collection(name)
    }

    private func metadataDocumentReference(uid: String) -> DocumentReference {
        userCollection(uid: uid, name: HealthSummaryRemoteSyncCollection.metadata)
            .document(HealthSummarySyncDocumentID.metadataDocumentID)
    }

    // MARK: - Errors

    private func mapUploadError(_ error: Error, collection: String) -> HealthSummarySyncError {
        .uploadFailed(collection: collection, reason: firestoreReason(from: error))
    }

    private func firestoreReason(from error: Error) -> String {
        let nsError = error as NSError
        return "firestore_code_\(nsError.code)"
    }
}
