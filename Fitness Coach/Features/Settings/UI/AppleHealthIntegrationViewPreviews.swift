//
//  AppleHealthIntegrationViewPreviews.swift
//  Fitness Coach
//
//  Forma — Apple Health settings previews.
//

import SwiftUI

#if DEBUG
private struct AppleHealthIntegrationPreviewHost: View {
    let integrationState: TrainingIntegrationState
    let permissionAccess: HealthSignalAccess
    let localSyncDate: Date?
    let remoteSyncEnabled: Bool
    let consentDecision: HealthSummarySyncConsentDecision

    @StateObject private var store: TrainingInsightsStore
    @StateObject private var healthSyncStateStore: HealthSyncStateStore
    @StateObject private var consentStore: HealthSummarySyncConsentStore

    init(
        integrationState: TrainingIntegrationState,
        permissionAccess: HealthSignalAccess = .available,
        localSyncDate: Date? = nil,
        remoteSyncEnabled: Bool = false,
        consentDecision: HealthSummarySyncConsentDecision = .notDetermined
    ) {
        self.integrationState = integrationState
        self.permissionAccess = permissionAccess
        self.localSyncDate = localSyncDate
        self.remoteSyncEnabled = remoteSyncEnabled
        self.consentDecision = consentDecision

        let store = TrainingInsightsStore(
            integration: StubTrainingIntegrationProvider(refreshResult: integrationState)
        )
        store.configureLastSyncedAtForPreview(localSyncDate)
        _store = StateObject(wrappedValue: store)

        let syncService = HealthSyncService(
            repository: HealthDataRepository(
                healthKitManager: HealthKitManager(),
                cacheStore: LocalHealthCacheStore(userProvider: AuthUIDCache())
            ),
            cacheStore: LocalHealthCacheStore(userProvider: AuthUIDCache())
        )
        let syncStore = HealthSyncStateStore(syncService: syncService, syncEnabled: false)
        _healthSyncStateStore = StateObject(wrappedValue: syncStore)

        let consentStorage = LockedHealthSummarySyncConsentStore()
        consentStorage.save(
            HealthSummarySyncConsentState(decision: consentDecision, updatedAt: Date()),
            for: "preview-user"
        )
        _consentStore = StateObject(
            wrappedValue: HealthSummarySyncConsentStore(
                storage: consentStorage,
                userProvider: StaticHealthCacheUserProvider(userID: "preview-user")
            )
        )
    }

    var body: some View {
        NavigationStack {
            AppleHealthIntegrationView(insightsStore: store)
        }
        .environmentObject(healthSyncStateStore)
        .environmentObject(consentStore)
        .environment(
            \.appleHealthSettingsEnvironment,
            AppleHealthSettingsEnvironment(
                permissionService: PreviewHealthPermissionService(access: permissionAccess),
                remoteSyncService: remoteSyncEnabled ? PreviewHealthSummarySyncService() : nil,
                remoteSyncCapabilityEnabled: { remoteSyncEnabled }
            )
        )
        .formaThemePreview()
    }
}

@MainActor
private struct PreviewHealthPermissionService: HealthPermissionServing {
    let access: HealthSignalAccess

    var isHealthDataAvailable: Bool { true }

    func currentStatus(includingFutureTypes: Bool) async -> HealthPermissionStatus {
        .uniform(access, isHealthDataAvailable: true)
    }

    func requestPermissions(includingFutureTypes: Bool) async throws -> HealthPermissionStatus {
        await currentStatus(includingFutureTypes: includingFutureTypes)
    }
}

private actor PreviewHealthSummarySyncService: HealthSummarySyncServing {
    func syncRecentHealthSummaries(days: Int) async {}
    func syncTodayHealthSummary() async {}
    func syncWeeklyReviewIfAvailable() async {}
    func syncAfterLocalHealthRefresh(days: Int) async {}
    func syncOnAppForeground() async {}
    func getRemoteSyncState() async -> HealthSummaryRemoteSyncState { .idle }
    func deleteRemoteHealthSummaries() async throws {}
}

#Preview("Apple Health — Connected") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .connected,
        localSyncDate: Date()
    )
}

#Preview("Apple Health — Partial permissions") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .connected,
        permissionAccess: .denied
    )
}

#Preview("Apple Health — Disconnected") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .notConnected,
        permissionAccess: .notDetermined
    )
}

#Preview("Apple Health — Remote sync enabled") {
    AppleHealthIntegrationPreviewHost(
        integrationState: .connected,
        localSyncDate: Date(),
        remoteSyncEnabled: true,
        consentDecision: .optedIn
    )
}
#endif
