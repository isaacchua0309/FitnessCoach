//
//  AccountDeletionViewModel.swift
//  Fitness Coach
//
//  Forma — Drives account deletion confirmation, progress, and recovery UI.
//

import Foundation

@MainActor
final class AccountDeletionViewModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case confirming(scope: AccountDeletionScope)
        case performing(scope: AccountDeletionScope, status: AccountDeletionStatus)
        case finished(scope: AccountDeletionScope, summary: AccountDeletionSummary)
    }

    @Published private(set) var phase: Phase = .idle
    @Published var confirmationText = ""
    @Published private(set) var isPerformingDeletion = false

    private var coordinator: AccountDeletionCoordinator?
    private var deletionTask: Task<Void, Never>?

    func configure(coordinator: AccountDeletionCoordinator?) {
        self.coordinator = coordinator
    }

    var activeScope: AccountDeletionScope? {
        switch phase {
        case .idle:
            return nil
        case .confirming(let scope), .performing(let scope, _), .finished(let scope, _):
            return scope
        }
    }

    var canConfirmDeletion: Bool {
        guard case .confirming = phase else { return false }
        guard AccountDeletionPolicy.requiresTypedConfirmation else { return true }
        return confirmationText == AccountDeletionPolicy.confirmationPhrase
    }

    var showsProgress: Bool {
        if case .performing = phase { return true }
        if case .finished(_, let summary) = phase, summary.isSuccessful { return true }
        return false
    }

    var progressStatus: AccountDeletionStatus? {
        switch phase {
        case .performing(_, let status):
            return status
        case .finished(_, let summary) where summary.isSuccessful:
            return .completed
        default:
            return nil
        }
    }

    var terminalSummary: AccountDeletionSummary? {
        guard case .finished(_, let summary) = phase else { return nil }
        return summary
    }

    var safeErrorMessage: String? {
        guard let summary = terminalSummary, !summary.isSuccessful else { return nil }
        return AccountDeletionErrorFormatting.userFacingMessage(for: summary)
    }

    var allowsRetry: Bool {
        terminalSummary?.status.allowsRetry ?? false
    }

    var requiresReauthentication: Bool {
        terminalSummary?.status == .reauthenticationRequired
    }

    func beginConfirmation(scope: AccountDeletionScope) {
        deletionTask?.cancel()
        deletionTask = nil
        confirmationText = ""
        isPerformingDeletion = false
        phase = .confirming(scope: scope)
    }

    func cancelFlow() {
        if isPerformingDeletion {
            coordinator?.cancelDeletion()
            deletionTask?.cancel()
        }
        reset()
    }

    func reset() {
        deletionTask?.cancel()
        deletionTask = nil
        confirmationText = ""
        isPerformingDeletion = false
        phase = .idle
    }

    func confirmDeletion() {
        guard let scope = activeScope, canConfirmDeletion else { return }
        guard let coordinator else {
            phase = .finished(
                scope: scope,
                summary: unavailableSummary(scope: scope)
            )
            return
        }

        startDeletion(scope: scope, coordinator: coordinator, useReauthenticationRetry: false)
    }

    func retryDeletion() {
        guard let scope = activeScope, let coordinator else { return }
        guard let summary = terminalSummary, summary.status.allowsRetry else { return }
        startDeletion(
            scope: scope,
            coordinator: coordinator,
            useReauthenticationRetry: summary.status == .reauthenticationRequired
        )
    }

    private func startDeletion(
        scope: AccountDeletionScope,
        coordinator: AccountDeletionCoordinator,
        useReauthenticationRetry: Bool
    ) {
        isPerformingDeletion = true
        phase = .performing(scope: scope, status: .preparing)
        let confirmation = AccountDeletionPolicy.requiresTypedConfirmation
            ? confirmationText
            : AccountDeletionPolicy.confirmationPhrase

        deletionTask = Task { [weak self] in
            guard let self else { return }
            let summary: AccountDeletionSummary
            if useReauthenticationRetry {
                summary = await coordinator.retryAfterReauthentication(
                    confirmation: confirmation,
                    onProgress: { [weak self] status in
                        self?.updateProgress(scope: scope, status: status)
                    }
                )
            } else {
                summary = await self.runDeletion(
                    scope: scope,
                    confirmation: confirmation,
                    coordinator: coordinator
                )
            }
            guard !Task.isCancelled else { return }
            self.isPerformingDeletion = false
            self.phase = .finished(scope: scope, summary: summary)
        }
    }

    private func runDeletion(
        scope: AccountDeletionScope,
        confirmation: String,
        coordinator: AccountDeletionCoordinator
    ) async -> AccountDeletionSummary {
        switch scope {
        case .fullAccount:
            return await coordinator.deleteAccount(
                confirmation: confirmation,
                onProgress: { [weak self] status in
                    self?.updateProgress(scope: scope, status: status)
                }
            )
        case .localDeviceOnly:
            return await coordinator.deleteLocalDeviceDataOnly(
                confirmation: confirmation,
                onProgress: { [weak self] status in
                    self?.updateProgress(scope: scope, status: status)
                }
            )
        case .remoteAccountDataOnly:
            return unavailableSummary(scope: scope)
        }
    }

    private func updateProgress(scope: AccountDeletionScope, status: AccountDeletionStatus) {
        guard isPerformingDeletion else { return }
        phase = .performing(scope: scope, status: status)
    }

    private func unavailableSummary(scope: AccountDeletionScope) -> AccountDeletionSummary {
        AccountDeletionSummary(
            uid: "",
            scope: scope,
            status: .failed,
            startedAt: Date(),
            endedAt: Date(),
            remoteProfileDeleted: false,
            remoteDailyLogsDeleted: 0,
            remoteFoodEntriesDeleted: 0,
            remoteWaterEntriesDeleted: 0,
            remoteWeightEntriesDeleted: 0,
            remoteDailyReviewsDeleted: 0,
            remoteHealthSummariesDeleted: false,
            authAccountDeleted: false,
            localProfileDeleted: false,
            localDailyLogsDeleted: 0,
            localFoodEntriesDeleted: 0,
            localWaterEntriesDeleted: 0,
            localWeightEntriesDeleted: 0,
            localDailyReviewsDeleted: 0,
            localCoachMessagesDeleted: 0,
            localTimelineEventsDeleted: 0,
            localHealthCacheDeleted: false,
            localPreferencesDeleted: false,
            pendingMutationsDeleted: 0,
            failureCategory: .unknown,
            userFacingMessage: FormaProductCopy.Settings.PrivacyData.deletionFlowUnavailableMessage
        )
    }
}
