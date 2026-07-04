//
//  AccountIncrementalPuller.swift
//  Fitness Coach
//
//  Forma — Incremental cross-device pull and merge (Phase 5).
//
//  Fetches only remote documents changed since per-domain cursors and merges
//  into SwiftData using the Phase 3 merge policy.
//

import Foundation

protocol AccountIncrementalPulling: AnyObject {
    func pullChanges(
        for uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary
}

enum AccountIncrementalPullerSupport {

    static func dateRange(
        for mode: CrossDeviceSyncMode,
        referenceDate: Date,
        calendar: Calendar
    ) -> (start: String, end: String) {
        let lookbackDays = CrossDeviceSyncPolicy.pullLookbackDays(for: mode)
        let end = calendar.startOfDay(for: referenceDate)
        let start = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: end) ?? end
        return (
            CloudAccountDataDateCodec.localDateString(from: start, calendar: calendar),
            CloudAccountDataDateCodec.localDateString(from: end, calendar: calendar)
        )
    }

    static func maxUpdatedAt<T>(_ documents: [T], updatedAt: (T) -> Date) -> Date? {
        documents.map(updatedAt).max()
    }

    static func cursorAdvanceDate(
        fetchedDocumentsMaxUpdatedAt: Date?,
        mergeSucceeded: Bool
    ) -> Date? {
        guard mergeSucceeded, let fetchedDocumentsMaxUpdatedAt else { return nil }
        return fetchedDocumentsMaxUpdatedAt
    }
}

enum AccountIncrementalProfileMergeOutcome: Equatable {
    case merged(updatedAt: Date)
    case skippedNoRemoteChange
    case skippedLocalNewer
    case conflict
    case failed
}

@MainActor
final class AccountIncrementalPuller: AccountIncrementalPulling {

    private let remoteStore: any AccountDataRemoteStore
    private let mergePuller: AccountSyncPuller
    private let cursorStore: any AccountSyncCursorStoring
    private let profileBootstrapService: ProfileBootstrapService
    private let userProfileService: UserProfileService
    private let profileCloudSyncStore: ProfileCloudSyncStore
    private let localInspector: any AccountLocalDataInspecting
    private let currentUIDProvider: () -> String?
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let fetchLimit: Int

    init(
        remoteStore: any AccountDataRemoteStore,
        mergePuller: AccountSyncPuller,
        cursorStore: any AccountSyncCursorStoring,
        profileBootstrapService: ProfileBootstrapService,
        userProfileService: UserProfileService,
        profileCloudSyncStore: ProfileCloudSyncStore,
        localInspector: any AccountLocalDataInspecting,
        currentUIDProvider: @escaping () -> String?,
        calendar: Calendar = AccountIncrementalPuller.defaultCalendar,
        nowProvider: @escaping () -> Date = Date.init,
        fetchLimit: Int = AccountDataRemoteStoreIncrementalSupport.defaultFetchLimit
    ) {
        self.remoteStore = remoteStore
        self.mergePuller = mergePuller
        self.cursorStore = cursorStore
        self.profileBootstrapService = profileBootstrapService
        self.userProfileService = userProfileService
        self.profileCloudSyncStore = profileCloudSyncStore
        self.localInspector = localInspector
        self.currentUIDProvider = currentUIDProvider
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.fetchLimit = fetchLimit
    }

