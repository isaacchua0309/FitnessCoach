//
//  NutritionRemoteSyncing.swift
//  Fitness Coach
//
//  Forma — Remote sync abstraction for nutrition Firestore documents (Phase 2).
//
//  Phase 2 exposes clients only. Production log services do not call these APIs yet.
//

import Foundation

// MARK: - UID provider

protocol NutritionSyncUIDProviding: Sendable {
    var currentUID: String? { get }
}

// MARK: - Remote sync surface

protocol NutritionRemoteSyncing: Sendable {
    func fetchSyncMetadata(uid: String) async throws -> CloudSyncMetadataDocument?
    func saveSyncMetadata(_ document: CloudSyncMetadataDocument, uid: String) async throws

    func fetchDailyLog(uid: String, dayId: String) async throws -> CloudDailyLogDocument?
    func saveDailyLog(_ document: CloudDailyLogDocument, uid: String) async throws
    func listDailyLogsUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument]

    func fetchFoodEntry(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument?
    func saveFoodEntry(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws
    func listFoodEntries(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument]

    func fetchWaterEntry(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument?
    func saveWaterEntry(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws
    func listWaterEntries(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument]

    func fetchWeightEntry(uid: String, entryId: String) async throws -> CloudWeightEntryDocument?
    func saveWeightEntry(_ document: CloudWeightEntryDocument, uid: String) async throws
    func listWeightEntriesUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument]

    func fetchDailyReview(uid: String, dayId: String) async throws -> CloudDailyReviewDocument?
    func saveDailyReview(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws
}

// MARK: - Per-collection clients (Phase 2 building blocks)

protocol SyncMetadataRemoteSyncing: Sendable {
    func fetch(uid: String) async throws -> CloudSyncMetadataDocument?
    func save(_ document: CloudSyncMetadataDocument, uid: String) async throws
}

protocol DailyLogRemoteSyncing: Sendable {
    func fetch(uid: String, dayId: String) async throws -> CloudDailyLogDocument?
    func save(_ document: CloudDailyLogDocument, uid: String) async throws
    func listUpdatedSince(uid: String, after: Date) async throws -> [CloudDailyLogDocument]
}

protocol FoodEntryRemoteSyncing: Sendable {
    func fetch(uid: String, dayId: String, entryId: String) async throws -> CloudFoodEntryDocument?
    func save(_ document: CloudFoodEntryDocument, uid: String, dayId: String) async throws
    func list(uid: String, dayId: String) async throws -> [CloudFoodEntryDocument]
}

protocol WaterEntryRemoteSyncing: Sendable {
    func fetch(uid: String, dayId: String, entryId: String) async throws -> CloudWaterEntryDocument?
    func save(_ document: CloudWaterEntryDocument, uid: String, dayId: String) async throws
    func list(uid: String, dayId: String) async throws -> [CloudWaterEntryDocument]
}

protocol WeightEntryRemoteSyncing: Sendable {
    func fetch(uid: String, entryId: String) async throws -> CloudWeightEntryDocument?
    func save(_ document: CloudWeightEntryDocument, uid: String) async throws
    func listUpdatedSince(uid: String, after: Date) async throws -> [CloudWeightEntryDocument]
}

protocol DailyReviewRemoteSyncing: Sendable {
    func fetch(uid: String, dayId: String) async throws -> CloudDailyReviewDocument?
    func save(_ document: CloudDailyReviewDocument, uid: String, dayId: String) async throws
}
