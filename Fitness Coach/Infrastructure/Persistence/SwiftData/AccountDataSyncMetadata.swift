//
//  AccountDataSyncMetadata.swift
//  Fitness Coach
//
//  Forma — Shared sync metadata fields for account-backed SwiftData entities (Phase 3).
//

import Foundation

/// Sync metadata carried by nutrition log SwiftData entities.
protocol AccountDataSyncMetadataEntity: AnyObject {
    var cloudId: String? { get set }
    var cloudUpdatedAt: Date? { get set }
    var lastSyncedAt: Date? { get set }
    var syncStatusRawValue: String { get set }
    var lastSyncError: String? { get set }
    var deletedAt: Date? { get set }
    var lastMutationId: String? { get set }
    var syncAttemptCount: Int { get set }
    var nextRetryAt: Date? { get set }
    var localUpdatedAt: Date? { get set }
}

extension AccountDataSyncMetadataEntity {

    var syncStatus: AccountDataSyncStatus {
        get { AccountDataSyncStatus(rawValue: syncStatusRawValue) ?? .localOnly }
        set { syncStatusRawValue = newValue.rawValue }
    }
}

enum AccountDataSyncMetadataSupport {

    static let defaultLegacyStatus = AccountDataSyncStatus.localOnly.rawValue

    /// Stable cloud document id for entry entities (food, water, weight, review).
    static func entryCloudID(for entityId: UUID) -> String {
        entityId.uuidString
    }

    /// Firestore daily log document ids use `yyyy-MM-dd`, not the SwiftData UUID.
    static func dailyLogCloudID(for date: Date, calendar: Calendar = .current) -> String {
        CloudAccountDataDateCodec.localDateString(from: date, calendar: calendar)
    }

    /// Sanitized sync errors must never include food names, weights, or chat text.
    static func sanitizedSyncError(from error: Error) -> String {
        if let storeError = error as? AccountDataRemoteStoreError {
            return String(describing: storeError)
        }
        if let mappingError = error as? CloudAccountDataMappingError {
            return String(describing: mappingError)
        }
        return error.localizedDescription
    }
}

extension DailyLogEntity: AccountDataSyncMetadataEntity {}
extension FoodEntryEntity: AccountDataSyncMetadataEntity {}
extension WaterEntryEntity: AccountDataSyncMetadataEntity {}
extension WeightEntryEntity: AccountDataSyncMetadataEntity {}
extension DailyReviewEntity: AccountDataSyncMetadataEntity {}
