//
//  AppleHealthSettingsViewModel.swift
//  Fitness Coach
//
//  Forma — Loads Apple Health settings state without auto-requesting permissions.
//

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
        isHealthDataAvailable: Bool,
        isRemoteSyncEnabled: Bool
    ) -> AppleHealthSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.build(
            input: presentationInput(
                localSyncState: healthSyncStateStore.state,
                isHealthDataAvailable: isHealthDataAvailable,
                isRemoteSyncEnabled: isRemoteSyncEnabled
            )
        )
    }

    func remoteSyncPresentation(
        healthSyncStateStore: HealthSyncStateStore,
        isHealthDataAvailable: Bool,
        isRemoteSyncEnabled: Bool
    ) -> AppleHealthRemoteSyncSettingsPresentation {
        AppleHealthSettingsPresentationBuilder.buildRemoteSyncSettings(
            input: presentationInput(
                localSyncState: healthSyncStateStore.state,
                isHealthDataAvailable: isHealthDataAvailable,
                isRemoteSyncEnabled: isRemoteSyncEnabled
            )
        )
    }

    func loadSnapshot(
        healthSyncStateStore: HealthSyncStateStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        guard loadPhase != .loading else { return }

        loadPhase = .loading

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
        async let remoteState = loadRemoteSyncState(environment: environment)

        _ = await integrationRefresh
        _ = await localSyncRefresh
        permissionStatus = await permissionSnapshot
        remoteSyncState = await remoteState
        loadPhase = .loaded
    }

    func connectAppleHealth(
        healthSyncStateStore: HealthSyncStateStore,
        environment: AppleHealthSettingsEnvironment
    ) async {
        await insightsStore.connectAppleHealth()
        permissionStatus = await environment.permissionService.currentStatus()
        if HealthIntelligenceFeatureFlags.isSyncEnabled {
            await healthSyncStateStore.refreshState()
        }
        remoteSyncState = await loadRemoteSyncState(environment: environment)
        loadPhase = .loaded
    }

    func refreshHealthData(
        healthSyncStateStore: HealthSyncStateStore,
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
        remoteSyncState = await loadRemoteSyncState(environment: environment)
        loadPhase = .loaded
    }

    func syncRemoteSummariesNow(environment: AppleHealthSettingsEnvironment) async {
        guard environment.remoteSyncEnabled(), let remoteSyncService = environment.remoteSyncService else {
            return
        }
        await remoteSyncService.syncRecentHealthSummaries()
        remoteSyncState = await loadRemoteSyncState(environment: environment)
    }

    func deleteRemoteSummaries(environment: AppleHealthSettingsEnvironment) async {
        guard environment.remoteSyncEnabled(),
              let remoteSyncService = environment.remoteSyncService else {
            return
        }
        guard !isDeletingRemoteSummaries else { return }

        isDeletingRemoteSummaries = true
        defer { isDeletingRemoteSummaries = false }

        do {
            try await remoteSyncService.deleteRemoteHealthSummaries()
            remoteSyncState = await loadRemoteSyncState(environment: environment)
        } catch {
            loadPhase = .error(FormaProductCopy.Settings.AppleHealth.deleteRemoteSummariesFailedMessage)
        }
    }

    // MARK: - Private

    private func presentationInput(
        localSyncState: HealthSyncState,
        isHealthDataAvailable: Bool,
        isRemoteSyncEnabled: Bool
    ) -> AppleHealthSettingsPresentationInput {
        AppleHealthSettingsPresentationInput(
            integrationState: insightsStore.integrationState,
            permissionStatus: permissionStatus,
            localSyncState: localSyncState,
            remoteSyncState: remoteSyncState,
            isRemoteSyncEnabled: isRemoteSyncEnabled,
            isHealthDataAvailable: isHealthDataAvailable,
            loadPhase: loadPhase,
            isRefreshingHealthData: isRefreshingHealthData,
            isDeletingRemoteSummaries: isDeletingRemoteSummaries
        )
    }

    private func loadRemoteSyncState(
        environment: AppleHealthSettingsEnvironment
    ) async -> HealthSummaryRemoteSyncState {
        guard environment.remoteSyncEnabled(), let remoteSyncService = environment.remoteSyncService else {
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
