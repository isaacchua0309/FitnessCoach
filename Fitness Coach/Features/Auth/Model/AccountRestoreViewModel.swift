//
//  AccountRestoreViewModel.swift
//  Fitness Coach
//
//  Forma — User-facing restore progress and terminal outcomes (Phase 4).
//

import Foundation

enum AccountRestoreUIPhase: Equatable {
    case checkingAccount
    case restoringProfile
    case restoringRecentLogs
    case restoringWeightHistory
    case preparingDashboard
    case completed
    case partialContinue
    case offlineContinue
    case failed

    var isBlockingProgress: Bool {
        switch self {
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard, .completed:
            return true
        case .partialContinue, .offlineContinue, .failed:
            return false
        }
    }

    var showsPrimaryAction: Bool {
        switch self {
        case .partialContinue, .offlineContinue, .failed:
            return true
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard, .completed:
            return false
        }
    }

    var showsSignOutAction: Bool {
        self == .failed
    }

    init?(restoreStatus: AccountRestoreStatus) {
        switch restoreStatus {
        case .notStarted, .checking:
            self = .checkingAccount
        case .restoringProfile:
            self = .restoringProfile
        case .restoringRecentData:
            self = .restoringRecentLogs
        case .restoringWeightHistory:
            self = .restoringWeightHistory
        case .rebuildingLocalViews:
            self = .preparingDashboard
        case .completed, .skipped:
            self = .completed
        case .partial:
            self = .partialContinue
        case .offline:
            self = .offlineContinue
        case .failed:
            self = .failed
        }
    }

    init(summary: AccountRestoreSummary) {
        switch summary.status {
        case .completed, .skipped:
            self = .completed
        case .partial:
            self = .partialContinue
        case .offline:
            self = .offlineContinue
        case .failed:
            self = .failed
        case .notStarted, .checking:
            self = .checkingAccount
        case .restoringProfile:
            self = .restoringProfile
        case .restoringRecentData:
            self = .restoringRecentLogs
        case .restoringWeightHistory:
            self = .restoringWeightHistory
        case .rebuildingLocalViews:
            self = .preparingDashboard
        }
    }
}

@MainActor
final class AccountRestoreViewModel: ObservableObject {

    @Published private(set) var phase: AccountRestoreUIPhase = .checkingAccount
    @Published private(set) var summary: AccountRestoreSummary?
    @Published private(set) var isRetrying = false

    var onContinueToMain: ((AccountRestoreSummary) -> Void)?
    var onSignOut: (() -> Void)?

    private let container: AppContainer
    private var activeUID: String?
    private var activeReason: AccountRestoreReason = .afterSignIn
    private var restoreTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?

    init(container: AppContainer) {
        self.container = container
    }

    deinit {
        restoreTask?.cancel()
        progressTask?.cancel()
    }

    func start(uid: String, reason: AccountRestoreReason) {
        activeUID = uid
        activeReason = reason
        isRetrying = false
        phase = .checkingAccount
        summary = nil

        restoreTask?.cancel()
        progressTask?.cancel()

        restoreTask = Task { [weak self] in
            await self?.runRestore(uid: uid, reason: reason, isRetry: false)
        }
    }

    func retry() {
        guard let uid = activeUID else { return }
        isRetrying = true
        phase = .checkingAccount
        summary = nil

        restoreTask?.cancel()
        progressTask?.cancel()

        restoreTask = Task { [weak self] in
            await self?.runRestore(uid: uid, reason: .manualRetry, isRetry: true)
        }
    }

    func continueToApp() {
        guard let summary else { return }
        onContinueToMain?(summary)
    }

    func signOut() {
        onSignOut?()
    }

    // MARK: - Copy

    var progressMessage: String {
        switch phase {
        case .checkingAccount:
            return FormaProductCopy.AccountRestore.Progress.checkingAccount
        case .restoringProfile:
            return FormaProductCopy.AccountRestore.Progress.restoringProfile
        case .restoringRecentLogs:
            return FormaProductCopy.AccountRestore.Progress.restoringRecentLogs
        case .restoringWeightHistory:
            return FormaProductCopy.AccountRestore.Progress.restoringWeightHistory
        case .preparingDashboard:
            return FormaProductCopy.AccountRestore.Progress.preparingDashboard
        case .completed:
            return FormaProductCopy.AccountRestore.Completed.message
        case .partialContinue:
            if summary?.userFacingMessage == FormaProductCopy.AccountRestore.TimedOut.body {
                return FormaProductCopy.AccountRestore.TimedOut.body
            }
            return summary?.userFacingMessage ?? FormaProductCopy.AccountRestore.Partial.body
        case .offlineContinue:
            return summary?.userFacingMessage ?? FormaProductCopy.AccountRestore.Offline.body
        case .failed:
            return summary?.userFacingMessage ?? FormaProductCopy.AccountRestore.Failed.body
        }
    }

