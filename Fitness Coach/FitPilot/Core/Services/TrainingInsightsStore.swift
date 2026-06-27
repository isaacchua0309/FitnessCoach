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

    private let integration: TrainingIntegrationProviding

    init(integration: TrainingIntegrationProviding) {
        self.integration = integration
        self.dataSource = integration.dataSource
    }

    func refresh() async {
        let previous = integrationState
        let state = await integration.refreshState()
        integrationState = state
        dataSource = integration.dataSource
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

        HealthTrainingDebugLogger.logIntegrationTransition(
            from: previous,
            to: result,
            action: "TrainingInsightsStore.connectAppleHealth",
            fields: ["dataSource": dataSource.rawValue]
        )
    }
}
