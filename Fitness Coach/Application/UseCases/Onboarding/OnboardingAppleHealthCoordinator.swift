//
//  OnboardingAppleHealthCoordinator.swift
//  Fitness Coach
//
//  Apple Health permission flow during onboarding.
//

import Foundation

@MainActor
final class OnboardingAppleHealthCoordinator {

    private let healthTrainingIntegration: TrainingIntegrationProviding
    private let trainingInsightsStore: TrainingInsightsStore?

    init(
        healthTrainingIntegration: TrainingIntegrationProviding,
        trainingInsightsStore: TrainingInsightsStore?
    ) {
        self.healthTrainingIntegration = healthTrainingIntegration
        self.trainingInsightsStore = trainingInsightsStore
    }

    func refreshDeviceState() async -> TrainingIntegrationState {
        await healthTrainingIntegration.refreshState()
    }

    func requestPermission() async -> TrainingIntegrationState {
        if let trainingInsightsStore {
            return await OnboardingAppleHealthFlow.requestPermission(
                trainingInsightsStore: trainingInsightsStore
            )
        }
        return await OnboardingAppleHealthFlow.requestPermission(
            using: healthTrainingIntegration
        )
    }

    func mapPresentation(from deviceState: TrainingIntegrationState) -> OnboardingAppleHealthPresentationState {
        OnboardingAppleHealthPresentationBuilder.mapPermissionResult(deviceState)
    }

    func buildScreenState(
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState
    ) -> OnboardingAppleHealthScreenState {
        OnboardingAppleHealthPresentationBuilder.build(
            presentation: presentation,
            deviceState: deviceState
        )
    }

    func shouldAdvanceFromConnected(
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState
    ) -> Bool {
        presentation == .connected || deviceState == .connected
    }

    func logCTAState(
        action: String,
        presentation: OnboardingAppleHealthPresentationState,
        deviceState: TrainingIntegrationState,
        screenState: OnboardingAppleHealthScreenState,
        isConnecting: Bool
    ) {
        HealthTrainingDebugLogger.event(
            "Apple Health onboarding CTA",
            fields: [
                "action": action,
                "authorizationState": deviceState.debugLabel,
                "presentationState": String(describing: presentation),
                "localConnected": String(shouldAdvanceFromConnected(
                    presentation: presentation,
                    deviceState: deviceState
                )),
                "ctaTitle": screenState.primaryTitle,
                "ctaEnabled": String(screenState.isPrimaryEnabled),
                "ctaLoading": String(isConnecting)
            ]
        )
    }
}
