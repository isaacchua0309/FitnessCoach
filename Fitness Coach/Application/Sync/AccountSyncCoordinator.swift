//
//  AccountSyncCoordinator.swift
//  Fitness Coach
//
//  Forma — Coordinates account sync upload/pull without repository or UI coupling (Phase 3).
//

import Foundation

enum AccountSyncReason: String, Equatable, Sendable, CaseIterable {
    case appForeground
    case manual
    case afterLocalMutation
    case afterSignIn
    case retry
}

struct AccountSyncRunSummary: Equatable, Sendable {
    let uid: String
    let reason: AccountSyncReason
    let startedAt: Date
    let endedAt: Date
    let uploadSummary: AccountSyncUploadSummary?
    let pullSummary: AccountSyncPullSummary?
    let didSkip: Bool
    let skipReason: String?
}

protocol AccountSyncCoordinating: AnyObject {
    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary
    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary
    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary
    func cancelPendingWork()
    func cancelAllWork(for uid: String) async
    func reinstateWork(for uid: String)
}

extension AccountSyncCoordinating {
    func cancelAllWork(for uid: String) async {
        cancelPendingWork()
    }

    func reinstateWork(for uid: String) {}
}

/// Optional network gate for sync. Defaults to available when no reachability service exists.
protocol AccountSyncNetworkChecking: Sendable {
    var isNetworkAvailable: Bool { get }
}

struct AlwaysAvailableAccountSyncNetworkChecker: AccountSyncNetworkChecking {
    var isNetworkAvailable: Bool { true }
}

enum AccountSyncCoordinatorSkipReason {
    static let syncEngineDisabled = "syncEngineDisabled"
    static let missingUID = "missingUID"
    static let networkUnavailable = "networkUnavailable"
    static let syncAlreadyInProgress = "syncAlreadyInProgress"
    static let uidChanged = "uidChanged"
    static let uploadDisabled = "uploadDisabled"
    static let pullDisabled = "pullDisabled"
    static let debouncedUploadScheduled = "debouncedUploadScheduled"
    static let deletionInProgress = "deletionInProgress"
}

@MainActor
final class AccountSyncCoordinator: AccountSyncCoordinating {

    static let defaultUploadBatchLimit = 50

    private let uploader: AccountSyncUploading
    private let puller: AccountSyncPulling
    private let networkChecker: any AccountSyncNetworkChecking
    private let currentUIDProvider: () -> String?
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let uploadBatchLimit: Int
    private let pullDayCount: Int
    private let debounceInterval: Duration
    private let deletionGuard: AccountDeletionGuarding?
    private let runGuard = AccountSyncRunGuard()
    private let diagnostics: AccountSyncDiagnostics?

    private var debouncedUploadTask: Task<Void, Never>?
    private var debouncedUploadUID: String?

    init(
        uploader: AccountSyncUploading,
        puller: AccountSyncPulling,
        networkChecker: any AccountSyncNetworkChecking = AlwaysAvailableAccountSyncNetworkChecker(),
        currentUIDProvider: @escaping () -> String?,
        calendar: Calendar = AccountSyncCoordinator.defaultCalendar,
        nowProvider: @escaping () -> Date = Date.init,
        uploadBatchLimit: Int = AccountSyncCoordinator.defaultUploadBatchLimit,
        pullDayCount: Int = AccountSyncPuller.defaultRecentPullDayCount,
        debounceInterval: Duration = .seconds(2),
        diagnostics: AccountSyncDiagnostics? = nil,
        deletionGuard: AccountDeletionGuarding? = nil
    ) {
        self.uploader = uploader
        self.puller = puller
        self.networkChecker = networkChecker
        self.currentUIDProvider = currentUIDProvider
        self.calendar = calendar
        self.nowProvider = nowProvider
        self.uploadBatchLimit = uploadBatchLimit
        self.pullDayCount = pullDayCount
        self.debounceInterval = debounceInterval
        self.diagnostics = diagnostics
        self.deletionGuard = deletionGuard
    }

    func syncNow(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        switch reason {
        case .afterLocalMutation:
            return await uploadPendingOnly(for: uid, reason: reason)

        case .afterSignIn:
            return await run(
                for: uid,
                reason: reason,
                includeUpload: AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled,
                includePull: shouldPullAfterSignIn
            )

        case .appForeground:
            return await run(
                for: uid,
                reason: reason,
                includeUpload: AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled,
                includePull: AccountPersistenceFeatureFlags.pullRecentDataEnabled
            )

        case .manual, .retry:
            return await run(
                for: uid,
                reason: reason,
                includeUpload: AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled,
                includePull: AccountPersistenceFeatureFlags.pullRecentDataEnabled
            )
        }
    }

    func uploadPendingOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        if reason == .afterLocalMutation {
            return scheduleDebouncedUpload(for: uid, reason: reason)
        }

