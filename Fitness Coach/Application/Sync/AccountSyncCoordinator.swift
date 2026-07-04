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
    private let runGuard = AccountSyncRunGuard()

    private var debouncedUploadTask: Task<Void, Never>?

    init(
        uploader: AccountSyncUploading,
        puller: AccountSyncPulling,
        networkChecker: any AccountSyncNetworkChecking = AlwaysAvailableAccountSyncNetworkChecker(),
        currentUIDProvider: @escaping () -> String?,
        calendar: Calendar = AccountSyncCoordinator.defaultCalendar,
        nowProvider: @escaping () -> Date = Date.init,
        uploadBatchLimit: Int = AccountSyncCoordinator.defaultUploadBatchLimit,
        pullDayCount: Int = AccountSyncPuller.defaultRecentPullDayCount,
        debounceInterval: Duration = .seconds(2)
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
    }

    // MARK: - Core run loop

    private func run(
        for uid: String,
        reason: AccountSyncReason,
        includeUpload: Bool,
        includePull: Bool
    ) async -> AccountSyncRunSummary {
        let startedAt = nowProvider()

        guard AccountPersistenceFeatureFlags.syncEngineEnabled else {
            return skippedSummary(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.syncEngineDisabled
            )
        }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return skippedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.missingUID
            )
        }

        guard isUIDStillCurrent(normalizedUID) else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.uidChanged
            )
        }

        guard networkChecker.isNetworkAvailable else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.networkUnavailable
            )
        }

        guard runGuard.tryBegin(uid: normalizedUID) else {
            return skippedSummary(
                uid: normalizedUID,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.syncAlreadyInProgress
            )
        }

        defer {
            runGuard.end(uid: normalizedUID)
        }

        var uploadSummary: AccountSyncUploadSummary?
        var pullSummary: AccountSyncPullSummary?

        if includeUpload {
            guard AccountPersistenceFeatureFlags.uploadPendingMutationsEnabled else {
                return skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.uploadDisabled
                )
            }

            guard isUIDStillCurrent(normalizedUID) else {
                return skippedSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    skipReason: AccountSyncCoordinatorSkipReason.uidChanged
                )
            }

            uploadSummary = await uploader.uploadDueMutations(
                for: normalizedUID,
                limit: uploadBatchLimit
            )
        }

        if includePull {
            guard AccountPersistenceFeatureFlags.pullRecentDataEnabled else {
                return AccountSyncRunSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    endedAt: nowProvider(),
                    uploadSummary: uploadSummary,
                    pullSummary: nil,
                    didSkip: true,
                    skipReason: AccountSyncCoordinatorSkipReason.pullDisabled
                )
            }

            guard isUIDStillCurrent(normalizedUID) else {
                return AccountSyncRunSummary(
                    uid: normalizedUID,
                    reason: reason,
                    startedAt: startedAt,
                    endedAt: nowProvider(),
                    uploadSummary: uploadSummary,
                    pullSummary: nil,
                    didSkip: true,
                    skipReason: AccountSyncCoordinatorSkipReason.uidChanged
                )
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
        }

        return AccountSyncRunSummary(
            uid: normalizedUID,
            reason: reason,
            startedAt: startedAt,
            endedAt: nowProvider(),
            uploadSummary: uploadSummary,
            pullSummary: pullSummary,
            didSkip: false,
            skipReason: nil
        )
    }

    // MARK: - Debounced upload

    private func scheduleDebouncedUpload(
        for uid: String,
        reason: AccountSyncReason
    ) -> AccountSyncRunSummary {
        let startedAt = nowProvider()

        guard AccountPersistenceFeatureFlags.syncEngineEnabled else {
            return skippedSummary(
                uid: uid,
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.syncEngineDisabled
            )
        }

        let normalizedUID: String
        do {
            normalizedUID = try AccountSyncMutationValidation.normalizedOwnerUID(uid)
        } catch {
            return skippedSummary(
                uid: uid.trimmingCharacters(in: .whitespacesAndNewlines),
                reason: reason,
                startedAt: startedAt,
                skipReason: AccountSyncCoordinatorSkipReason.missingUID
            )
        }

        debouncedUploadTask?.cancel()
        debouncedUploadTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: debounceInterval)
            guard !Task.isCancelled else { return }
            guard self.isUIDStillCurrent(normalizedUID) else { return }
            _ = await self.run(
                for: normalizedUID,
                reason: reason,
                includeUpload: true,
                includePull: false
            )
        }

        return skippedSummary(
            uid: normalizedUID,
            reason: reason,
            startedAt: startedAt,
            skipReason: AccountSyncCoordinatorSkipReason.debouncedUploadScheduled
        )
    }

    // MARK: - Helpers

    private var shouldPullAfterSignIn: Bool {
        AccountPersistenceFeatureFlags.pullRecentDataEnabled
            && !AccountPersistenceFeatureFlags.restoreOnLoginEnabled
    }

    private func isUIDStillCurrent(_ uid: String) -> Bool {
        guard let currentUID = currentUIDProvider() else { return false }
        return (try? AccountSyncMutationValidation.normalizedOwnerUID(currentUID)) == uid
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

    private static var defaultCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

// MARK: - Per-UID run guard

@MainActor
private final class AccountSyncRunGuard {

    private var activeUIDs = Set<String>()

    func tryBegin(uid: String) -> Bool {
        guard !activeUIDs.contains(uid) else { return false }
        activeUIDs.insert(uid)
        return true
    }

    func end(uid: String) {
        activeUIDs.remove(uid)
    }
}
