//
//  AccountLocalDataInspector.swift
//  Fitness Coach
//
//  Forma — Local account data inventory for restore decisions (Phase 4).
//
//  Inspects SwiftData rows scoped to a signed-in UID. Tombstoned rows do not
//  count as populated content; pending outbox work blocks initial restore.
//

import Foundation
import SwiftData

protocol AccountLocalDataInspecting: AnyObject {
    func inspectLocalData(for uid: String) async throws -> AccountLocalDataStatus
}

struct AccountLocalDataStatus: Equatable, Sendable {
    let uid: String
    let hasProfile: Bool
    let hasAnyDailyLogs: Bool
    let hasTodayDailyLog: Bool
    let foodEntryCount: Int
    let waterEntryCount: Int
    let weightEntryCount: Int
    let dailyReviewCount: Int
    let pendingMutationCount: Int
    let failedMutationCount: Int
    let newestLocalUpdatedAt: Date?
    let oldestLocalDate: String?
    let newestLocalDate: String?
    let isEffectivelyEmpty: Bool
    let needsInitialRestore: Bool
}

enum AccountLocalDataInspectorError: Error, Equatable {
    case invalidUID
}

@MainActor
final class AccountLocalDataInspector: AccountLocalDataInspecting {

    private let store: SwiftDataStore
    private let userProfileService: UserProfileService
    private let outboxStore: any AccountSyncOutboxStore
    private let dateProvider: DateProviding
    private let calendar: Calendar

    init(
        store: SwiftDataStore,
        userProfileService: UserProfileService,
        outboxStore: any AccountSyncOutboxStore,
        dateProvider: DateProviding? = nil,
        calendar: Calendar = AccountLocalMutationTracker.defaultCalendar
    ) {
        self.store = store
        self.userProfileService = userProfileService
        self.outboxStore = outboxStore
        self.dateProvider = dateProvider ?? SystemDateProvider()
        self.calendar = calendar
    }

    func inspectLocalData(for uid: String) async throws -> AccountLocalDataStatus {
        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            throw AccountLocalDataInspectorError.invalidUID
        }

        let hasProfile = try profileBelongsToUID(normalizedUID)
        let dailyLogs = try fetchOwnedDailyLogs(ownerUID: normalizedUID)
        let visibleDailyLogs = dailyLogs.filter(AccountDataSyncReadFilter.isVisible)

        let foodEntryCount = try countOwnedVisibleEntities(
            FoodEntryEntity.self,
            ownerUID: normalizedUID
        )
        let waterEntryCount = try countOwnedVisibleEntities(
            WaterEntryEntity.self,
            ownerUID: normalizedUID
        )
        let weightEntryCount = try countOwnedVisibleEntities(
            WeightEntryEntity.self,
            ownerUID: normalizedUID
        )
        let dailyReviewCount = try countOwnedVisibleEntities(
            DailyReviewEntity.self,
            ownerUID: normalizedUID
        )

        let todayStart = dateProvider.startOfDay(for: dateProvider.now)
        let hasTodayDailyLog = visibleDailyLogs.contains {
            dateProvider.startOfDay(for: $0.date) == todayStart
        }
        let hasAnyDailyLogs = !visibleDailyLogs.isEmpty

        let localDates = visibleDailyLogs
            .map { CloudAccountDataDateCodec.localDateString(from: $0.date, calendar: calendar) }
            .sorted()
        let oldestLocalDate = localDates.first
        let newestLocalDate = localDates.last

        let newestLocalUpdatedAt = newestLocalUpdatedAt(
            ownerUID: normalizedUID,
            dailyLogs: dailyLogs,
            hasProfile: hasProfile
        )

        let mutationCounts = try await outboxStore.countActiveMutations(ownerUID: normalizedUID)

        let hasNutritionContent = foodEntryCount > 0
            || waterEntryCount > 0
            || weightEntryCount > 0
            || dailyReviewCount > 0
            || visibleDailyLogs.contains(where: Self.hasSubstantiveDailyLogContent)
        let isEffectivelyEmpty = !hasNutritionContent
        let hasBlockingLocalEdits = mutationCounts.pending > 0 || mutationCounts.failed > 0
        let needsInitialRestore = isEffectivelyEmpty && !hasBlockingLocalEdits