    func pullChanges(
        for uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason
    ) async -> CrossDeviceSyncSummary {
        let traceId = UUID().uuidString
        let startedAt = nowProvider()

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return failedSummary(
                traceId: traceId,
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                mode: mode,
                reason: reason,
                startedAt: startedAt,
                endedAt: nowProvider()
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return cancelledSummary(
                traceId: traceId,
                uid: normalizedUID,
                mode: mode,
                reason: reason,
                startedAt: startedAt,
                endedAt: nowProvider()
            )
        }

        _ = try? await localInspector.inspectLocalData(for: normalizedUID)

        let cursor = cursorStore.loadCursor(uid: normalizedUID)
        let dateRange = AccountIncrementalPullerSupport.dateRange(
            for: mode,
            referenceDate: startedAt,
            calendar: calendar
        )

        var pulledProfile = false
        var profileConflicts = 0
        var profileFailed = 0

        let profileOutcome = await pullAndMergeProfile(
            uid: normalizedUID,
            since: cursor.profileLastPulledAt
        )
        switch profileOutcome {
        case .merged:
            pulledProfile = true
        case .skippedNoRemoteChange, .skippedLocalNewer:
            break
        case .conflict:
            profileConflicts = 1
            CrossDeviceSyncLogger.profileMergeConflictDetected(traceId: traceId, uid: uid)
        case .failed:
            profileFailed = 1
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return cancelledSummary(
                traceId: traceId,
                uid: normalizedUID,
                mode: mode,
                reason: reason,
                startedAt: startedAt,
                endedAt: nowProvider()
            )
        }

        let dailyLogsResult = await pullDomain(
            uid: normalizedUID,
            since: cursor.dailyLogsLastPulledAt
        ) {
            try await self.remoteStore.fetchDailyLogsUpdatedSince(
                uid: normalizedUID,
                since: $0,
                limit: self.fetchLimit
            )
        }

        let foodEntriesResult = await pullDomain(
            uid: normalizedUID,
            since: cursor.foodEntriesLastPulledAt
        ) {
            try await self.remoteStore.fetchFoodEntriesUpdatedSince(
                uid: normalizedUID,
                since: $0,
                from: dateRange.start,
                to: dateRange.end,
                limit: self.fetchLimit
            )
        }

        let waterEntriesResult = await pullDomain(
            uid: normalizedUID,
            since: cursor.waterEntriesLastPulledAt
        ) {
            try await self.remoteStore.fetchWaterEntriesUpdatedSince(
                uid: normalizedUID,
                since: $0,
                from: dateRange.start,
                to: dateRange.end,
                limit: self.fetchLimit
            )
        }

        let weightEntriesResult = await pullDomain(
            uid: normalizedUID,
            since: cursor.weightEntriesLastPulledAt
        ) {
            try await self.remoteStore.fetchWeightEntriesUpdatedSince(
                uid: normalizedUID,
                since: $0,
                limit: self.fetchLimit
            )
        }

        let dailyReviewsResult = await pullDomain(
            uid: normalizedUID,
            since: cursor.dailyReviewsLastPulledAt
        ) {
            try await self.remoteStore.fetchDailyReviewsUpdatedSince(
                uid: normalizedUID,
                since: $0,
                limit: self.fetchLimit
            )
        }

        let dailyLogsMerge = mergeDomain(
            uid: normalizedUID,
            fetchResult: dailyLogsResult,
            merge: {
                try mergePuller.mergeFetchedDocuments(
                    for: normalizedUID,
                    dailyLogs: dailyLogsResult.documents,
                    foodEntries: [],
                    waterEntries: [],
                    weightEntries: [],
                    dailyReviews: []
                )
            }
        )

        let foodEntriesMerge = mergeDomain(
            uid: normalizedUID,
            fetchResult: foodEntriesResult,
            merge: {
                try mergePuller.mergeFetchedDocuments(
                    for: normalizedUID,
                    dailyLogs: [],
                    foodEntries: foodEntriesResult.documents,
                    waterEntries: [],
                    weightEntries: [],
                    dailyReviews: []
                )
            }
        )

        let waterEntriesMerge = mergeDomain(
            uid: normalizedUID,
            fetchResult: waterEntriesResult,
            merge: {
                try mergePuller.mergeFetchedDocuments(
                    for: normalizedUID,
                    dailyLogs: [],
                    foodEntries: [],
                    waterEntries: waterEntriesResult.documents,
                    weightEntries: [],
                    dailyReviews: []
                )
            }
        )

        let weightEntriesMerge = mergeDomain(
            uid: normalizedUID,
            fetchResult: weightEntriesResult,
            merge: {
                try mergePuller.mergeFetchedDocuments(
                    for: normalizedUID,
                    dailyLogs: [],
                    foodEntries: [],
                    waterEntries: [],
                    weightEntries: weightEntriesResult.documents,
                    dailyReviews: []
                )
            }
        )

        let dailyReviewsMerge = mergeDomain(
            uid: normalizedUID,
            fetchResult: dailyReviewsResult,
            merge: {
                try mergePuller.mergeFetchedDocuments(
                    for: normalizedUID,
                    dailyLogs: [],
                    foodEntries: [],
                    waterEntries: [],
                    weightEntries: [],
                    dailyReviews: dailyReviewsResult.documents
                )
            }
        )

        if case .merged(let profileUpdatedAt) = profileOutcome {
            cursorStore.updateCursor(uid: normalizedUID, domain: .profile, date: profileUpdatedAt)
        }

        applyCursorUpdate(
            uid: normalizedUID,
            domain: .dailyLogs,
            fetchResult: dailyLogsResult,
            mergeResult: dailyLogsMerge
        )
        applyCursorUpdate(
            uid: normalizedUID,
            domain: .foodEntries,
            fetchResult: foodEntriesResult,
            mergeResult: foodEntriesMerge
        )
        applyCursorUpdate(
            uid: normalizedUID,
            domain: .waterEntries,
            fetchResult: waterEntriesResult,
            mergeResult: waterEntriesMerge
        )
        applyCursorUpdate(
            uid: normalizedUID,
            domain: .weightEntries,
            fetchResult: weightEntriesResult,
            mergeResult: weightEntriesMerge
        )
        applyCursorUpdate(
            uid: normalizedUID,
            domain: .dailyReviews,
            fetchResult: dailyReviewsResult,
            mergeResult: dailyReviewsMerge
        )

        recordRefreshTimestamp(uid: normalizedUID, mode: mode, date: nowProvider())

        let mergeTotals = [
            dailyLogsMerge,
            foodEntriesMerge,
            waterEntriesMerge,
            weightEntriesMerge,
            dailyReviewsMerge
        ].compactMap { $0 }

        let domainFailures = domainFetchFailures(
            dailyLogsResult,
            foodEntriesResult,
            waterEntriesResult,
            weightEntriesResult,
            dailyReviewsResult
        )
        let totalFailed = mergeTotals.reduce(0) { $0 + $1.failed } + profileFailed + domainFailures
        let totalConflicts = mergeTotals.reduce(0) { $0 + $1.conflicts } + profileConflicts
        let endedAt = nowProvider()
        let status: CrossDeviceSyncStatus = (totalFailed > 0 || totalConflicts > 0) ? .partial : .completed

        let summary = CrossDeviceSyncSummary(
            uid: normalizedUID,
            mode: mode,
            reason: reason,
            status: status,
            startedAt: startedAt,
            endedAt: endedAt,
            uploadedMutations: 0,
            pulledDailyLogs: dailyLogsResult.documents.count,
            pulledFoodEntries: foodEntriesResult.documents.count,
            pulledWaterEntries: waterEntriesResult.documents.count,
            pulledWeightEntries: weightEntriesResult.documents.count,
            pulledDailyReviews: dailyReviewsResult.documents.count,
            pulledProfile: pulledProfile,
            inserted: mergeTotals.reduce(0) { $0 + $1.inserted },
            updated: mergeTotals.reduce(0) { $0 + $1.updated },
            deleted: mergeTotals.reduce(0) { $0 + $1.deleted },
            skippedLocalNewer: mergeTotals.reduce(0) { $0 + $1.skippedLocalNewer },
            conflicts: totalConflicts,
            failed: totalFailed,
            didRefreshUI: false,
            userFacingMessage: nil
        )
        CrossDeviceSyncLogger.incrementalPullCompleted(traceId: traceId, summary: summary)
        return summary
    }

