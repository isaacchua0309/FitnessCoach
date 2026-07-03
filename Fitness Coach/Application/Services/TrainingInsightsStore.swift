//
//  TrainingInsightsStore.swift
//  Fitness Coach
//
//  Forma — Published training integration state for Training Insights (Stage 2).
//

import Combine
import Foundation

@MainActor
final class TrainingInsightsStore: ObservableObject {

    @Published private(set) var integrationState: TrainingIntegrationState = .notConnected
    @Published private(set) var dataSource: TrainingDataSource = .unavailable
    @Published private(set) var lastSyncedAt: Date?

    private let integration: TrainingIntegrationProviding
    private let healthSyncStateStore: HealthSyncStateStore?

    init(
        integration: TrainingIntegrationProviding,
        healthSyncStateStore: HealthSyncStateStore? = nil
    ) {
        self.integration = integration
        self.healthSyncStateStore = healthSyncStateStore
        self.dataSource = integration.dataSource
    }

    func refresh() async {
        let previous = integrationState
        let state = await integration.refreshState()
        integrationState = state
        dataSource = integration.dataSource
        if state.isConnected {
            lastSyncedAt = Date()
        }
        HealthTrainingDebugLogger.logIntegrationTransition(
            from: previous,
            to: state,
            action: "TrainingInsightsStore.refresh",
            fields: ["dataSource": dataSource.rawValue]
        )
    }

    func connectAppleHealth() async {
        guard !integrationState.isRequestingPermission else {
            HealthTrainingDebugLogger.warn(
                "connectAppleHealth ignored: already requesting permission",
                fields: ["integrationState": integrationState.debugLabel]
            )
            return
        }

        let previous = integrationState
        HealthTrainingDebugLogger.event(
            "connectAppleHealth started",
            fields: ["previousState": previous.debugLabel]
        )

        integrationState = .requestingPermission
        dataSource = integration.dataSource

        let result = await integration.requestConnection()
        integrationState = result
        dataSource = integration.dataSource
        if result.isConnected {
            lastSyncedAt = Date()
            healthSyncStateStore?.syncInitialHealthData()
        }

        HealthTrainingDebugLogger.logIntegrationTransition(
            from: previous,
            to: result,
            action: "TrainingInsightsStore.connectAppleHealth",
            fields: ["dataSource": dataSource.rawValue]
        )
    }

    #if DEBUG
    func configureLastSyncedAtForPreview(_ date: Date?) {
        lastSyncedAt = date
    }
    #endif
}