    var title: String? {
        switch phase {
        case .partialContinue:
            return FormaProductCopy.AccountRestore.Partial.title
        case .offlineContinue:
            return FormaProductCopy.AccountRestore.Offline.title
        case .failed:
            return FormaProductCopy.AccountRestore.Failed.title
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard, .completed:
            return nil
        }
    }

    var primaryActionTitle: String {
        switch phase {
        case .partialContinue:
            return FormaProductCopy.AccountRestore.Partial.continueCTA
        case .offlineContinue:
            return FormaProductCopy.AccountRestore.Offline.continueCTA
        case .failed:
            return failedAllowsContinue
                ? FormaProductCopy.AccountRestore.Offline.continueCTA
                : FormaProductCopy.AccountRestore.Failed.retryCTA
        case .checkingAccount, .restoringProfile, .restoringRecentLogs,
             .restoringWeightHistory, .preparingDashboard, .completed:
            return FormaProductCopy.Common.continueAction
        }
    }

    var failedAllowsContinue: Bool {
        guard phase == .failed, let summary else { return false }
        return summary.allowsContinuedEntry
    }

    var showsPrimaryAction: Bool {
        phase.showsPrimaryAction
    }

    var showsSecondaryRetryAction: Bool {
        switch phase {
        case .failed:
            return failedAllowsContinue
        case .offlineContinue:
            return true
        default:
            return false
        }
    }

    #if DEBUG
    var debugDetail: String? {
        guard let summary else { return nil }
        return [
            "logs: \(summary.dailyLogsRestored)",
            "food: \(summary.foodEntriesRestored)",
            "water: \(summary.waterEntriesRestored)",
            "weight: \(summary.weightEntriesRestored)",
            "reviews: \(summary.dailyReviewsRestored)"
        ].joined(separator: " · ")
    }
    #endif

    // MARK: - Restore execution

    private func runRestore(uid: String, reason: AccountRestoreReason, isRetry: Bool) async {
        startProgressPolling(uid: uid)

        let result: AccountRestoreSummary
        #if DEBUG
        if isRetry, let testingRetryHandler {
            result = await testingRetryHandler(uid)
        } else if isRetry {
            result = await container.accountRestoreCoordinator.retryRestore(uid: uid)
        } else {
            result = await container.runAccountRestoreAfterSignIn(uid: uid, reason: reason)
        }
        #else
        if isRetry {
            result = await container.accountRestoreCoordinator.retryRestore(uid: uid)
        } else {
            result = await container.runAccountRestoreAfterSignIn(uid: uid, reason: reason)
        }
        #endif

        progressTask?.cancel()
        progressTask = nil
        isRetrying = false

        guard !Task.isCancelled else { return }
        summary = result
        await applyTerminalOutcome(result)
    }

    private func startProgressPolling(uid: String) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                let status = container.accountRestoreStateStore.loadState(uid: uid).status
                if let mapped = AccountRestoreUIPhase(restoreStatus: status),
                   mapped.isBlockingProgress {
                    phase = mapped
                }
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    private func applyTerminalOutcome(_ result: AccountRestoreSummary) async {
        phase = AccountRestoreUIPhase(summary: result)

        switch result.status {
        case .completed, .skipped:
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            onContinueToMain?(result)
        case .partial, .offline, .failed:
            break
        case .notStarted, .checking, .restoringProfile, .restoringRecentData,
             .restoringWeightHistory, .rebuildingLocalViews:
            onContinueToMain?(result)
        }
    }
}

#if DEBUG
extension AccountRestoreViewModel {

    func applyTestingState(
        phase: AccountRestoreUIPhase,
        summary: AccountRestoreSummary? = nil
    ) {
        self.phase = phase
        self.summary = summary
        activeUID = summary?.uid ?? activeUID ?? "test-user"
    }

    var testingRetryHandler: ((String) async -> AccountRestoreSummary)? {
        get { AccountRestoreViewModelTestSupport.retryHandler(for: self) }
        set { AccountRestoreViewModelTestSupport.setRetryHandler(newValue, for: self) }
    }
}

private enum AccountRestoreViewModelTestSupport {
    private static var retryHandlers: [ObjectIdentifier: (String) async -> AccountRestoreSummary] = [:]

    static func retryHandler(for viewModel: AccountRestoreViewModel) -> ((String) async -> AccountRestoreSummary)? {
        retryHandlers[ObjectIdentifier(viewModel)]
    }

    static func setRetryHandler(
        _ handler: ((String) async -> AccountRestoreSummary)?,
        for viewModel: AccountRestoreViewModel
    ) {
        let key = ObjectIdentifier(viewModel)
        if let handler {
            retryHandlers[key] = handler
        } else {
            retryHandlers.removeValue(forKey: key)
        }
    }
}
#endif
