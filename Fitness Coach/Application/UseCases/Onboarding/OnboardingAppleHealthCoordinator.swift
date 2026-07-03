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
    private var isPermissionRequestInFlight = false

    init(
        healthTrainingIntegration: TrainingIntegrationProviding,
        trainingInsightsStore: TrainingInsightsStore?
    ) {
        self.healthTrainingIntegration = healthTrainingIntegration
        self.trainingInsightsStore = trainingInsightsStore
    }

    var isHealthDataAvailable: Bool {
        healthTrainingIntegration.isHealthDataAvailable
    }

    func refreshDeviceState() async -> TrainingIntegrationState {
        logAuthorizationStatusRefreshed(phase: "started")
        let state = await healthTrainingIntegration.refreshState()
        logAuthorizationStatusRefreshed(phase: "finished", deviceState: state)
        return state
    }

    func requestPermission() async -> TrainingIntegrationState {
        guard healthTrainingIntegration.isHealthDataAvailable else {
            logHealthKitUnavailable(context: "requestPermission")
            return .unavailable
        }

        guard !isPermissionRequestInFlight else {
            HealthTrainingDebugLogger.warn(
                "Onboarding Apple Health authorization request ignored (already in flight)"
            )
            return await refreshDeviceState()
        }

        isPermissionRequestInFlight = true
        defer { isPermissionRequestInFlight = false }

        logAuthorizationRequested()

        let state: TrainingIntegrationState
        if let trainingInsightsStore {
            state = await OnboardingAppleHealthFlow.requestPermission(
                trainingInsightsStore: trainingInsightsStore
            )
        } else {
            state = await OnboardingAppleHealthFlow.requestPermission(
                using: healthTrainingIntegration
            )
        }

        switch state {
        case .connected:
            logAuthorizationSuccess()
        case .denied:
            logAuthorizationDenied()
        case .unavailable:
            logHealthKitUnavailable(context: "requestPermission.result")
        default:
            break
        }

        return state
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
                "primaryAction": String(describing: screenState.primaryAction),
                "showsSkip": String(screenState.showsSkipButton),
                "ctaTitle": screenState.primaryTitle,
                "ctaEnabled": String(screenState.isPrimaryEnabled),
                "ctaLoading": String(isConnecting)
            ]
        )
    }

    // MARK: - Debug logging

    private func logHealthKitUnavailable(context: String) {
        HealthTrainingDebugLogger.warn(
            "HealthKit unavailable",
            fields: ["context": context]
        )
    }

    private func logAuthorizationRequested() {
        HealthTrainingDebugLogger.event("Authorization requested", fields: ["surface": "onboarding"])
    }

    private func logAuthorizationSuccess() {
        HealthTrainingDebugLogger.event("Authorization success", fields: ["surface": "onboarding"])
    }

    private func logAuthorizationDenied() {
        HealthTrainingDebugLogger.warn("Authorization denied", fields: ["surface": "onboarding"])
    }

    private func logAuthorizationStatusRefreshed(
        phase: String,
        deviceState: TrainingIntegrationState? = nil
    ) {
        var fields: [String: String] = [
            "phase": phase,
            "surface": "onboarding"
        ]
        if let deviceState {
            fields["authorizationState"] = deviceState.debugLabel
        }
        HealthTrainingDebugLogger.event("Authorization status refreshed", fields: fields)
    }
}
