//
//  OnboardingGeneratingPlanCopyBuilder.swift
//  Fitness Coach
//
//  Forma — Goal-aware presentation copy for the plan-generation moment.
//

import Foundation

struct OnboardingGeneratingPlanPresentation: Equatable, Sendable {
    let subtitle: String
    let goalDirection: OnboardingGoalDirection
}

enum OnboardingGeneratingPlanCopyBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingGeneratingPlanPresentation {
        let direction = resolveDirection(from: formState)
        return OnboardingGeneratingPlanPresentation(
            subtitle: subtitle(for: direction, hasWeights: hasWeights(in: formState)),
            goalDirection: direction
        )
    }

    static func subtitle(for direction: OnboardingGoalDirection) -> String {
        subtitle(for: direction, hasWeights: true)
    }

    private static func hasWeights(in formState: OnboardingFormState) -> Bool {
        formState.parsedCurrentWeightKg != nil && formState.parsedGoalWeightKg != nil
    }

    private static func resolveDirection(from formState: OnboardingFormState) -> OnboardingGoalDirection {
        guard let currentKg = formState.parsedCurrentWeightKg,
              let goalKg = formState.parsedGoalWeightKg else {
            return .maintain
        }
        return OnboardingGoalProjectionBuilder.goalDirection(
            currentWeightKg: currentKg,
            goalWeightKg: goalKg
        )
    }

    private static func subtitle(for direction: OnboardingGoalDirection, hasWeights: Bool) -> String {
        let copy = FormaProductCopy.Onboarding.V2.Generating.Subtitle.self
        guard hasWeights else { return copy.fallback }
        switch direction {
        case .cut:
            return copy.loss
        case .gain:
            return copy.gain
        case .maintain:
            return copy.maintain
        }
    }
}