        return AccountLocalDataStatus(
            uid: normalizedUID,
            hasProfile: hasProfile,
            hasAnyDailyLogs: hasAnyDailyLogs,
            hasTodayDailyLog: hasTodayDailyLog,
            foodEntryCount: foodEntryCount,
            waterEntryCount: waterEntryCount,
            weightEntryCount: weightEntryCount,
            dailyReviewCount: dailyReviewCount,
            pendingMutationCount: mutationCounts.pending,
            failedMutationCount: mutationCounts.failed,
            newestLocalUpdatedAt: newestLocalUpdatedAt,
            oldestLocalDate: oldestLocalDate,
            newestLocalDate: newestLocalDate,
            isEffectivelyEmpty: isEffectivelyEmpty,
            needsInitialRestore: needsInitialRestore
        )
    }

    // MARK: - Profile

    private func profileBelongsToUID(_ uid: String) throws -> Bool {
        guard let profile = try userProfileService.getCurrentProfile() else {
            return false
        }
        return profile.ownerUID == uid
    }

    // MARK: - Entity inventory

    private func fetchOwnedDailyLogs(ownerUID: String) throws -> [DailyLogEntity] {
        let descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { $0.ownerUID == ownerUID },
            sortBy: [SortDescriptor(\.date, order: .forward)]
        )
        return try store.fetch(descriptor)
    }

    private func countOwnedVisibleEntities<T: PersistentModel & AccountDataSyncMetadataEntity & AccountDataSyncOwnable>(
        _ type: T.Type,
        ownerUID: String
    ) throws -> Int {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == ownerUID && entity.deletedAt == nil
            }
        )
        return try store.fetch(descriptor).count
    }

    private func newestLocalUpdatedAt(
        ownerUID: String,
        dailyLogs: [DailyLogEntity],
        hasProfile: Bool
    ) -> Date? {
        var candidates: [Date] = []

        if hasProfile, let profile = try? userProfileService.getCurrentProfile() {
            candidates.append(profile.updatedAt)
        }

        candidates.append(contentsOf: dailyLogs.compactMap(\.localUpdatedAt))
        candidates.append(contentsOf: (try? fetchOwnedSyncMetadataEntities(
            FoodEntryEntity.self,
            ownerUID: ownerUID
        ).compactMap(\.localUpdatedAt)) ?? [])
        candidates.append(contentsOf: (try? fetchOwnedSyncMetadataEntities(
            WaterEntryEntity.self,
            ownerUID: ownerUID
        ).compactMap(\.localUpdatedAt)) ?? [])
        candidates.append(contentsOf: (try? fetchOwnedSyncMetadataEntities(
            WeightEntryEntity.self,
            ownerUID: ownerUID
        ).compactMap(\.localUpdatedAt)) ?? [])
        candidates.append(contentsOf: (try? fetchOwnedSyncMetadataEntities(
            DailyReviewEntity.self,
            ownerUID: ownerUID
        ).compactMap(\.localUpdatedAt)) ?? [])

        return candidates.max()
    }

    private func fetchOwnedSyncMetadataEntities<T: PersistentModel & AccountDataSyncMetadataEntity & AccountDataSyncOwnable>(
        _ type: T.Type,
        ownerUID: String
    ) throws -> [T] {
        let descriptor = FetchDescriptor<T>(
            predicate: #Predicate { entity in
                entity.ownerUID == ownerUID
            }
        )
        return try store.fetch(descriptor)
    }

    private static func hasSubstantiveDailyLogContent(_ log: DailyLogEntity) -> Bool {
        log.caloriesConsumed > 0
            || log.waterConsumedMl > 0
            || log.weightKg != nil
            || log.dailyReviewId != nil
            || log.workoutCaloriesBurned > 0
    }
}
