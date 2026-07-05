//
//  TodayHealthIntegrationNextStepResolver.swift
//  Fitness Coach
//
//  Forma — Today Suggested Next Step policy separating connection state from data gaps.
//

import Foundation

enum TodayHealthIntegrationNextStepResolver {

    private static let sectionTitle = FormaProductCopy.Today.HealthIntelligence.NextAction.sectionTitle

    static func resolve(
        integrationStatus: HealthIntegrationStatus,
        signalAvailability: HealthSignalAvailability,
        behavioralAction: NextBestAction,
        hasPriorConnectionEvidence: Bool
    ) -> TodayHealthNextBestActionState {
        if let prioritized = prioritizedBehavioralAction(behavioralAction) {
            return prioritized
        }

        if integrationStatus.requiresInitialConnection(
            hasPriorConnectionEvidence: hasPriorConnectionEvidence
        ) {
            return connectAppleHealthAction(for: integrationStatus)
        }

        if integrationStatus == .connectedNoData {
            return connectedNoDataAction()
        }

        if integrationStatus == .connectedPartial {
            return connectedPartialAction(integrationStatus: integrationStatus)
        }

        if let fallback = deprioritizedBehavioralAction(behavioralAction) {
            return fallback
        }

        return .hidden
    }

    // MARK: - Behavioral priority

    private static func prioritizedBehavioralAction(
        _ action: NextBestAction
    ) -> TodayHealthNextBestActionState? {
        guard HealthIntelligencePresentationCore.isVisibleHealthAction(action) else { return nil }

        switch action.reason {
        case .noMealLogged, .hydration, .postWorkoutRecovery, .lowRecovery, .missingWeight:
            return mapBehavioralAction(action)
        case .stepEncouragement:
            return mapBehavioralAction(action)
        case .stayOnPlan, .connectHealth, .waitingForData, .healthDataLimited:
            return nil
        }
    }

    private static func deprioritizedBehavioralAction(
        _ action: NextBestAction
    ) -> TodayHealthNextBestActionState? {
        guard HealthIntelligencePresentationCore.isVisibleHealthAction(action) else { return nil }
        guard action.reason == .stayOnPlan || action.reason == .waitingForData else { return nil }
        return nil
    }

    // MARK: - Integration actions

    private static func connectAppleHealthAction(
        for status: HealthIntegrationStatus
    ) -> TodayHealthNextBestActionState {
        let copy = FormaProductCopy.HealthIntelligence.Integration.connectAction(for: status)
        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: sectionTitle,
            title: copy.title,
            message: copy.message,
            ctaTitle: copy.ctaTitle,
            destination: status == .permissionDenied ? .connectHealth : .connectHealth,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: sectionTitle,
                title: copy.title,
                message: copy.message,
                ctaTitle: copy.ctaTitle
            )
        )
    }

    private static func connectedNoDataAction() -> TodayHealthNextBestActionState {
        let copy = FormaProductCopy.HealthIntelligence.Integration.connectedNoData
        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: sectionTitle,
            title: copy.title,
            message: copy.message,
            ctaTitle: copy.ctaTitle,
            destination: .refreshHealthData,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: sectionTitle,
                title: copy.title,
                message: copy.message,
                ctaTitle: copy.ctaTitle
            )
        )
    }

    private static func connectedPartialAction(
        integrationStatus: HealthIntegrationStatus
    ) -> TodayHealthNextBestActionState {
        let copy = FormaProductCopy.HealthIntelligence.Integration.connectedPartial
        let ctaTitle = integrationStatus.canReviewPermissions ? copy.ctaTitle : nil
        let destination: TodayHealthNextBestActionDestination = integrationStatus.canReviewPermissions
            ? .manageHealthPermissions
            : .none

        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: sectionTitle,
            title: copy.title,
            message: copy.message,
            ctaTitle: ctaTitle,
            destination: destination,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: sectionTitle,
                title: copy.title,
                message: copy.message,
                ctaTitle: ctaTitle
            )
        )
    }

    private static func mapBehavioralAction(_ action: NextBestAction) -> TodayHealthNextBestActionState {
        let fields = HealthIntelligencePresentationCore.normalizedActionFields(from: action)
        let destination = mapDestination(action.destination, reason: action.reason)

        return TodayHealthNextBestActionState(
            isVisible: true,
            sectionTitle: sectionTitle,
            title: fields.title,
            message: fields.message,
            ctaTitle: fields.ctaTitle?.isEmpty == false ? fields.ctaTitle : nil,
            destination: destination,
            accessibilityLabel: HealthIntelligencePresentationCore.nextBestActionAccessibilityLabel(
                sectionTitle: sectionTitle,
                title: fields.title,
                message: fields.message,
                ctaTitle: fields.ctaTitle
            )
        )
    }

    private static func mapDestination(
        _ destination: NextBestActionDestination,
        reason: HealthNextBestActionReason
    ) -> TodayHealthNextBestActionDestination {
        switch destination {
        case .logMeal: return .logMeal
        case .addWater: return .addWater
        case .askCoach: return .askCoach
        case .viewRecovery: return .viewRecovery
        case .logWeight: return .logWeight
        case .none:
            if reason == .lowRecovery {
                return .viewRecovery
            }
            return .none
        }
    }
}
