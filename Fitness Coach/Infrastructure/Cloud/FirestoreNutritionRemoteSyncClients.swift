//
//  FirestoreNutritionRemoteSyncClients.swift
//  Fitness Coach
//
//  Forma — Firestore remote clients for nutrition collections (Phase 2).
//
//  Not wired into AppContainer or log services. Phase 3 sync engine will call these APIs.
//

import FirebaseFirestore
import Foundation

// MARK: - Sync metadata

final class FirestoreSyncMetadataClient: SyncMetadataRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String) async throws -> CloudSyncMetadataDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .syncMetadataReference(firestore, uid: sessionUID)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudSyncMetadataDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.syncMetadata,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .syncMetadataReference(firestore, uid: sessionUID)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.syncMetadata,
                operation: "write"
            )
        }
    }
}

// MARK: - Daily logs

final class FirestoreDailyLogSyncClient: DailyLogRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String, dayId: String) async throws -> CloudDailyLogDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .dailyLogReference(firestore, uid: sessionUID, localDate: dayId)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudDailyLogDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.dailyLogs,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudDailyLogDocument, uid: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .dailyLogReference(firestore, uid: sessionUID, localDate: document.id)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.dailyLogs,
                operation: "write"
            )
        }
    }

    func listUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument] {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .userCollection(firestore, uid: sessionUID, name: AccountDataCloudPaths.Segment.dailyLogs)
                .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
                .whereField(AccountDataCloudSchema.updatedAt, isGreaterThan: after)
                .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: CloudDailyLogDocument.self) }
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.dailyLogs,
                operation: "fetch"
            )
        }
    }
}

// MARK: - Food entries

final class FirestoreFoodEntrySyncClient: FoodEntryRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .foodEntryReference(firestore, uid: sessionUID, localDate: dayId, entryId: entryId)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudFoodEntryDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.foodEntries,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .foodEntryReference(firestore, uid: sessionUID, localDate: dayId, entryId: document.id)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.foodEntries,
                operation: "write"
            )
        }
    }

    func list(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument] {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .dailyLogReference(firestore, uid: sessionUID, localDate: dayId)
                .collection(AccountDataCloudPaths.Segment.foodEntries)
                .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
                .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: CloudFoodEntryDocument.self) }
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.foodEntries,
                operation: "fetch"
            )
        }
    }
}

// MARK: - Water entries

final class FirestoreWaterEntrySyncClient: WaterEntryRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .waterEntryReference(firestore, uid: sessionUID, localDate: dayId, entryId: entryId)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudWaterEntryDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.waterEntries,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .waterEntryReference(firestore, uid: sessionUID, localDate: dayId, entryId: document.id)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.waterEntries,
                operation: "write"
            )
        }
    }

    func list(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument] {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .dailyLogReference(firestore, uid: sessionUID, localDate: dayId)
                .collection(AccountDataCloudPaths.Segment.waterEntries)
                .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
                .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: CloudWaterEntryDocument.self) }
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.waterEntries,
                operation: "fetch"
            )
        }
    }
}

// MARK: - Weight entries

final class FirestoreWeightEntrySyncClient: WeightEntryRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String, entryId: String) async throws -> CloudWeightEntryDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .weightEntryReference(firestore, uid: sessionUID, entryId: entryId)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudWeightEntryDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.weightEntries,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudWeightEntryDocument, uid: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .weightEntryReference(firestore, uid: sessionUID, entryId: document.id)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.weightEntries,
                operation: "write"
            )
        }
    }

    func listUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument] {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .userCollection(firestore, uid: sessionUID, name: AccountDataCloudPaths.Segment.weightEntries)
                .whereField(AccountDataCloudSchema.userId, isEqualTo: sessionUID)
                .whereField(AccountDataCloudSchema.updatedAt, isGreaterThan: after)
                .getDocuments()
            return try snapshot.documents.compactMap { try $0.data(as: CloudWeightEntryDocument.self) }
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.weightEntries,
                operation: "fetch"
            )
        }
    }
}

// MARK: - Daily reviews

final class FirestoreDailyReviewSyncClient: DailyReviewRemoteSyncing, @unchecked Sendable {

    private lazy var firestore: Firestore = Firestore.firestore()

    func fetch(uid: String, dayId: String) async throws -> CloudDailyReviewDocument? {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        do {
            let snapshot = try await FirestoreNutritionSyncSupport
                .dailyReviewReference(firestore, uid: sessionUID, localDate: dayId)
                .getDocument()
            guard snapshot.exists else { return nil }
            return try snapshot.data(as: CloudDailyReviewDocument.self)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.dailyReviews,
                operation: "fetch"
            )
        }
    }

    func save(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws {
        let sessionUID = try FirestoreNutritionSyncSupport.normalizedUID(uid)
        try FirestoreNutritionSyncSupport.validate(document, sessionUID: sessionUID)
        do {
            try await FirestoreNutritionSyncSupport
                .dailyReviewReference(firestore, uid: sessionUID, localDate: dayId)
                .setData(try Firestore.Encoder().encode(document), merge: true)
        } catch let error as NutritionSyncError {
            throw error
        } catch {
            throw FirestoreNutritionSyncSupport.mapFirestoreError(
                error,
                collection: AccountDataCloudPaths.Segment.dailyReviews,
                operation: "write"
            )
        }
    }
}

