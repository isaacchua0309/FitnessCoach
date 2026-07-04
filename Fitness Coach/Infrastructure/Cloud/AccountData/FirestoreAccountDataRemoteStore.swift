//
//  FirestoreAccountDataRemoteStore.swift
//  Fitness Coach
//
//  Forma — Firestore-backed account data remote store (Phase 2).
//
//  Not wired into AppContainer or log services. Phase 3 sync engine will inject this store.
//

import FirebaseFirestore
import Foundation

final class FirestoreAccountDataRemoteStore: AccountDataRemoteStore, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()
    private lazy var encoder: Firestore.Encoder = Firestore.Encoder()

    func fetchDailyLog(uid: String, localDate: String) async throws -> CloudDailyLogDocument? {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        let snapshot = try await dailyLogReference(uid: sessionUID, localDate: normalizedDate).getDocument()
        guard snapshot.exists else { return nil }
        return try decode(snapshot, as: CloudDailyLogDocument.self)
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        try await dailyLogReference(uid: sessionUID, localDate: normalizedDate)
            .setData(try encode(document), merge: true)
    }

    func fetchDailyLogs(uid: String, from startDate: String, to endDate: String) async throws -> [CloudDailyLogDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        let snapshot = try await userCollection(uid: sessionUID, name: AccountDataCloudPaths.Segment.dailyLogs)
            .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
            .whereField("localDate", isGreaterThanOrEqualTo: range.0)
            .whereField("localDate", isLessThanOrEqualTo: range.1)
            .getDocuments()
        return try snapshot.documents.map { try decode($0, as: CloudDailyLogDocument.self) }
    }

    func fetchFoodEntries(uid: String, localDate: String) async throws -> [CloudFoodEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        let snapshot = try await dailyLogReference(uid: sessionUID, localDate: normalizedDate)
            .collection(AccountDataCloudPaths.Segment.foodEntries)
            .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
            .getDocuments()
        return try snapshot.documents.map { try decode($0, as: CloudFoodEntryDocument.self) }
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        try await foodEntryReference(uid: sessionUID, localDate: normalizedDate, entryId: document.id)
            .setData(try encode(document), merge: true)
    }

    func deleteFoodEntry(uid: String, localDate: String, entryId: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        guard !entryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
        try await foodEntryReference(uid: sessionUID, localDate: normalizedDate, entryId: entryId).delete()
    }

    func fetchWaterEntries(uid: String, localDate: String) async throws -> [CloudWaterEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        let snapshot = try await dailyLogReference(uid: sessionUID, localDate: normalizedDate)
            .collection(AccountDataCloudPaths.Segment.waterEntries)
            .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
            .getDocuments()
        return try snapshot.documents.map { try decode($0, as: CloudWaterEntryDocument.self) }
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        try await waterEntryReference(uid: sessionUID, localDate: normalizedDate, entryId: document.id)
            .setData(try encode(document), merge: true)
    }

    func deleteWaterEntry(uid: String, localDate: String, entryId: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        guard !entryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
        try await waterEntryReference(uid: sessionUID, localDate: normalizedDate, entryId: entryId).delete()
    }

    func fetchWeightEntries(
        uid: String,
        from startDate: String?,
        to endDate: String?
    ) async throws -> [CloudWeightEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let start = try startDate.map(AccountDataRemoteStoreSupport.validateLocalDate)
        let end = try endDate.map(AccountDataRemoteStoreSupport.validateLocalDate)
        if let start, let end {
            _ = try AccountDataRemoteStoreSupport.validateDateRange(from: start, to: end)
        }

        var query: Query = userCollection(uid: sessionUID, name: AccountDataCloudPaths.Segment.weightEntries)
            .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
        if let start {
            query = query.whereField("localDate", isGreaterThanOrEqualTo: start)
        }
        if let end {
            query = query.whereField("localDate", isLessThanOrEqualTo: end)
        }

        let snapshot = try await query.getDocuments()
        return try snapshot.documents.map { try decode($0, as: CloudWeightEntryDocument.self) }
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        try await weightEntryReference(uid: sessionUID, entryId: document.id)
            .setData(try encode(document), merge: true)
    }

    func deleteWeightEntry(uid: String, entryId: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        guard !entryId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AccountDataRemoteStoreError.invalidDocumentPath
        }
        try await weightEntryReference(uid: sessionUID, entryId: entryId).delete()
    }

    func fetchDailyReview(uid: String, localDate: String) async throws -> CloudDailyReviewDocument? {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        let snapshot = try await dailyReviewReference(uid: sessionUID, localDate: normalizedDate).getDocument()
        guard snapshot.exists else { return nil }
        return try decode(snapshot, as: CloudDailyReviewDocument.self)
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(document.localDate)
        try await dailyReviewReference(uid: sessionUID, localDate: normalizedDate)
            .setData(try encode(document), merge: true)
    }

    func deleteDailyReview(uid: String, localDate: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let normalizedDate = try AccountDataRemoteStoreSupport.validateLocalDate(localDate)
        try await dailyReviewReference(uid: sessionUID, localDate: normalizedDate).delete()
    }

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let snapshot = try await syncMetadataReference(uid: sessionUID).getDocument()
        guard snapshot.exists else { return nil }
        return try decode(snapshot, as: CloudSyncMetadataDocument.self)
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        try AccountDataRemoteStoreSupport.validateWrite(document, uid: sessionUID)
        try await syncMetadataReference(uid: sessionUID)
            .setData(try encode(document), merge: true)
    }

    // MARK: - Firestore references

    private func usersDocument(uid: String) -> DocumentReference {
        firestore
            .collection(AccountDataCloudPaths.Segment.users)
            .document(uid)
    }

    private func userCollection(uid: String, name: String) -> CollectionReference {
        usersDocument(uid: uid).collection(name)
    }

    private func syncMetadataReference(uid: String) -> DocumentReference {
        userCollection(uid: uid, name: AccountDataCloudPaths.Segment.syncMetadata)
            .document(AccountDataCloudPaths.Segment.currentDocumentID)
    }

    private func dailyLogReference(uid: String, localDate: String) -> DocumentReference {
        userCollection(uid: uid, name: AccountDataCloudPaths.Segment.dailyLogs)
            .document(localDate)
    }

    private func foodEntryReference(uid: String, localDate: String, entryId: String) -> DocumentReference {
        dailyLogReference(uid: uid, localDate: localDate)
            .collection(AccountDataCloudPaths.Segment.foodEntries)
            .document(entryId)
    }

    private func waterEntryReference(uid: String, localDate: String, entryId: String) -> DocumentReference {
        dailyLogReference(uid: uid, localDate: localDate)
            .collection(AccountDataCloudPaths.Segment.waterEntries)
            .document(entryId)
    }

    private func weightEntryReference(uid: String, entryId: String) -> DocumentReference {
        userCollection(uid: uid, name: AccountDataCloudPaths.Segment.weightEntries)
            .document(entryId)
    }

    private func dailyReviewReference(uid: String, localDate: String) -> DocumentReference {
        userCollection(uid: uid, name: AccountDataCloudPaths.Segment.dailyReviews)
            .document(localDate)
    }

    // MARK: - Codable helpers

    private func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        do {
            return try encoder.encode(value)
        } catch {
            throw AccountDataRemoteStoreError.encodingFailed
        }
    }

    private func decode<T: Decodable>(_ snapshot: DocumentSnapshot, as type: T.Type) throws -> T {
        do {
            return try snapshot.data(as: T.self)
        } catch {
            throw AccountDataRemoteStoreError.decodingFailed
        }
    }
}
