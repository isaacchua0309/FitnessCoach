//
//  OnboardingV4AppleHealthFlow.swift
//  Fitness Coach
//
//  Forma — V4 Apple Health permission attempt and analytics mapping.
//

import Foundation

enum OnboardingV4AppleHealthFlow {

    static func requestPermission(
        using integration: TrainingIntegrationProviding
    ) async -> TrainingIntegrationState {
        await integration.requestConnection()
    }

    @MainActor
    static func requestPermission(
        trainingInsightsStore: TrainingInsightsStore
    ) async -> TrainingIntegrationState {
        await trainingInsightsStore.connectAppleHealth()
        return trainingInsightsStore.integrationState
    }

    static func analyticsResult(for state: TrainingIntegrationState) -> String {
        switch state {
        case .connected:
            return "authorized"
        case .denied:
            return "denied"
        case .unavailable:
            return "unavailable"
        case .failed:
            return "failed"
        case .notConnected:
            return "not_connected"
        case .requestingPermission:
            return "requesting"
        }
    }
}