// MARK: - Facade

final class FirestoreNutritionRemoteSyncClient: NutritionRemoteSyncing, @unchecked Sendable {

    private let syncMetadataClient: FirestoreSyncMetadataClient
    private let dailyLogClient: FirestoreDailyLogSyncClient
    private let foodEntryClient: FirestoreFoodEntrySyncClient
    private let waterEntryClient: FirestoreWaterEntrySyncClient
    private let weightEntryClient: FirestoreWeightEntrySyncClient
    private let dailyReviewClient: FirestoreDailyReviewSyncClient

    init(
        syncMetadataClient: FirestoreSyncMetadataClient = FirestoreSyncMetadataClient(),
        dailyLogClient: FirestoreDailyLogSyncClient = FirestoreDailyLogSyncClient(),
        foodEntryClient: FirestoreFoodEntrySyncClient = FirestoreFoodEntrySyncClient(),
        waterEntryClient: FirestoreWaterEntrySyncClient = FirestoreWaterEntrySyncClient(),
        weightEntryClient: FirestoreWeightEntrySyncClient = FirestoreWeightEntrySyncClient(),
        dailyReviewClient: FirestoreDailyReviewSyncClient = FirestoreDailyReviewSyncClient()
    ) {
        self.syncMetadataClient = syncMetadataClient
        self.dailyLogClient = dailyLogClient
        self.foodEntryClient = foodEntryClient
        self.waterEntryClient = waterEntryClient
        self.weightEntryClient = weightEntryClient
        self.dailyReviewClient = dailyReviewClient
    }

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? {
        try await syncMetadataClient.fetch(uid: uid)
    }

    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {
        try await syncMetadataClient.save(document, uid: uid)
    }

    func fetchDailyLog(uid: String, dayId: String) async throws -> CloudDailyLogDocument? {
        try await dailyLogClient.fetch(uid: uid, dayId: dayId)
    }

    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {
        try await dailyLogClient.save(document, uid: uid)
    }

    func listDailyLogsUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument] {
        try await dailyLogClient.listUpdatedSince(uid: uid, after: after)
    }

    func fetchFoodEntry(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument? {
        try await foodEntryClient.fetch(uid: uid, dayId: dayId, entryId: entryId)
    }

    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws {
        try await foodEntryClient.save(document, uid: uid, dayId: dayId)
    }

    func listFoodEntries(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument] {
        try await foodEntryClient.list(uid: uid, dayId: dayId)
    }

    func fetchWaterEntry(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument? {
        try await waterEntryClient.fetch(uid: uid, dayId: dayId, entryId: entryId)
    }

    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws {
        try await waterEntryClient.save(document, uid: uid, dayId: dayId)
    }

    func listWaterEntries(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument] {
        try await waterEntryClient.list(uid: uid, dayId: dayId)
    }

    func fetchWeightEntry(uid: String, entryId: String) async throws -> CloudWeightEntryDocument? {
        try await weightEntryClient.fetch(uid: uid, entryId: entryId)
    }

    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {
        try await weightEntryClient.save(document, uid: uid)
    }

    func listWeightEntriesUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument] {
        try await weightEntryClient.listUpdatedSince(uid: uid, after: after)
    }

    func fetchDailyReview(uid: String, dayId: String) async throws -> CloudDailyReviewDocument? {
        try await dailyReviewClient.fetch(uid: uid, dayId: dayId)
    }

    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws {
        try await dailyReviewClient.save(document, uid: uid, dayId: dayId)
    }
}

// MARK: - No-op (tests / disabled builds)

final class NoOpNutritionRemoteSyncClient: NutritionRemoteSyncing, @unchecked Sendable {

    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument? { nil }
    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws {}
    func fetchDailyLog(uid: String, dayId: String) async throws -> CloudDailyLogDocument? { nil }
    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws {}
    func listDailyLogsUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument] { [] }
    func fetchFoodEntry(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument? { nil }
    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws {}
    func listFoodEntries(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument] { [] }
    func fetchWaterEntry(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument? { nil }
    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws {}
    func listWaterEntries(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument] { [] }
    func fetchWeightEntry(uid: String, entryId: String) async throws -> CloudWeightEntryDocument? { nil }
    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws {}
    func listWeightEntriesUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument] { [] }
    func fetchDailyReview(uid: String, dayId: String) async throws -> CloudDailyReviewDocument? { nil }
    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws {}
}
