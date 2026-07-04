//
//  FirestoreAccountDataRemoteStore.swift
//  Fitness Coach
//
//  Forma — Firestore-backed account data remote store (Phase 2).
//
//  Not wired into AppContainer or log services. Phase 3 sync engine will inject this store.
//
//  Phase 5 incremental fetch composite indexes (deploy in Firebase console or firestore.indexes.json):
//  - Collection `users/{uid}/dailyLogs`:        userId ASC, updatedAt ASC
//  - Collection `users/{uid}/weightEntries`:      userId ASC, updatedAt ASC
//  - Collection `users/{uid}/dailyReviews`:     userId ASC, updatedAt ASC
//  - Subcollection `.../dailyLogs/{date}/foodEntries`:  userId ASC, updatedAt ASC
//  - Subcollection `.../dailyLogs/{date}/waterEntries`: userId ASC, updatedAt ASC
//
//  Food/water incremental fetch uses bounded per-day subcollection queries (no collection group).
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

    // MARK: - Phase 5 incremental fetch

    func fetchDailyLogsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyLogDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let safeLimit = AccountDataRemoteStoreIncrementalSupport.clampLimit(limit)
        let query = incrementalQuery(
            on: userCollection(uid: sessionUID, name: AccountDataCloudPaths.Segment.dailyLogs),
            sessionUID: sessionUID,
            since: since,
            limit: safeLimit
        )
        let snapshot = try await query.getDocuments()
        let documents = try validatedDocuments(from: snapshot.documents, as: CloudDailyLogDocument.self, sessionUID: sessionUID)
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            documents,
            limit: safeLimit,
            updatedAt: \.updatedAt
        )
    }

    func fetchFoodEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudFoodEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        let safeLimit = AccountDataRemoteStoreIncrementalSupport.clampLimit(limit)
        let localDates = AccountDataRemoteStoreSupport.localDates(from: range.0, to: range.1)
        var collected: [CloudFoodEntryDocument] = []
        for localDate in localDates {
            let query = incrementalQuery(
                on: dailyLogReference(uid: sessionUID, localDate: localDate)
                    .collection(AccountDataCloudPaths.Segment.foodEntries),
                sessionUID: sessionUID,
                since: since,
                limit: safeLimit
            )
            let snapshot = try await query.getDocuments()
            collected.append(
                contentsOf: try validatedDocuments(
                    from: snapshot.documents,
                    as: CloudFoodEntryDocument.self,
                    sessionUID: sessionUID
                )
            )
        }
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            collected,
            limit: safeLimit,
            updatedAt: \.updatedAt
        )
    }

    func fetchWaterEntriesUpdatedSince(
        uid: String,
        since: Date?,
        from startDate: String,
        to endDate: String,
        limit: Int
    ) async throws -> [CloudWaterEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        let safeLimit = AccountDataRemoteStoreIncrementalSupport.clampLimit(limit)
        let localDates = AccountDataRemoteStoreSupport.localDates(from: range.0, to: range.1)
        var collected: [CloudWaterEntryDocument] = []
        for localDate in localDates {
            let query = incrementalQuery(
                on: dailyLogReference(uid: sessionUID, localDate: localDate)
                    .collection(AccountDataCloudPaths.Segment.waterEntries),
                sessionUID: sessionUID,
                since: since,
                limit: safeLimit
            )
            let snapshot = try await query.getDocuments()
            collected.append(
                contentsOf: try validatedDocuments(
                    from: snapshot.documents,
                    as: CloudWaterEntryDocument.self,
                    sessionUID: sessionUID
                )
            )
        }
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            collected,
            limit: safeLimit,
            updatedAt: \.updatedAt
        )
    }

    func fetchWeightEntriesUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudWeightEntryDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let safeLimit = AccountDataRemoteStoreIncrementalSupport.clampLimit(limit)
        let query = incrementalQuery(
            on: userCollection(uid: sessionUID, name: AccountDataCloudPaths.Segment.weightEntries),
            sessionUID: sessionUID,
            since: since,
            limit: safeLimit
        )
        let snapshot = try await query.getDocuments()
        let documents = try validatedDocuments(
            from: snapshot.documents,
            as: CloudWeightEntryDocument.self,
            sessionUID: sessionUID
        )
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            documents,
            limit: safeLimit,
            updatedAt: \.updatedAt
        )
    }

    func fetchDailyReviewsUpdatedSince(
        uid: String,
        since: Date?,
        limit: Int
    ) async throws -> [CloudDailyReviewDocument] {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let safeLimit = AccountDataRemoteStoreIncrementalSupport.clampLimit(limit)
        let query = incrementalQuery(
            on: userCollection(uid: sessionUID, name: AccountDataCloudPaths.Segment.dailyReviews),
            sessionUID: sessionUID,
            since: since,
            limit: safeLimit
        )
        let snapshot = try await query.getDocuments()
        let documents = try validatedDocuments(
            from: snapshot.documents,
            as: CloudDailyReviewDocument.self,
            sessionUID: sessionUID
        )
        return AccountDataRemoteStoreIncrementalSupport.sortAndLimit(
            documents,
            limit: safeLimit,
            updatedAt: \.updatedAt
        )
    }

    func fetchCloudProfileUpdatedSince(uid: String, since: Date?) async throws -> CloudUserProfileDocument? {
        let sessionUID = try AccountDataRemoteStoreSupport.normalizedUID(uid)
        let snapshot = try await profileDocumentReference(uid: sessionUID).getDocument()
        guard snapshot.exists else { return nil }
        let document = try decode(snapshot, as: CloudUserProfileDocument.self)
        guard AccountDataRemoteStoreIncrementalSupport.matchesUpdatedSince(document.updatedAt, since: since) else {
            return nil
        }
        return document
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

    private func profileDocumentReference(uid: String) -> DocumentReference {
        usersDocument(uid: uid)
            .collection(AccountDataCloudPaths.Segment.profile)
            .document(AccountDataCloudPaths.Segment.currentDocumentID)
    }

    // MARK: - Incremental query helpers

    private func incrementalQuery(
        on collection: Query,
        sessionUID: String,
        since: Date?,
        limit: Int
    ) -> Query {
        var query = collection.whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
        if let since {
            query = query
                .whereField(AccountDataCloudSchema.updatedAt, isGreaterThan: since)
                .order(by: AccountDataCloudSchema.updatedAt)
        } else {
            query = query.order(by: AccountDataCloudSchema.updatedAt)
        }
        return query.limit(to: limit)
    }

    private func validatedDocuments<T: CloudAccountDataDocument>(
        from snapshots: [QueryDocumentSnapshot],
        as type: T.Type,
        sessionUID: String
    ) throws -> [T] {
        var results: [T] = []
        for snapshot in snapshots {
            let document = try decode(snapshot, as: type)
            let normalizedDocumentUserId = document.userId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedDocumentUserId == sessionUID else { continue }
            results.append(document)
        }
        return results
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
