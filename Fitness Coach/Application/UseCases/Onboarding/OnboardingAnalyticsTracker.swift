//
//  OnboardingAnalyticsTracker.swift
//  Fitness Coach
//
//  Onboarding funnel analytics session tracking.
//

import Foundation

@MainActor
final class OnboardingAnalyticsTracker {

    private let analyticsLogger: any OnboardingAnalyticsLogging
    private let analyticsEntry: OnboardingAnalyticsEntry
    private var stepEnteredAt = Date()

    init(
        analyticsLogger: any OnboardingAnalyticsLogging,
        analyticsEntry: OnboardingAnalyticsEntry
    ) {
        self.analyticsLogger = analyticsLogger
        self.analyticsEntry = analyticsEntry
    }

    func bootstrap(restoredFromDraft: Bool, currentStep: OnboardingStep) {
        if restoredFromDraft {
            recordStepViewed(currentStep)
            return
        }
        log(.started)
        recordStepViewed(currentStep)
    }

    func recordStepViewed(_ step: OnboardingStep) {
        stepEnteredAt = Date()
        var properties = baseProperties(step: step)
        properties.step = OnboardingDraftBridge.analyticsStepName(step)
        properties.stage = step.stage.rawValue
        log(.stepViewed, properties: properties)

        if step == .appleHealth {
            logAppleHealth(.appleHealthPromptViewed)
            logAppleHealth(.appleHealthOnboardingViewed)
        }
    }

    func recordStepCompleted(for step: OnboardingStep) {
        var properties = baseProperties(step: step)
        properties.step = OnboardingDraftBridge.analyticsStepName(step)
        properties.stage = step.stage.rawValue
        properties.durationMs = stepDurationMs
        log(.stepCompleted, properties: properties)
    }

    func logPlanGenerated(
        currentStep: OnboardingStep,
        formState: OnboardingFormState,
        plan: CalorieTargetResult,
        revealState: OnboardingPlanRevealState?
    ) {
        log(.planGenerated, properties: planProperties(
            step: currentStep,
            formState: formState,
            plan: plan,
            revealState: revealState
        ))
    }

    func logPlanRevealed(
        formState: OnboardingFormState,
        plan: CalorieTargetResult,
        revealState: OnboardingPlanRevealState?
    ) {
        log(.planRevealed, properties: planProperties(
            step: .planReveal,
            formState: formState,
            plan: plan,
            revealState: revealState
        ))
    }

    func logProfileSavedLocal(
        currentStep: OnboardingStep,
        formState: OnboardingFormState,
        generatedPlan: CalorieTargetResult?,
        revealState: OnboardingPlanRevealState?
    ) {
        log(.profileSavedLocal, properties: planProperties(
            step: currentStep,
            formState: formState,
            plan: generatedPlan,
            revealState: revealState
        ))
    }

    func logSignInStarted() {
        log(.signInStarted)
    }

    func logSignInCancelled() {
        log(.signInCancelled)
    }

    func logSignInCompleted() {
        log(.signInCompleted)
    }

    func logCompleted(
        currentStep: OnboardingStep,
        formState: OnboardingFormState,
        generatedPlan: CalorieTargetResult?,
        revealState: OnboardingPlanRevealState?,
        completionPath: String
    ) {
        var properties = planProperties(
            step: currentStep,
            formState: formState,
            plan: generatedPlan,
            revealState: revealState
        )
        properties.completionPath = completionPath
        log(.completed, properties: properties)
    }

    func logAppleHealth(
        _ event: OnboardingAnalyticsEvent,
        permissionResult: String? = nil
    ) {
        var properties = baseProperties(step: .appleHealth)
        properties.step = OnboardingDraftBridge.analyticsStepName(.appleHealth)
        properties.permissionResult = permissionResult
        log(event, properties: properties)
    }

    private func log(
        _ event: OnboardingAnalyticsEvent,
        properties: OnboardingAnalyticsProperties? = nil
    ) {
        let resolved = properties ?? baseProperties(step: .introProof)
        analyticsLogger.log(event, properties: resolved)
    }

    private func baseProperties(step: OnboardingStep) -> OnboardingAnalyticsProperties {
        OnboardingAnalyticsProperties(
            step: OnboardingDraftBridge.analyticsStepName(step),
            stage: step.stage.rawValue,
            entry: analyticsEntry
        )
    }

    private func planProperties(
        step: OnboardingStep,
        formState: OnboardingFormState,
        plan: CalorieTargetResult?,
        revealState: OnboardingPlanRevealState?
    ) -> OnboardingAnalyticsProperties {
        var properties = baseProperties(step: step)
        guard let plan else { return properties }

        let planProperties = OnboardingAnalyticsContextBuilder.planProperties(
            formState: formState,
            plan: plan,
            revealState: revealState
        )
        properties.goalDirection = planProperties.goalDirection
        properties.isAggressive = planProperties.isAggressive
        properties.estimatedWeeks = planProperties.estimatedWeeks
        return properties
    }

    private var stepDurationMs: Int {
        max(0, Int(Date().timeIntervalSince(stepEnteredAt) * 1000))
    }
}
