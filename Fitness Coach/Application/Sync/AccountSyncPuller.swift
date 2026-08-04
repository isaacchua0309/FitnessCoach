//
//  AccountSyncPuller.swift
//  Fitness Coach
//
//  Forma — Fetches cloud account data and merges into local SwiftData (Phase 3).
//

import Foundation
import SwiftData

struct AccountSyncPullSummary: Equatable, Sendable {
    let uid: String
    let dailyLogsFetched: Int
    let foodEntriesFetched: Int
    let waterEntriesFetched: Int
    let weightEntriesFetched: Int
    let dailyReviewsFetched: Int
    let inserted: Int
    let updated: Int
    let skippedLocalNewer: Int
    let conflicts: Int
    let failed: Int
}

struct AccountSyncMergeBatchResult: Equatable, Sendable {
    let inserted: Int
    let updated: Int
    let deleted: Int
    let skippedLocalNewer: Int
    let conflicts: Int
    let failed: Int
}

protocol AccountSyncPulling: AnyObject {
    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary

    /// Pulls only weight entries for a date range (no per-day food/water/review fan-out).
    func pullWeightEntries(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult
}

enum AccountSyncPullerError: Error, Equatable, Sendable {
    case ownerMismatch(expected: String, actual: String)
    case missingDailyLog(localDate: String)
}

@MainActor
final class AccountSyncPuller: AccountSyncPulling {

    static let defaultRecentPullDayCount = 90

    private let remoteStore: any AccountDataRemoteStore
    private let store: SwiftDataStore
    private let calendar: Calendar
    private let nowProvider: () -> Date

    init(
        remoteStore: any AccountDataRemoteStore,
        store: SwiftDataStore,
        calendar: Calendar = AccountSyncPuller.defaultCalendar,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.remoteStore = remoteStore
        self.store = store
        self.calendar = calendar
        self.nowProvider = nowProvider
    }

    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        await AccountRestoreBootstrapTracer.measure(
            "pull_recent_account_data",
            fields: ["daycount": "range"]
        ) {
            await pullRecentAccountDataInstrumented(
                for: uid,
                from: startDate,
                to: endDate
            )
        }
    }

    func pullWeightEntries(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        await AccountRestoreBootstrapTracer.measure("pull_weight_entries") {
            await pullWeightEntriesInstrumented(
                for: uid,
                from: startDate,
                to: endDate
            )
        }
    }

