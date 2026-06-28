//
//  OnboardingActivityLevelExplanationBuilder.swift
//  Fitness Coach
//
//  Forma — Live explanation card for activity level onboarding.
//

import Foundation

struct OnboardingActivityLevelExplanationState: Equatable, Sendable {
    let headline: String
    let supportingCopy: String
    let isPlaceholder: Bool
    let accessibilityLabel: String
}

enum OnboardingActivityLevelExplanationBuilder {

    static func build(from formState: OnboardingFormState) -> OnboardingActivityLevelExplanationState {
        let copy = FormaProductCopy.Onboarding.Flow.Activity.self

        guard formState.hasConfirmedActivityLevelSelection else {
            return OnboardingActivityLevelExplanationState(
                headline: copy.explanationPlaceholder,
                supportingCopy: copy.explanationSupporting,
                isPlaceholder: true,
                accessibilityLabel: copy.explanationPlaceholder
            )
        }

        let headline = explanationHeadline(for: formState.activityLevel)
        return OnboardingActivityLevelExplanationState(
            headline: headline,
            supportingCopy: copy.explanationSupporting,
            isPlaceholder: false,
            accessibilityLabel: "\(headline) \(copy.explanationSupporting)"
        )
    }

    static func voiceOverLabel(
        for level: ActivityLevel,
        isSelected: Bool
    ) -> String {
        let title = OnboardingFormatter.activityLevel(level)
        let description = OnboardingActivityLevelValues.optionDescription(for: level)
        if isSelected {
            return "\(title), \(description), selected."
        }
        return "Select \(title)"
    }

    private static func explanationHeadline(for level: ActivityLevel) -> String {
        let copy = FormaProductCopy.Onboarding.Flow.Activity.self
        switch level {
        case .sedentary:
            return copy.sedentaryExplanationHeadline
        case .lightlyActive:
            return copy.lightlyActiveExplanationHeadline
        case .moderatelyActive:
            return copy.moderatelyActiveExplanationHeadline
        case .veryActive:
            return copy.veryActiveExplanationHeadline
        case .athlete:
            return copy.extraActiveExplanationHeadline
        }
    }
}
