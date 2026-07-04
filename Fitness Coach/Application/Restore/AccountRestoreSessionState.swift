//
//  AccountRestoreSessionState.swift
//  Fitness Coach
//
//  Forma — Published restore session state for main-shell tabs (Phase 4).
//

import Combine
import Foundation

extension Notification.Name {
    static let accountRestoreDidComplete = Notification.Name("forma.accountRestore.didComplete")
}

@MainActor
final class AccountRestoreSessionState: ObservableObject {

    @Published private(set) var isBlockingRestoreActive = false
    @Published private(set) var lastCompletedSummary: AccountRestoreSummary?
    @Published private(set) var completionToken: Int = 0

    func beginBlockingRestore() {
        isBlockingRestoreActive = true
    }

    func recordRestoreCompletion(_ summary: AccountRestoreSummary) {
        isBlockingRestoreActive = false
        lastCompletedSummary = summary
        completionToken += 1
        NotificationCenter.default.post(name: .accountRestoreDidComplete, object: nil)
    }

    func clearForSignOut() {
        isBlockingRestoreActive = false
        lastCompletedSummary = nil
    }

    func shouldShowPendingRestoreUI(localDataEffectivelyEmpty: Bool) -> Bool {
        guard localDataEffectivelyEmpty else { return false }
        guard let summary = lastCompletedSummary else { return false }
        switch summary.status {
        case .partial, .offline:
            return true
        case .completed, .skipped, .failed, .notStarted, .checking,
             .restoringProfile, .restoringRecentData, .restoringWeightHistory, .rebuildingLocalViews:
            return false
        }
    }

    func shouldShowPendingRestoreUI(
        ownerUID: String?,
        localDataInspector: (any AccountLocalDataInspecting)?
    ) async -> Bool {
        guard let ownerUID, let localDataInspector else { return false }
        do {
            let status = try await localDataInspector.inspectLocalData(for: ownerUID)
            return shouldShowPendingRestoreUI(localDataEffectivelyEmpty: status.isEffectivelyEmpty)
        } catch {
            return false
        }
    }

    var pendingRestoreMessage: String {
        guard let summary = lastCompletedSummary else {
            return FormaProductCopy.AccountRestore.Pending.defaultBody
        }
        switch summary.status {
        case .offline:
            return FormaProductCopy.AccountRestore.Pending.offlineBody
        case .partial:
            return FormaProductCopy.AccountRestore.Pending.partialBody
        default:
            return FormaProductCopy.AccountRestore.Pending.defaultBody
        }
    }
}
