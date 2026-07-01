//
//  OnboardingPlanGenerationExecutor.swift
//  Fitness Coach
//
//  Target generation and reveal timing for onboarding.
//

import Foundation
import UIKit

@MainActor
final class OnboardingPlanGenerationExecutor {

    private let planTargetCalculator: any PlanTargetCalculating
    private let generationDelay: any OnboardingGenerationDelayProviding

    init(
        planTargetCalculator: any PlanTargetCalculating,
        generationDelay: any OnboardingGenerationDelayProviding
    ) {
        self.planTargetCalculator = planTargetCalculator
        self.generationDelay = generationDelay
    }

    func firstInvalidRequiredStep(for formState: OnboardingFormState) -> OnboardingStep? {
        OnboardingFormState.firstInvalidRequiredStep(for: formState)
    }

    func validationMessage(for step: OnboardingStep, formState: OnboardingFormState) -> String? {
        formState.validationMessage(for: step)
    }

    func generatePlan(from formState: OnboardingFormState) throws -> CalorieTargetResult {
        let input = try formState.makeCalorieTargetInput()
        return try planTargetCalculator.generateInitialTargets(from: input)
    }

    func runGeneration(
        formState: OnboardingFormState,
        startedAt: Date = Date()
    ) async throws -> CalorieTargetResult {
        let plan = try generatePlan(from: formState)

        let elapsed = Date().timeIntervalSince(startedAt)
        let remaining = max(
            0,
            OnboardingGeneratingPlanTiming.minimumPresentationBeforeSuccess - elapsed
        )
        await generationDelay.delay(for: remaining)

        try Task.checkCancellation()
        return plan
    }

    func buildPlanReveal(
        formState: OnboardingFormState,
        plan: CalorieTargetResult
    ) -> OnboardingPlanRevealState? {
        OnboardingPlanRevealBuilder.build(formState: formState, plan: plan)
    }

    func successHoldDuration() -> TimeInterval {
        UIAccessibility.isReduceMotionEnabled ? 0 : OnboardingGeneratingPlanTiming.successHold
    }
}