    // MARK: - Profile

    private func pullAndMergeProfile(
        uid: String,
        since: Date?
    ) async -> AccountIncrementalProfileMergeOutcome {
        do {
            guard let remoteDocument = try await remoteStore.fetchCloudProfileUpdatedSince(uid: uid, since: since) else {
                return .skippedNoRemoteChange
            }

            if let localProfile = try userProfileService.getCurrentProfile() {
                guard localProfile.ownerUID == uid else {
                    return .failed
                }

                if profileBootstrapService.hasUnsyncedLocalProfileChanges(localProfile, uid: uid) {
                    if remoteDocument.updatedAt > localProfile.updatedAt {
                        return .conflict
                    }
                    return .skippedLocalNewer
                }

                if remoteDocument.updatedAt <= localProfile.updatedAt {
                    return .skippedNoRemoteChange
                }

                var mergedDocument = remoteDocument
                mergedDocument.onboardingCompletedAt = localProfile.createdAt
                _ = try profileBootstrapService.adoptCloudProfile(mergedDocument, uid: uid)
                return .merged(updatedAt: remoteDocument.updatedAt)
            }

            _ = try profileBootstrapService.adoptCloudProfile(remoteDocument, uid: uid)
            return .merged(updatedAt: remoteDocument.updatedAt)
        } catch {
            return .failed
        }
    }

    // MARK: - Domain fetch

    private struct DomainFetchResult<Document> {
        let documents: [Document]
        let fetchFailed: Bool
        let maxUpdatedAt: Date?

        static func failure() -> DomainFetchResult<Document> {
            DomainFetchResult(documents: [], fetchFailed: true, maxUpdatedAt: nil)
        }
    }

