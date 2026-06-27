//
//  TrainingIntegrationPreviewData.swift
//  Fitness Coach
//
//  Forma — Fixed integration states for previews and tests.
//

import Foundation

enum TrainingIntegrationPreviewData {

    static let notConnected = TrainingIntegrationState.notConnected
    static let connected = TrainingIntegrationState.connected
    static let denied = TrainingIntegrationState.denied
    static let requesting = TrainingIntegrationState.requestingPermission
    static let unavailable = TrainingIntegrationState.unavailable
    static let failed = TrainingIntegrationState.failed(message: "Could not reach Apple Health.")

    static let appleHealthSource = TrainingDataSource.appleHealth
    static let unavailableSource = TrainingDataSource.unavailable
}

/// In-memory integration provider for SwiftUI previews and unit tests.
final class StubTrainingIntegrationProvider: TrainingIntegrationProviding, @unchecked Sendable {

    var dataSource: TrainingDataSource
    var refreshResult: TrainingIntegrationState
    var requestConnectionResult: TrainingIntegrationState?

    private(set) var refreshCallCount = 0
    private(set) var requestConnectionCallCount = 0

    init(
        dataSource: TrainingDataSource = .appleHealth,
        refreshResult: TrainingIntegrationState = .notConnected,
        requestConnectionResult: TrainingIntegrationState? = nil
    ) {
        self.dataSource = dataSource
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
