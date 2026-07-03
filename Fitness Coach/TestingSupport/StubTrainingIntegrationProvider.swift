//
//  StubTrainingIntegrationProvider.swift
//  Fitness Coach
//
//  Forma — In-memory integration provider for SwiftUI previews and unit tests.
//

import Foundation

final class StubTrainingIntegrationProvider: TrainingIntegrationProviding, @unchecked Sendable {

    var dataSource: TrainingDataSource
    var isHealthDataAvailable: Bool
    var refreshResult: TrainingIntegrationState
    var requestConnectionResult: TrainingIntegrationState?

    private(set) var refreshCallCount = 0
    private(set) var requestConnectionCallCount = 0

    init(
        dataSource: TrainingDataSource = .appleHealth,
        isHealthDataAvailable: Bool? = nil,
        refreshResult: TrainingIntegrationState = .notConnected,
        requestConnectionResult: TrainingIntegrationState? = nil
    ) {
        self.dataSource = dataSource
        self.isHealthDataAvailable = isHealthDataAvailable ?? (dataSource != .unavailable)
        self.refreshResult = refreshResult
        self.requestConnectionResult = requestConnectionResult
    }

    func refreshState() async -> TrainingIntegrationState {
        refreshCallCount += 1
        return refreshResult
    }

    func requestConnection() async -> TrainingIntegrationState {
        requestConnectionCallCount += 1
        return requestConnectionResult ?? refreshResult
    }
}