    private func pullDomain<Document>(
        uid: String,
        since: Date?,
        fetch: (Date?) async throws -> [Document]
    ) async -> DomainFetchResult<Document> where Document: CloudAccountDataDocument {
        guard isUIDStillCurrent(uid) else {
            return .failure()
        }

        do {
            let documents = try await fetch(since)
            let filtered = documents.filter {
                CrossDeviceSyncPolicy.mayApplyRemoteDocument(documentUserId: $0.userId, sessionUID: uid)
            }
            let maxUpdatedAt = AccountIncrementalPullerSupport.maxUpdatedAt(filtered) { $0.updatedAt }
            return DomainFetchResult(
                documents: filtered,
                fetchFailed: false,
                maxUpdatedAt: maxUpdatedAt
            )
        } catch {
            return .failure()
        }
    }

    private func mergeDomain<Document: CloudAccountDataDocument>(
        uid: String,
        fetchResult: DomainFetchResult<Document>,
        merge: () throws -> AccountSyncMergeBatchResult
    ) -> AccountSyncMergeBatchResult? {
        guard isUIDStillCurrent(uid), !fetchResult.fetchFailed else { return nil }
        return try? merge()
    }

    private func applyCursorUpdate<Document: CloudAccountDataDocument>(
        uid: String,
        domain: AccountSyncCursorDomain,
        fetchResult: DomainFetchResult<Document>,
        mergeResult: AccountSyncMergeBatchResult?
    ) where Document: CloudAccountDataDocument {
        guard let mergeResult, mergeResult.failed == 0 else { return }
        guard let advanceDate = AccountIncrementalPullerSupport.cursorAdvanceDate(
            fetchedDocumentsMaxUpdatedAt: fetchResult.maxUpdatedAt,
            mergeSucceeded: true
        ) else {
            return
        }
        cursorStore.updateCursor(uid: uid, domain: domain, date: advanceDate)
    }

    private func domainFetchFailures(
        _ dailyLogs: DomainFetchResult<CloudDailyLogDocument>,
        _ foodEntries: DomainFetchResult<CloudFoodEntryDocument>,
        _ waterEntries: DomainFetchResult<CloudWaterEntryDocument>,
        _ weightEntries: DomainFetchResult<CloudWeightEntryDocument>,
        _ dailyReviews: DomainFetchResult<CloudDailyReviewDocument>
    ) -> Int {
        [
            dailyLogs.fetchFailed,
            foodEntries.fetchFailed,
            waterEntries.fetchFailed,
            weightEntries.fetchFailed,
            dailyReviews.fetchFailed
        ].filter { $0 }.count
    }

    private func recordRefreshTimestamp(uid: String, mode: CrossDeviceSyncMode, date: Date) {
        switch mode {
        case .foregroundRefresh, .afterRemoteChange, .realtimeListener, .backgroundRefresh:
            cursorStore.updateForegroundRefresh(uid: uid, date: date)
        case .manualRefresh:
            cursorStore.updateManualRefresh(uid: uid, date: date)
        }
    }

    // MARK: - Summary helpers

    private func failedSummary(
        traceId: String,
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date,
        endedAt: Date
    ) -> CrossDeviceSyncSummary {
        let summary = CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .failed,
            startedAt: startedAt,
            endedAt: endedAt,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 1,
            didRefreshUI: false,
            userFacingMessage: nil
        )
        CrossDeviceSyncLogger.incrementalPullCompleted(traceId: traceId, summary: summary)
        return summary
    }

    private func cancelledSummary(
        traceId: String,
        uid: String,
        mode: CrossDeviceSyncMode,
        reason: CrossDeviceSyncReason,
        startedAt: Date,
        endedAt: Date
    ) -> CrossDeviceSyncSummary {
        let summary = CrossDeviceSyncSummary(
            uid: uid,
            mode: mode,
            reason: reason,
            status: .cancelled,
            startedAt: startedAt,
            endedAt: endedAt,
            uploadedMutations: 0,
            pulledDailyLogs: 0,
            pulledFoodEntries: 0,
            pulledWaterEntries: 0,
            pulledWeightEntries: 0,
            pulledDailyReviews: 0,
            pulledProfile: false,
            inserted: 0,
            updated: 0,
            deleted: 0,
            skippedLocalNewer: 0,
            conflicts: 0,
            failed: 0,
            didRefreshUI: false,
            userFacingMessage: nil
        )
        CrossDeviceSyncLogger.incrementalPullCompleted(traceId: traceId, summary: summary)
        return summary
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = currentUIDProvider() else { return false }
        return (try? AccountSyncMutationValidation.normalizedOwnerUID(currentUID)) == uid
    }

    nonisolated private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}
