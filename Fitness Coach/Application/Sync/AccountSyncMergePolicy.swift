//
//  AccountSyncMergePolicy.swift
//  Fitness Coach
//
//  Forma — Conflict-safe merge rules for cloud → local account data pull (Phase 3).
//

import Foundation

/// Inputs for evaluating whether a remote document may be merged into local SwiftData.
struct AccountSyncMergeContext: Equatable, Sendable {
    let uid: String
    let remoteUpdatedAt: Date
    let remoteDeletedAt: Date?
    let localExists: Bool
    let localOwnerUID: String?
    let localSyncStatus: AccountDataSyncStatus?
    /// Best-effort local edit timestamp (`localUpdatedAt` when present, otherwise content timestamp).
    let localEffectiveUpdatedAt: Date?
}

enum AccountSyncMergeDecision: Equatable, Sendable {
    case insert
    case update
    case applyRemoteTombstone
    case skipStaleRemote
    case skipLocalNewer
    case conflict
    case failedOwnerMismatch
    case skipRemoteDeletedNoLocal
}

enum AccountSyncMergePolicy {

    /// Phase 3 does not resurrect rows locally marked `pendingDelete` from non-deleted remotes.
    static let resurrectPendingDeleteFromRemote = false

    static func decide(_ context: AccountSyncMergeContext) -> AccountSyncMergeDecision {
        if let localOwner = normalizedOwnerUID(context.localOwnerUID),
           localOwner != context.uid {
            return .failedOwnerMismatch
        }

        guard context.localExists else {
            if context.remoteDeletedAt != nil {
                return .skipRemoteDeletedNoLocal
            }
            return .insert
        }

        let localStatus = context.localSyncStatus ?? .localOnly
        let remoteIsNewer = isRemoteNewer(
            remoteUpdatedAt: context.remoteUpdatedAt,
            localEffectiveUpdatedAt: context.localEffectiveUpdatedAt
        )

        if let remoteDeletedAt = context.remoteDeletedAt {
            return decideRemoteTombstone(
                localStatus: localStatus,
                remoteIsNewer: remoteIsNewer,
                remoteDeletedAt: remoteDeletedAt,
                localEffectiveUpdatedAt: context.localEffectiveUpdatedAt
            )
        }

        switch localStatus {
        case .pendingDelete:
            if resurrectPendingDeleteFromRemote, remoteIsNewer {
                return .update
            }
            return .skipLocalNewer

        case .pendingUpload, .failed, .conflict:
            if remoteIsNewer {
                return .conflict
            }
            return .skipLocalNewer

        case .synced, .localOnly:
            if remoteIsNewer {
                return .update
            }
            return .skipStaleRemote
        }
    }

    static func localEffectiveUpdatedAt(
        syncMetadata: AccountDataSyncMetadataEntity,
        contentUpdatedAt: Date
    ) -> Date {
        syncMetadata.localUpdatedAt ?? contentUpdatedAt
    }

    // MARK: - Private

    private static func decideRemoteTombstone(
        localStatus: AccountDataSyncStatus,
        remoteIsNewer: Bool,
        remoteDeletedAt: Date,
        localEffectiveUpdatedAt: Date?
    ) -> AccountSyncMergeDecision {
        switch localStatus {
        case .pendingUpload, .failed, .conflict:
            if let localEffectiveUpdatedAt, localEffectiveUpdatedAt > remoteDeletedAt {
                return .skipLocalNewer
            }
            if remoteIsNewer {
                return .applyRemoteTombstone
            }
            return .skipLocalNewer

        case .pendingDelete:
            return .applyRemoteTombstone

        case .synced, .localOnly:
            if remoteIsNewer {
                return .applyRemoteTombstone
            }
            return .skipStaleRemote
        }
    }

    private static func isRemoteNewer(
        remoteUpdatedAt: Date,
        localEffectiveUpdatedAt: Date?
    ) -> Bool {
        guard let localEffectiveUpdatedAt else {
            return true
        }
        return remoteUpdatedAt > localEffectiveUpdatedAt
    }

