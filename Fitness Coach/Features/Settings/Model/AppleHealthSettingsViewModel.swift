//
//  AppleHealthSettingsViewModel.swift
//  Fitness Coach
//
//  Forma — Loads Apple Health settings state without auto-requesting permissions.
//

import Combine
import Foundation

@MainActor
final class AppleHealthSettingsViewModel: ObservableObject {

    @Published private(set) var loadPhase: AppleHealthSettingsLoadPhase = .idle
    @Published private(set) var permissionStatus: HealthPermissionStatus?
    @Published private(set) var remoteSyncState: HealthSummaryRemoteSyncState = .disabled
    @Published private(set) var isRefreshingHealthData = false
    @Published private(set) var isDeletingRemoteSummaries = false
    @Published var showsDeleteRemoteConfirmation = false
    @Published var showsRemoteSyncSettings = false

    private let insightsStore: TrainingInsightsStore

    init(insightsStore: TrainingInsightsStore) {
        self.insightsStore = insightsStore
    }

    func presentation(
        healthSyncStateStore: HealthSyncStateStore,
        consentStore: HealthSummarySyncConsentStore,
        isHealthDataAvailable: Bool,
        isRemoteSyncCapabilityEnabled: Bool
    ) -> AppleHealthSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.build(
            input: presentationInput(
                localSyncState: healthSyncStateStore.state,
                consentStore: consentStore,
                isHealthDataAvailable: isHealthDataAvailable,
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled
            )
        )
    }

    func remoteSyncPresentation(
        healthSyncStateStore: HealthSyncStateStore,
        consentStore: HealthSummarySyncConsentStore,
        isHealthDataAvailable: Bool,
        isRemoteSyncCapabilityEnabled: Bool
    ) -> AppleHealthRemoteSyncSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.buildRemoteSyncSettings(
            input: presentationInput(
                localSyncState: healthSyncStateStore.state,
                consentStore: consentStore,
                isHealthDataAvailable: isHealthDataAvailable,
                isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled
            )
        )
    }

    func loadSnapshot(
        healthSyncStateStore: HealthSyncStateStore,
        consentStore: HealthSummarySyncConsentStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        guard loadPhase != .loading else { return }

        loadPhase = .loading
        consentStore.refresh()

        guard environment.permissionService.isHealthDataAvailable else {
            permissionStatus = .unavailable()
            remoteSyncState = .disabled
            loadPhase = .healthKitUnavailable
            return
        }

        async let integrationRefresh: Void = { await insightsStore.refresh() }()
        async let permissionSnapshot = environment.permissionService.currentStatus()
        async let localSyncRefresh: Void = {
            if HealthIntelligenceFeatureFlags.isSyncEnabled {
                await healthSyncStateStore.refreshState()
            }
        }()
        async let remoteState = loadRemoteSyncState(
            environment: environment,
            consentStore: consentStore
        )

        _ = await integrationRefresh
        _ = await localSyncRefresh
        permissionStatus = await permissionSnapshot
        remoteSyncState = await remoteState
        loadPhase = .loaded
    }

    func connectAppleHealth(
        healthSyncStateStore: HealthSyncStateStore,
        consentStore: HealthSummarySyncConsentStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        await insightsStore.connectAppleHealth()
        permissionStatus = await environment.permissionService.currentStatus()
        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            await healthSyncStateStore.refreshState()
        }
        remoteSyncState = await loadRemoteSyncState(
            environment: environment,
            consentStore: consentStore
        )
        loadPhase = .loaded
    }

    func refreshHealthData(
        healthSyncStateStore: HealthSyncStateStore,
        consentStore: HealthSummarySyncConsentStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        guard !isRefreshingHealthData else { return }
        isRefreshingHealthData = true
        defer { isRefreshingHealthData = false }

        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            healthSyncStateStore.syncLastNDays(HealthSummarySyncPolicy.defaultSyncWindowDays)
            await waitForLocalSyncToSettle(healthSyncStateStore: healthSyncStateStore)
            await healthSyncStateStore.refreshState()
        }

        permissionStatus = await environment.permissionService.currentStatus()
        remoteSyncState = await loadRemoteSyncState(
            environment: environment,
            consentStore: consentStore
        )
        loadPhase = .loaded
    }

    func optInToRemoteSync(
        consentStore: HealthSummarySyncConsentStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        consentStore.optIn()
        await syncRemoteSummariesNow(environment: environment, consentStore: consentStore)
    }

    func optOutOfRemoteSync(
        deleteRemoteSummaries: Bool,
        consentStore: HealthSummarySyncConsentStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        await environment.remoteSyncService?.cancelActiveSync()
        consentStore.optOut()
        if deleteRemoteSummaries {
            await self.deleteRemoteSummaries(environment: environment, consentStore: consentStore)
        } else {
            remoteSyncState = await loadRemoteSyncState(
                environment: environment,
                consentStore: consentStore
            )
        }
    }

    func syncRemoteSummariesNow(
        environment: AppleHealthSettingsEnvironment,
        consentStore: HealthSummarySyncConsentStore
    ) async {
        guard environment.isRemoteSyncActive(consentStore: consentStore),
              let remoteSyncService = environment.remoteSyncService else {
            return
        }
        await remoteSyncService.syncRecentHealthSummaries()
        remoteSyncState = await loadRemoteSyncState(
            environment: environment,
            consentStore: consentStore
        )
    }

    func deleteRemoteSummaries(
        environment: AppleHealthSettingsEnvironment,
        consentStore: HealthSummarySyncConsentStore
    ) async {
        guard environment.isRemoteSyncCapabilityEnabled,
              let remoteSyncService = environment.remoteSyncService else {
            return
        }
        guard !isDeletingRemoteSummaries else { return }

        isDeletingRemoteSummaries = true
        defer { isDeletingRemoteSummaries = false }

        do {
            try await remoteSyncService.deleteRemoteHealthSummaries()
            remoteSyncState = await loadRemoteSyncState(
                environment: environment,
                consentStore: consentStore
            )
        } catch {
            loadPhase = .error(FormaProductCopy.Settings.AppleHealth.deleteRemoteSummariesFailedMessage)
        }
    }

    // MARK: - Private

    private func presentationInput(
        localSyncState: HealthSyncState,
        consentStore: HealthSummarySyncConsentStore,
        isHealthDataAvailable: Bool,
        isRemoteSyncCapabilityEnabled: Bool
    ) -> AppleHealthSettingsPresentationInput {
        AppleHealthSettingsPresentationInput(
            integrationState: insightsStore.integrationState,
            permissionStatus: permissionStatus,
            localSyncState: localSyncState,
            remoteSyncState: remoteSyncState,
            isRemoteSyncCapabilityEnabled: isRemoteSyncCapabilityEnabled,
            remoteSyncConsent: consentStore.state,
            isHealthDataAvailable: isHealthDataAvailable,
            loadPhase: loadPhase,
            isRefreshingHealthData: isRefreshingHealthData,
            isDeletingRemoteSummaries: isDeletingRemoteSummaries
        )
    }

    private func loadRemoteSyncState(
        environment: AppleHealthSettingsEnvironment,
        consentStore: HealthSummarySyncConsentStore
    ) async -> HealthSummaryRemoteSyncState {
        guard environment.isRemoteSyncActive(consentStore: consentStore),
              let remoteSyncService = environment.remoteSyncService else {
            return .disabled
        }
        return await remoteSyncService.getRemoteSyncState()
    }

    private func waitForLocalSyncToSettle(healthSyncStateStore: HealthSyncStateStore) async {
        let timeout = Date().addingTimeInterval(30)
        while healthSyncStateStore.state.isSyncing, Date() < timeout {
            try? await Task.sleep(nanoseconds: 250_000_000)
            await healthSyncStateStore.refreshState()
        }
    }
}
