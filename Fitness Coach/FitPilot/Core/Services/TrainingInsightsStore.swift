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
        let state = await integration.refreshState()
        integrationState = state
        dataSource = integration.dataSource
    }

    func connectAppleHealth() async {
        guard !integrationState.isRequestingPermission else { return }

        integrationState = .requestingPermission
        dataSource = integration.dataSource

        let result = await integration.requestConnection()
        integrationState = result
        dataSource = integration.dataSource
    }
}
