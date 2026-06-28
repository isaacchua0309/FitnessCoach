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
                supportingCopy: "",
                isPlaceholder: true,
                accessibilityLabel: copy.explanationPlaceholder
            )
        }

        let headline = selectedExplanation(for: formState.activityLevel)
        return OnboardingActivityLevelExplanationState(
            headline: headline,
            supportingCopy: "",
            isPlaceholder: false,
            accessibilityLabel: headline
        )
    }

    static func selectedExplanation(for level: ActivityLevel) -> String {
        explanationHeadline(for: level)
    }

    static func voiceOverLabel(
        for level: ActivityLevel,
        isSelected: Bool
    ) -> String {
        let title = OnboardingFormatter.activityLevel(level)
        let description = OnboardingActivityLevelValues.optionDescription(for: level)
        if isSelected {
            let explanation = selectedExplanation(for: level)
            return "\(title), \(description), selected. \(explanation)"
        }
        return "Select \(title), \(description)"
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