    private func pullRecentAccountDataInstrumented(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        let normalizedUID: String
        let range: (String, String)
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
            range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        } catch {
            return emptySummary(uid: uid.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var stats = PullStats()

        // 1) Range-fetch daily logs first so child fan-out only hits dates that exist.
        var dailyLogs: [CloudDailyLogDocument] = []
        do {
            dailyLogs = try await remoteStore.fetchDailyLogs(
                uid: normalizedUID,
                from: range.0,
                to: range.1
            )
            stats.dailyLogsFetched = dailyLogs.count
            for document in dailyLogs {
                mergeDailyLog(document, uid: normalizedUID, stats: &stats)
            }
        } catch {
            stats.failed += 1
        }

        let childDates = Self.childFetchDates(
            dailyLogs: dailyLogs,
            rangeStart: range.0,
            rangeEnd: range.1,
            calendar: calendar
        )
        AccountRestoreBootstrapTracer.event(
            "pull_child_dates_resolved",
            fields: ["childdatecount": String(childDates.count)]
        )

        // 2) Fetch weight + per-day children concurrently, then merge on the main actor.
        async let weightResult = fetchWeightDocuments(
            uid: normalizedUID,
            from: range.0,
            to: range.1
        )
        async let childResult = fetchChildDocuments(
            uid: normalizedUID,
            localDates: childDates
        )

        let fetchedWeights = await weightResult
        let fetchedChildren = await childResult

        switch fetchedWeights {
        case .success(let weightEntries):
            stats.weightEntriesFetched = weightEntries.count
            for document in weightEntries {
                mergeWeightEntry(document, uid: normalizedUID, stats: &stats)
            }
        case .failure:
            stats.failed += 1
        }

        stats.foodEntriesFetched += fetchedChildren.foodEntries.count
        stats.waterEntriesFetched += fetchedChildren.waterEntries.count
        stats.dailyReviewsFetched += fetchedChildren.dailyReviews.count
        stats.failed += fetchedChildren.failed

        for document in fetchedChildren.foodEntries {
            mergeFoodEntry(document, uid: normalizedUID, stats: &stats)
        }
        for document in fetchedChildren.waterEntries {
            mergeWaterEntry(document, uid: normalizedUID, stats: &stats)
        }
        for document in fetchedChildren.dailyReviews {
            mergeDailyReview(document, uid: normalizedUID, stats: &stats)
        }

        try? store.save()

        return stats.summary(uid: normalizedUID)
    }

    private func pullWeightEntriesInstrumented(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary {
        let normalizedUID: String
        let range: (String, String)
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
            range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        } catch {
            return emptySummary(uid: uid.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var stats = PullStats()
        switch await fetchWeightDocuments(uid: normalizedUID, from: range.0, to: range.1) {
        case .success(let weightEntries):
            stats.weightEntriesFetched = weightEntries.count
            for document in weightEntries {
                mergeWeightEntry(document, uid: normalizedUID, stats: &stats)
            }
        case .failure:
            stats.failed += 1
        }

        try? store.save()
        return stats.summary(uid: normalizedUID)
    }

    private struct ChildFetchBatch: Sendable {
        var foodEntries: [CloudFoodEntryDocument] = []
        var waterEntries: [CloudWaterEntryDocument] = []
        var dailyReviews: [CloudDailyReviewDocument] = []
        var failed: Int = 0
    }

    private enum DayChildPayload: Sendable {
        case food([CloudFoodEntryDocument])
        case water([CloudWaterEntryDocument])
        case review(CloudDailyReviewDocument?)
        case failed
    }

    private func fetchWeightDocuments(
        uid: String,
        from startDate: String,
        to endDate: String
    ) async -> Result<[CloudWeightEntryDocument], Error> {
        do {
            let documents = try await remoteStore.fetchWeightEntries(
                uid: uid,
                from: startDate,
                to: endDate
            )
            return .success(documents)
        } catch {
            return .failure(error)
        }
    }

    private func fetchChildDocuments(
        uid: String,
        localDates: [String]
    ) async -> ChildFetchBatch {
        guard !localDates.isEmpty else { return ChildFetchBatch() }

        return await withTaskGroup(of: DayChildPayload.self, returning: ChildFetchBatch.self) { group in
            for localDate in localDates {
                group.addTask { [remoteStore] in
                    do {
                        let food = try await remoteStore.fetchFoodEntries(uid: uid, localDate: localDate)
                        return .food(food)
                    } catch {
                        return .failed
                    }
                }
                group.addTask { [remoteStore] in
                    do {
                        let water = try await remoteStore.fetchWaterEntries(uid: uid, localDate: localDate)
                        return .water(water)
                    } catch {
                        return .failed
                    }
                }
                group.addTask { [remoteStore] in
                    do {
                        let review = try await remoteStore.fetchDailyReview(uid: uid, localDate: localDate)
                        return .review(review)
                    } catch {
                        return .failed
                    }
                }
            }

            var batch = ChildFetchBatch()
            for await payload in group {
                switch payload {
                case .food(let entries):
                    batch.foodEntries.append(contentsOf: entries)
                case .water(let entries):
                    batch.waterEntries.append(contentsOf: entries)
                case .review(let review):
                    if let review {
                        batch.dailyReviews.append(review)
                    }
                case .failed:
                    batch.failed += 1
                }
            }
            return batch
        }
    }

    /// Child collections only exist under daily-log documents. Prefer those dates;
    /// fall back to the full range only when the daily-log range query itself failed.
    static func childFetchDates(
        dailyLogs: [CloudDailyLogDocument],
        rangeStart: String,
        rangeEnd: String,
        calendar: Calendar
    ) -> [String] {
        let datesFromLogs = Set(
            dailyLogs
                .filter { $0.deletedAt == nil }
                .map(\.localDate)
        )
        if !datesFromLogs.isEmpty {
            return datesFromLogs.sorted()
        }
        // No remote logs in range — skip empty-day fan-out entirely.
        _ = rangeStart
        _ = rangeEnd
        _ = calendar
        return []
    }

    func mergeFetchedDocuments(
        for uid: String,
        dailyLogs: [CloudDailyLogDocument],
        foodEntries: [CloudFoodEntryDocument],
        waterEntries: [CloudWaterEntryDocument],
        weightEntries: [CloudWeightEntryDocument],
        dailyReviews: [CloudDailyReviewDocument]
    ) throws -> AccountSyncMergeBatchResult {
        let normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        var stats = PullStats()

        for document in dailyLogs {
            mergeDailyLog(document, uid: normalizedUID, stats: &stats)
        }
        for document in foodEntries {
            mergeFoodEntry(document, uid: normalizedUID, stats: &stats)
        }
        for document in waterEntries {
            mergeWaterEntry(document, uid: normalizedUID, stats: &stats)
        }
        for document in weightEntries {
            mergeWeightEntry(document, uid: normalizedUID, stats: &stats)
        }
        for document in dailyReviews {
            mergeDailyReview(document, uid: normalizedUID, stats: &stats)
        }

        try store.save()
        return stats.mergeBatchResult
    }

    // MARK: - Merge handlers

    private func mergeDailyLog(_ document: CloudDailyLogDocument, uid: String, stats: inout PullStats) {
        do {
            try AccountDataRemoteStoreSupport.validateUserIdMatch(documentUserId: document.userId, uid: uid)
            let localDate = document.localDate
            let existing = try fetchDailyLogEntity(localDate: localDate)
            let context = mergeContext(
                uid: uid,
                remoteUpdatedAt: document.updatedAt,
                remoteDeletedAt: document.deletedAt,
                existing: existing,
                contentUpdatedAt: existing?.updatedAt
            )
            let decision = AccountSyncMergePolicy.decide(context)
            let now = nowProvider()
            let cloudId = document.id

            switch decision {
            case .insert:
                let entity = try CloudAccountDataMappers.entity(
                    from: document,
                    context: mappingContext(uid: uid)
                )
                AccountSyncRemoteMergeApplicator.stampInserted(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                try store.insert(entity)
                stats.inserted += 1

            case .update:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.apply(document, to: entity)
                AccountSyncRemoteMergeApplicator.stampUpdated(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                stats.updated += 1

            case .applyRemoteTombstone:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.applyRemoteTombstone(
                    on: entity,
                    remoteDeletedAt: document.deletedAt,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                entity.cloudId = cloudId
                stats.deleted += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict(let reason):
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt,
                        reason: reason
                    )
                    recordMergeConflict(
                        entityType: .dailyLog,
                        cloudId: cloudId,
                        reason: reason
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
                recordMergeConflict(
                    entityType: .dailyLog,
                    cloudId: cloudId,
                    reason: .ownerMismatch
                )
                stats.failed += 1
            }
        } catch {
            stats.failed += 1
        }
    }

    private func mergeFoodEntry(_ document: CloudFoodEntryDocument, uid: String, stats: inout PullStats) {
        do {
            try AccountDataRemoteStoreSupport.validateUserIdMatch(documentUserId: document.userId, uid: uid)
            let existing = try fetchFoodEntryEntity(id: document.id)
            let context = mergeContext(
                uid: uid,
                remoteUpdatedAt: document.updatedAt,
                remoteDeletedAt: document.deletedAt,
                existing: existing,
                contentUpdatedAt: existing?.updatedAt
            )
            let decision = AccountSyncMergePolicy.decide(context)
            let now = nowProvider()
            let cloudId = document.id

            switch decision {
            case .insert:
                guard let dailyLog = try requiredDailyLogEntity(localDate: document.localDate, uid: uid) else {
                    stats.failed += 1
                    return
                }
                var entity = try CloudAccountDataMappers.entity(
                    from: document,
                    context: mappingContext(uid: uid)
                )
                entity.dailyLog = dailyLog
                AccountSyncRemoteMergeApplicator.stampInserted(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                try store.insert(entity)
                stats.inserted += 1

            case .update:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.apply(document, to: entity)
                AccountSyncRemoteMergeApplicator.stampUpdated(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                stats.updated += 1

            case .applyRemoteTombstone:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.applyRemoteTombstone(
                    on: entity,
                    remoteDeletedAt: document.deletedAt,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                entity.cloudId = cloudId
                stats.deleted += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict(let reason):
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt,
                        reason: reason
                    )
                    recordMergeConflict(
                        entityType: .foodEntry,
                        cloudId: cloudId,
                        reason: reason
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
                recordMergeConflict(
                    entityType: .foodEntry,
                    cloudId: cloudId,
                    reason: .ownerMismatch
                )
                stats.failed += 1
            }
        } catch {
            stats.failed += 1
        }
    }

    private func mergeWaterEntry(_ document: CloudWaterEntryDocument, uid: String, stats: inout PullStats) {
        do {
            try AccountDataRemoteStoreSupport.validateUserIdMatch(documentUserId: document.userId, uid: uid)
            let existing = try fetchWaterEntryEntity(id: document.id)
            let context = mergeContext(
                uid: uid,
                remoteUpdatedAt: document.updatedAt,
                remoteDeletedAt: document.deletedAt,
                existing: existing,
                contentUpdatedAt: existing?.createdAt
            )
            let decision = AccountSyncMergePolicy.decide(context)
            let now = nowProvider()
            let cloudId = document.id

            switch decision {
            case .insert:
                guard let dailyLog = try requiredDailyLogEntity(localDate: document.localDate, uid: uid) else {
                    stats.failed += 1
                    return
                }
                var entity = try CloudAccountDataMappers.entity(
                    from: document,
                    context: mappingContext(uid: uid)
                )
                entity.dailyLog = dailyLog
                AccountSyncRemoteMergeApplicator.stampInserted(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                try store.insert(entity)
                stats.inserted += 1

            case .update:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.apply(document, to: entity)
                AccountSyncRemoteMergeApplicator.stampUpdated(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                stats.updated += 1

            case .applyRemoteTombstone:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.applyRemoteTombstone(
                    on: entity,
                    remoteDeletedAt: document.deletedAt,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                entity.cloudId = cloudId
                stats.deleted += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict(let reason):
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt,
                        reason: reason
                    )
                    recordMergeConflict(
                        entityType: .waterEntry,
                        cloudId: cloudId,
                        reason: reason
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
                recordMergeConflict(
                    entityType: .waterEntry,
                    cloudId: cloudId,
                    reason: .ownerMismatch
                )
                stats.failed += 1
            }
        } catch {
            stats.failed += 1
        }
    }

    private func mergeWeightEntry(_ document: CloudWeightEntryDocument, uid: String, stats: inout PullStats) {
        do {
            try AccountDataRemoteStoreSupport.validateUserIdMatch(documentUserId: document.userId, uid: uid)
            let existing = try fetchWeightEntryEntity(id: document.id)
            let context = mergeContext(
                uid: uid,
                remoteUpdatedAt: document.updatedAt,
                remoteDeletedAt: document.deletedAt,
                existing: existing,
                contentUpdatedAt: existing?.createdAt
            )
            let decision = AccountSyncMergePolicy.decide(context)
            let now = nowProvider()
            let cloudId = document.id

            switch decision {
            case .insert:
                let entity = try CloudAccountDataMappers.entity(
                    from: document,
                    context: mappingContext(uid: uid)
                )
                AccountSyncRemoteMergeApplicator.stampInserted(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                try store.insert(entity)
                stats.inserted += 1

            case .update:
                guard let entity = existing else { return }
                try AccountSyncRemoteMergeApplicator.apply(document, to: entity, calendar: calendar)
                AccountSyncRemoteMergeApplicator.stampUpdated(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                stats.updated += 1

            case .applyRemoteTombstone:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.applyRemoteTombstone(
                    on: entity,
                    remoteDeletedAt: document.deletedAt,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                entity.cloudId = cloudId
                stats.deleted += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict(let reason):
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt,
                        reason: reason
                    )
                    recordMergeConflict(
                        entityType: .weightEntry,
                        cloudId: cloudId,
                        reason: reason
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
                recordMergeConflict(
                    entityType: .weightEntry,
                    cloudId: cloudId,
                    reason: .ownerMismatch
                )
                stats.failed += 1
            }
        } catch {
            stats.failed += 1
        }
    }

    private func mergeDailyReview(_ document: CloudDailyReviewDocument, uid: String, stats: inout PullStats) {
        do {
            try AccountDataRemoteStoreSupport.validateUserIdMatch(documentUserId: document.userId, uid: uid)
            let existing = try fetchDailyReviewEntity(localDate: document.localDate)
            let context = mergeContext(
                uid: uid,
                remoteUpdatedAt: document.updatedAt,
                remoteDeletedAt: document.deletedAt,
                existing: existing,
                contentUpdatedAt: existing?.createdAt
            )
            let decision = AccountSyncMergePolicy.decide(context)
            let now = nowProvider()
            let cloudId = document.localDate

            switch decision {
            case .insert:
                guard let dailyLog = try requiredDailyLogEntity(localDate: document.localDate, uid: uid) else {
                    stats.failed += 1
                    return
                }
                var entity = try CloudAccountDataMappers.entity(
                    from: document,
                    context: mappingContext(uid: uid)
                )
                entity.dailyLog = dailyLog
                dailyLog.dailyReview = entity
                dailyLog.dailyReviewId = entity.id
                AccountSyncRemoteMergeApplicator.stampInserted(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                try store.insert(entity)
                stats.inserted += 1

            case .update:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.apply(document, to: entity)
                AccountSyncRemoteMergeApplicator.stampUpdated(
                    on: entity,
                    cloudId: cloudId,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                stats.updated += 1

            case .applyRemoteTombstone:
                guard let entity = existing else { return }
                AccountSyncRemoteMergeApplicator.applyRemoteTombstone(
                    on: entity,
                    remoteDeletedAt: document.deletedAt,
                    remoteUpdatedAt: document.updatedAt,
                    now: now
                )
                entity.cloudId = cloudId
                stats.deleted += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict(let reason):
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt,
                        reason: reason
                    )
                    recordMergeConflict(
                        entityType: .dailyReview,
                        cloudId: cloudId,
                        reason: reason
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
                recordMergeConflict(
                    entityType: .dailyReview,
                    cloudId: cloudId,
                    reason: .ownerMismatch
                )
                stats.failed += 1
            }
        } catch {
            stats.failed += 1
        }
    }

    // MARK: - Helpers

    private struct PullStats {
        var dailyLogsFetched = 0
        var foodEntriesFetched = 0
        var waterEntriesFetched = 0
        var weightEntriesFetched = 0
        var dailyReviewsFetched = 0
        var inserted = 0
        var updated = 0
        var deleted = 0
        var skippedLocalNewer = 0
        var conflicts = 0
        var failed = 0

        func summary(uid: String) -> AccountSyncPullSummary {
            AccountSyncPullSummary(
                uid: uid,
                dailyLogsFetched: dailyLogsFetched,
                foodEntriesFetched: foodEntriesFetched,
                waterEntriesFetched: waterEntriesFetched,
                weightEntriesFetched: weightEntriesFetched,
                dailyReviewsFetched: dailyReviewsFetched,
                inserted: inserted,
                updated: updated,
                skippedLocalNewer: skippedLocalNewer,
                conflicts: conflicts,
                failed: failed
            )
        }

        var mergeBatchResult: AccountSyncMergeBatchResult {
            AccountSyncMergeBatchResult(
                inserted: inserted,
                updated: updated,
                deleted: deleted,
                skippedLocalNewer: skippedLocalNewer,
                conflicts: conflicts,
                failed: failed
            )
        }
    }

    private func mergeContext(
        uid: String,
        remoteUpdatedAt: Date,
        remoteDeletedAt: Date?,
        existing: (any AccountDataSyncMetadataEntity)?,
        contentUpdatedAt: Date?
    ) -> AccountSyncMergeContext {
        let ownerUID = (existing as? CloudAccountDataOwnerEntity)?.ownerUID
        return AccountSyncMergeContext(
            uid: uid,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            localExists: existing != nil,
            localOwnerUID: ownerUID,
            localSyncStatus: existing?.syncStatus,
            localEffectiveUpdatedAt: existing.map {
                AccountSyncMergePolicy.localEffectiveUpdatedAt(
                    syncMetadata: $0,
                    contentUpdatedAt: contentUpdatedAt ?? remoteUpdatedAt
                )
            }
        )
    }

    private func recordMergeConflict(
        entityType: AccountSyncEntityType,
        cloudId: String,
        reason: AccountSyncMergeConflictReason
    ) {
        CrossDeviceSyncLogger.mergeConflictDetected(
            traceId: nil,
            entityType: entityType,
            cloudIdSuffix: String(cloudId.suffix(6)),
            reason: reason
        )
    }

    private func mappingContext(uid: String) -> CloudAccountDataMappingContext {
        CloudAccountDataMappingContext(userId: uid, calendar: calendar, now: nowProvider())
    }

    private func requiredDailyLogEntity(localDate: String, uid: String) throws -> DailyLogEntity? {
        if let existing = try fetchDailyLogEntity(localDate: localDate) {
            if let owner = existing.ownerUID?.trimmingCharacters(in: .whitespacesAndNewlines),
               !owner.isEmpty,
               owner != uid {
                throw AccountSyncPullerError.ownerMismatch(expected: uid, actual: owner)
            }
            return existing
        }
        return nil
    }

    private func fetchDailyLogEntity(localDate: String) throws -> DailyLogEntity? {
        guard let date = CloudAccountDataDateCodec.date(fromLocalDateString: localDate, calendar: calendar) else {
            return nil
        }
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
        var descriptor = FetchDescriptor<DailyLogEntity>(
            predicate: #Predicate { log in log.date >= start && log.date < end }
        )
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchFoodEntryEntity(id: String) throws -> FoodEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<FoodEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchWaterEntryEntity(id: String) throws -> WaterEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WaterEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchWeightEntryEntity(id: String) throws -> WeightEntryEntity? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        var descriptor = FetchDescriptor<WeightEntryEntity>(predicate: #Predicate { $0.id == uuid })
        descriptor.fetchLimit = 1
        return try store.fetchOne(descriptor)
    }

    private func fetchDailyReviewEntity(localDate: String) throws -> DailyReviewEntity? {
        guard let log = try fetchDailyLogEntity(localDate: localDate) else { return nil }
        return log.dailyReview
    }

    private func emptySummary(uid: String) -> AccountSyncPullSummary {
        AccountSyncPullSummary(
            uid: uid,
            dailyLogsFetched: 0,
            foodEntriesFetched: 0,
            waterEntriesFetched: 0,
            weightEntriesFetched: 0,
            dailyReviewsFetched: 0,
            inserted: 0,
            updated: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0
        )
    }

    static func localDates(from startDate: String, to endDate: String, calendar: Calendar) -> [String] {
        guard let start = CloudAccountDataDateCodec.date(fromLocalDateString: startDate, calendar: calendar),
              let end = CloudAccountDataDateCodec.date(fromLocalDateString: endDate, calendar: calendar) else {
            return []
        }
        var dates: [String] = []
        var cursor = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        while cursor <= endDay {
            dates.append(CloudAccountDataDateCodec.localDateString(from: cursor, calendar: calendar))
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }

    static func defaultRecentDateRange(
        referenceDate: Date = Date(),
        dayCount: Int = defaultRecentPullDayCount,
        calendar: Calendar = defaultCalendar
    ) -> (start: String, end: String) {
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(dayCount - 1), to: end) ?? end
        return (
            CloudAccountDataDateCodec.localDateString(from: start, calendar: calendar),
            CloudAccountDataDateCodec.localDateString(from: end, calendar: calendar)
        )
    }

    nonisolated private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
