//
//  SettingsPrivacyDataStatusProvider.swift
//  Fitness Coach
//
//  Forma — Builds privacy-safe account/sync status for Settings.
//

import Foundation

@MainActor
struct SettingsPrivacyDataStatusProvider {

    let authManager: AuthManager
    let accountRestoreStateStore: AccountRestoreStateStore
    let accountRestoreSessionState: AccountRestoreSessionState
    let accountSyncDiagnostics: AccountSyncDiagnostics
    let accountSyncOutboxStore: SwiftDataAccountSyncOutboxStore
    let profileCloudSyncStore: ProfileCloudSyncStore
    let accountSyncCursorStore: AccountSyncCursorStore

    func snapshot() async -> SettingsPrivacyDataStatusSnapshot {
        let accountConnection: SettingsPrivacyDataStatusSnapshot.AccountConnection
        if case .signedIn(let uid) = authManager.authState {
            accountConnection = .signedIn(provider: authManager.accountSignInProvider)
            let pendingUploadCount = await pendingUploadCount(for: uid)
            return SettingsPrivacyDataStatusSnapshot(
                accountConnection: accountConnection,
                lastSuccessfulSyncAt: latestSyncDate(uid: uid),
                lastSuccessfulRestoreAt: latestRestoreDate(uid: uid),
                pendingUploadCount: pendingUploadCount,
                isBlockingRestoreActive: accountRestoreSessionState.isBlockingRestoreActive
            )
        }

        return SettingsPrivacyDataStatusSnapshot(
            accountConnection: .signedOut,
            lastSuccessfulSyncAt: nil,
            lastSuccessfulRestoreAt: nil,
            pendingUploadCount: 0,
            isBlockingRestoreActive: false
        )
    }

    private func pendingUploadCount(for uid: String) async -> Int {
        await accountSyncDiagnostics.pendingMutationCount(
            outbox: accountSyncOutboxStore,
            ownerUID: uid
        )
    }

    private func latestSyncDate(uid: String) -> Date? {
        var candidates: [Date] = []

        if let snapshot = accountSyncDiagnostics.lastSnapshot, !snapshot.didSkip {
            candidates.append(snapshot.endedAt)
        }

        if profileCloudSyncStore.isSyncedForUID(uid),
           let profileSyncedAt = profileCloudSyncStore.lastSyncedProfileUpdatedAt {
            candidates.append(profileSyncedAt)
        }

        let cursor = accountSyncCursorStore.loadCursor(uid: uid)
        candidates.append(contentsOf: [
            cursor.profileLastPulledAt,
            cursor.dailyLogsLastPulledAt,
            cursor.foodEntriesLastPulledAt,
            cursor.waterEntriesLastPulledAt,
            cursor.weightEntriesLastPulledAt,
            cursor.dailyReviewsLastPulledAt,
            cursor.lastForegroundRefreshAt,
            cursor.lastManualRefreshAt
        ].compactMap { $0 })

        return candidates.max()
    }

    private func latestRestoreDate(uid: String) -> Date? {
        var candidates: [Date] = []

        let stored = accountRestoreStateStore.loadState(uid: uid)
        candidates.append(contentsOf: [
            stored.lastSuccessfulBlockingRestoreAt,
            stored.lastSuccessfulBackgroundBackfillAt,
            stored.lastCompletedAt
        ].compactMap { $0 })

        if let summary = accountRestoreSessionState.lastCompletedSummary,
           summary.uid == uid,
           summary.status == .completed,
           let endedAt = summary.endedAt {
            candidates.append(endedAt)
        }

        return candidates.max()
    }
}