    private static func normalizedOwnerUID(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

/// Applies accepted merge decisions to SwiftData entities and sync metadata.
enum AccountSyncRemoteMergeApplicator {

    static func stampInserted(
        on entity: AccountDataSyncMetadataEntity,
        cloudId: String,
        remoteUpdatedAt: Date,
        now: Date
    ) {
        entity.cloudId = cloudId
        entity.cloudUpdatedAt = remoteUpdatedAt
        entity.lastSyncedAt = now
        entity.syncStatusRawValue = AccountDataSyncStatus.synced.rawValue
        entity.lastSyncError = nil
        entity.syncAttemptCount = 0
        entity.nextRetryAt = nil
        entity.deletedAt = nil
    }

    static func stampUpdated(
        on entity: AccountDataSyncMetadataEntity,
        cloudId: String,
        remoteUpdatedAt: Date,
        now: Date
    ) {
        entity.cloudId = cloudId
        entity.cloudUpdatedAt = remoteUpdatedAt
        entity.lastSyncedAt = now
        entity.syncStatusRawValue = AccountDataSyncStatus.synced.rawValue
        entity.lastSyncError = nil
        entity.syncAttemptCount = 0
        entity.nextRetryAt = nil
        entity.deletedAt = nil
    }

    static func applyRemoteTombstone(
        on entity: AccountDataSyncMetadataEntity,
        remoteDeletedAt: Date?,
        remoteUpdatedAt: Date,
        now: Date
    ) {
        entity.deletedAt = remoteDeletedAt ?? now
        entity.cloudUpdatedAt = remoteUpdatedAt
        entity.lastSyncedAt = now
        entity.syncStatusRawValue = AccountDataSyncStatus.synced.rawValue
        entity.lastSyncError = nil
        entity.syncAttemptCount = 0
        entity.nextRetryAt = nil
    }

    static func markConflict(
        on entity: AccountDataSyncMetadataEntity,
        remoteUpdatedAt: Date
    ) {
        entity.syncStatusRawValue = AccountDataSyncStatus.conflict.rawValue
        entity.cloudUpdatedAt = remoteUpdatedAt
    }

    static func apply(
        _ document: CloudDailyLogDocument,
        to entity: DailyLogEntity
    ) {
        entity.weightKg = document.weightKg
        entity.calorieTarget = document.calorieTarget
        entity.proteinTarget = document.proteinTarget
        entity.carbTarget = document.carbTarget
        entity.fatTarget = document.fatTarget
        entity.waterTargetMl = document.waterTargetMl
        entity.expectedWeeklyWeightLossKg = document.expectedWeeklyWeightLossKg
        entity.aggressivenessRawValue = document.aggressiveness
        entity.caloriesConsumed = document.caloriesConsumed
        entity.proteinConsumed = document.proteinConsumed
        entity.carbsConsumed = document.carbsConsumed
        entity.fatConsumed = document.fatConsumed
        entity.fiberConsumed = document.fiberConsumed
        entity.sodiumConsumed = document.sodiumConsumed
        entity.waterConsumedMl = document.waterConsumedMl
        entity.steps = document.steps
        entity.workoutCaloriesBurned = document.workoutCaloriesBurned
        entity.dailyReviewId = document.dailyReviewId.flatMap(UUID.init(uuidString:))
        entity.createdAt = document.createdAt
        entity.updatedAt = document.updatedAt
    }

    /// Merges cloud food fields. `imageUrl` is a remote reference only — raw image bytes are never pulled.
    static func apply(
        _ document: CloudFoodEntryDocument,
        to entity: FoodEntryEntity
    ) {
        entity.dailyLogId = UUID(uuidString: document.dailyLogId) ?? entity.dailyLogId
        entity.mealTypeRawValue = document.mealType
        entity.name = document.name
        entity.quantity = document.quantity
        entity.unit = document.unit
        entity.calories = document.calories
        entity.protein = document.protein
        entity.carbs = document.carbs
        entity.fat = document.fat
        entity.fiber = document.fiber
        entity.sodium = document.sodium
        entity.sourceRawValue = document.source
        entity.confidenceRawValue = document.confidence
        entity.imageUrl = document.imageUrl
        entity.notes = document.notes
        entity.componentsJSON = document.componentsJSON
        entity.createdAt = document.createdAt
        entity.updatedAt = document.updatedAt
    }

    static func apply(
        _ document: CloudWaterEntryDocument,
        to entity: WaterEntryEntity
    ) {
        entity.dailyLogId = UUID(uuidString: document.dailyLogId) ?? entity.dailyLogId
        entity.amountMl = document.amountMl
        entity.createdAt = document.createdAt
    }

    static func apply(
        _ document: CloudWeightEntryDocument,
        to entity: WeightEntryEntity,
        calendar: Calendar
    ) throws {
        guard let date = CloudAccountDataDateCodec.date(
            fromLocalDateString: document.localDate,
            calendar: calendar
        ) else {
            throw CloudAccountDataMappingError.invalidDate(entity: "WeightEntryEntity", id: document.id)
        }
        entity.date = calendar.startOfDay(for: date)
        entity.weightKg = document.weightKg
        entity.note = document.note
        entity.createdAt = document.createdAt
    }

    static func apply(
        _ document: CloudDailyReviewDocument,
        to entity: DailyReviewEntity
    ) {
        entity.dailyLogId = UUID(uuidString: document.dailyLogId) ?? entity.dailyLogId
        entity.summaryText = document.summaryText
        entity.caloriesSummary = document.caloriesSummary
        entity.proteinSummary = document.proteinSummary
        entity.hydrationSummary = document.hydrationSummary
        entity.workoutSummary = document.workoutSummary
        entity.weightSummary = document.weightSummary
        entity.tomorrowRecommendation = document.tomorrowRecommendation
        entity.createdAt = document.createdAt
    }
}