        return await run(
            for: uid,
            reason: reason,
            includeUpload: true,
            includePull: false
        )
    }

    func pullRecentOnly(for uid: String, reason: AccountSyncReason) async -> AccountSyncRunSummary {
        await run(
            for: uid,
            reason: reason,
            includeUpload: false,
            includePull: true
        )
    }

    func cancelPendingWork() {
        debouncedUploadTask?.cancel()
        debouncedUploadTask = nil
        debouncedUploadUID = nil
    }

    func cancelAllWork(for uid: String) async {
        guard let normalizedUID = normalizedUID(uid) else { return }
        runGuard.invalidate(uid: normalizedUID)
        if debouncedUploadUID == normalizedUID {
            debouncedUploadTask?.cancel()
            debouncedUploadTask = nil
            debouncedUploadUID = nil
        }
        await runGuard.waitUntilIdle(uid: normalizedUID, timeout: .seconds(5))
    }

    func reinstateWork(for uid: String) {
        guard let normalizedUID = normalizedUID(uid) else { return }
        runGuard.reinstate(uid: normalizedUID)
    }

    // MARK: - Core run loop

    private func run(
        for uid: String,
        reason: AccountSyncReason,
        includeUpload: Bool,
        includePull: Bool
    ) async -> AccountSyncRunSummary {
        let traceId = UUID().uuidString
        let startedAt = nowProvider()

        guard AccountPersistenceFeatureFlags.syncEngineEnabled else {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: uid,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.syncEngineDisabled
                )
            )
        }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.missingUID
                )
            )
        }

        AccountSyncLogger.runStarted(traceId: traceId, reason: reason, uid: normalizedUID)

        if let blockedSummary = blockedSummaryIfNeeded(
            uid: normalizedUID,
            reason: reason,
            startedAt: startedAt,
            traceId: traceId
        ) {
            return blockedSummary
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.uidChanged
                )
            )
        }

        guard networkChecker.isNetworkAvailable else {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.networkUnavailable
                )
            )
        }

        guard runGuard.tryBegin(uid: normalizedUID) else {
            let skipReason = runGuard.isInvalidated(uid: normalizedUID)
                || deletionGuard?.isDeletionInProgress(for: normalizedUID) == true
                ? AccountSyncCoordinatorSkipReason.deletionInProgress
                : AccountSyncCoordinatorSkipReason.syncAlreadyInProgress
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: skipReason
                )
            )
        }

        defer {
            runGuard.end(uid: normalizedUID)
        }

        var uploadSummary: AccountSyncUploadSummary?
        var pullSummary: AccountSyncPullSummary?

        if includeUpload {
            guard AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled else {
                return recordAndReturn(
                    traceId: traceId,
                    summary: skippedSummary(
                        uid: normalizedUID,
                        reason: reason,
                        startedAt: startedAt,
                        skipReason: AccountSyncCoordinatorSkipReason.uploadDisabled
                    )
                )
            }

            if let blockedSummary = blockedSummaryIfNeeded(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                traceId: traceId,
                uploadSummary: nil
            ) {
                return blockedSummary
            }

            uploadSummary = await uploader.uploadDueMutations(
                for: normalizedUID,
                limit: uploadBatchLimit
            )

            if let blockedSummary = blockedSummaryIfNeeded(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                traceId: traceId,
                uploadSummary: uploadSummary
            ) {
                return blockedSummary
            }
        }

        if includePull {
            guard AccountPersistenceFeatureFlags.pullRecentDataEnabled else {
                return recordAndReturn(
                    traceId: traceId,
                    summary: AccountSyncRunSummary(
                        uid: normalizedUID,
                        reason: reason,
                        startedAt: startedAt,
                        endedAt: nowProvider(),
                        uploadSummary: uploadSummary,
                        pullSummary: nil,
                        didSkip: true,
                        skipReason: AccountSyncCoordinatorSkipReason.pullDisabled
                    )
                )
            }

            if let blockedSummary = blockedSummaryIfNeeded(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                traceId: traceId,
                uploadSummary: uploadSummary
            ) {
                return blockedSummary
            }

            let range = AccountSyncPuller.defaultRecentDateRange(
                referenceDate: nowProvider(),
                dayCount: pullDayCount,
                calendar: calendar
            )
            pullSummary = await puller.pullRecentAccountData(
                for: normalizedUID,
                from: range.start,
                to: range.end
            )

            if let blockedSummary = blockedSummaryIfNeeded(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                traceId: traceId,
                uploadSummary: uploadSummary,
                pullSummary: pullSummary
            ) {
                return blockedSummary
            }
        }

        return recordAndReturn(
            traceId: traceId,
            summary: AccountSyncRunSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                endedAt: nowProvider(),
                uploadSummary: uploadSummary,
                pullSummary: pullSummary,
                didSkip: false,
                skipReason: nil
            )
        )
    }

    // MARK: - Debounced upload

    private func scheduleDebouncedUpload(
        for uid: String,
        reason: AccountSyncReason
    ) -> AccountSyncRunSummary {
        let traceId = UUID().uuidString
        let startedAt = nowProvider()

        guard AccountPersistenceFeatureFlags.syncEngineEnabled else {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: uid,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.syncEngineDisabled
                )
            )
        }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return recordAndReturn(
                traceId: traceId,
                summary: skippedSummary(
                    uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.missingUID
                )
            )
        }

        AccountSyncLogger.runStarted(traceId: traceId, reason: reason, uid: normalizedUID)

        if let blockedSummary = blockedSummaryIfNeeded(
            uid: normalizedUID,
            reason: reason,
            startedAt: startedAt,
            traceId: traceId
        ) {
            return blockedSummary
        }

        debouncedUploadTask?.cancel()
        debouncedUploadUID = normalizedUID
        debouncedUploadTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            guard self.debouncedUploadUID == normalizedUID else { return }
            guard self.shouldProceed(for: normalizedUID) else { return }
            _ = await self.run(
                for: normalizedUID,
                reason: reason,
                includeUpload: true,
                includePull: false
            )
        }

        return recordAndReturn(
            traceId: traceId,
            summary: skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.debouncedUploadScheduled
            )
        )
    }

    // MARK: - Helpers

    private func recordAndReturn(traceId: String, summary: AccountSyncRunSummary) -> AccountSyncRunSummary {
        diagnostics?.recordRun(traceId: traceId, summary: summary)
        return summary
    }

    private var shouldPullAfterSignIn: Bool {
        AccountPersistenceFeatureFlags.pullRecentDataEnabled
            && !AccountPersistenceFeatureFlags.restoreOnLoginEnabled
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = currentUIDProvider() else { return false }
        return (try? AccountSyncMutationValidation.normalizedOwnerUID(currentUID)) == uid
    }

    private func shouldProceed(for uid: String) -> Bool {
        if deletionGuard?.isDeletionInProgress(for: uid) == true {
            return false
        }
        if runGuard.isInvalidated(uid: uid) {
            return false
        }
        return isUIDStillCurrent(uid)
    }

    private func blockedSummaryIfNeeded(
        uid: String,
        reason: AccountSyncReason,
        startedAt: Date,
        traceId: String,
        uploadSummary: AccountSyncUploadSummary? = nil,
        pullSummary: AccountSyncPullSummary? = nil
    ) -> AccountSyncRunSummary? {
        guard !shouldProceed(for: uid) else { return nil }
        return recordAndReturn(
            traceId: traceId,
            summary: AccountSyncRunSummary(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                endedAt: nowProvider(),
                uploadSummary: uploadSummary,
                pullSummary: pullSummary,
                didSkip: true,
                skipReason: cancellationSkipReason(for: uid)
            )
        )
    }

    private func cancellationSkipReason(for uid: String) -> String {
        if deletionGuard?.isDeletionInProgress(for: uid) == true
            || runGuard.isInvalidated(uid: uid) {
            return AccountSyncCoordinatorSkipReason.deletionInProgress
        }
        return AccountSyncCoordinatorSkipReason.uidChanged
    }

    private func normalizedUID(_ uid: String) -> String? {
        try? AccountSyncMutationValidation.normalizedOwnerUID(uid)
    }

    private func skippedSummary(
        uid: String,
        reason: AccountSyncReason,
        startedAt: Date,
        skipReason: String
    ) -> AccountSyncRunSummary {
        AccountSyncRunSummary(
            uid: uid,
            reason: reason,
            startedAt: startedAt,
            endedAt: nowProvider(),
            uploadSummary: nil,
            pullSummary: nil,
            didSkip: true,
            skipReason: skipReason
        )
    }

    nonisolated private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

// MARK: - Per-UID run guard

@MainActor
private final class AccountSyncRunGuard {

    private var activeUIDs = Set<String>()
    private var invalidatedUIDs = Set<String>()

    func tryBegin(uid: String) -> Bool {
        guard !invalidatedUIDs.contains(uid) else { return false }
        guard !activeUIDs.contains(uid) else { return false }
        activeUIDs.insert(uid)
        return true
    }

    func end(uid: String) {
        activeUIDs.remove(uid)
    }

    func invalidate(uid: String) {
        invalidatedUIDs.insert(uid)
    }

    func reinstate(uid: String) {
        invalidatedUIDs.remove(uid)
    }

    func isInvalidated(uid: String) -> Bool {
        invalidatedUIDs.contains(uid)
    }

    func waitUntilIdle(uid: String, timeout: Duration) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while activeUIDs.contains(uid), clock.now < deadline {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(20))
        }
    }
}
