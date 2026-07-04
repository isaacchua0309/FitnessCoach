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

protocol AccountSyncPulling: AnyObject {
    func pullRecentAccountData(
        for uid: String,
        from startDate: String,
        to endDate: String
    ) async -> AccountSyncPullSummary
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
        let normalizedUID: String
        let range: (String, String)
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
            range = try AccountDataRemoteStoreSupport.validateDateRange(from: startDate, to: endDate)
        } catch {
            return emptySummary(uid: uid.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var stats = PullStats()
        let localDates = Self.localDates(from: range.0, to: range.1, calendar: calendar)

        do {
            let dailyLogs = try await remoteStore.fetchDailyLogs(
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

        for localDate in localDates {
            do {
                let foodEntries = try await remoteStore.fetchFoodEntries(uid: normalizedUID, localDate: localDate)
                stats.foodEntriesFetched += foodEntries.count
                for document in foodEntries {
                    mergeFoodEntry(document, uid: normalizedUID, stats: &stats)
                }
            } catch {
                stats.failed += 1
            }

            do {
                let waterEntries = try await remoteStore.fetchWaterEntries(uid: normalizedUID, localDate: localDate)
                stats.waterEntriesFetched += waterEntries.count
                for document in waterEntries {
                    mergeWaterEntry(document, uid: normalizedUID, stats: &stats)
                }
            } catch {
                stats.failed += 1
            }

            do {
                if let review = try await remoteStore.fetchDailyReview(uid: normalizedUID, localDate: localDate) {
                    stats.dailyReviewsFetched += 1
                    mergeDailyReview(review, uid: normalizedUID, stats: &stats)
                }
            } catch {
                stats.failed += 1
            }
        }

        do {
            let weightEntries = try await remoteStore.fetchWeightEntries(
                uid: normalizedUID,
                from: range.0,
                to: range.1
            )
            stats.weightEntriesFetched = weightEntries.count
            for document in weightEntries {
                mergeWeightEntry(document, uid: normalizedUID, stats: &stats)
            }
        } catch {
            stats.failed += 1
        }

        try? store.save()

        return stats.summary(uid: normalizedUID)
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
                stats.updated += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict:
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
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
                stats.updated += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict:
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
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
                stats.updated += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict:
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
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
                stats.updated += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict:
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
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
                stats.updated += 1

            case .skipStaleRemote, .skipRemoteDeletedNoLocal:
                break

            case .skipLocalNewer:
                stats.skippedLocalNewer += 1

            case .conflict:
                if let entity = existing {
                    AccountSyncRemoteMergeApplicator.markConflict(
                        on: entity,
                        remoteUpdatedAt: document.updatedAt
                    )
                }
                stats.conflicts += 1

            case .failedOwnerMismatch:
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

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
