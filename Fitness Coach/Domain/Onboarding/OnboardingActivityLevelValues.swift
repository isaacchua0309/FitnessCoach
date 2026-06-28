//
//  OnboardingActivityLevelValues.swift
//  Fitness Coach
//
//  Forma — activity selection and hidden training rhythm defaults.
//

import Foundation

enum OnboardingActivityLevelValues {

    static let orderedLevels: [ActivityLevel] = ActivityLevel.allCases

    static func optionDescription(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return FormaProductCopy.Onboarding.Flow.Activity.sedentaryDescription
        case .lightlyActive:
            return FormaProductCopy.Onboarding.Flow.Activity.lightlyActiveDescription
        case .moderatelyActive:
            return FormaProductCopy.Onboarding.Flow.Activity.moderatelyActiveDescription
        case .veryActive:
            return FormaProductCopy.Onboarding.Flow.Activity.veryActiveDescription
        case .athlete:
            return FormaProductCopy.Onboarding.Flow.Activity.extraActiveDescription
        }
    }

    static func icon(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return "chair.fill"
        case .lightlyActive:
            return "figure.walk"
        case .moderatelyActive:
            return "figure.run"
        case .veryActive:
            return "figure.strengthtraining.traditional"
        case .athlete:
            return "bolt.heart.fill"
        }
    }

    static func applyDefaultsIfNeeded(to formState: inout OnboardingFormState) {
        formState.applyTrainingRhythmDefaultsForCurrentActivity()
    }

    static func select(_ level: ActivityLevel, in formState: inout OnboardingFormState) {
        formState.selectActivityLevel(level)
        formState.applyTrainingRhythmDefaultsForCurrentActivity()
    }

    static func validate(formState: OnboardingFormState) throws {
        guard formState.hasConfirmedActivityLevelSelection else {
            throw OnboardingFormError.invalid(
                FormaProductCopy.Onboarding.Flow.Activity.selectionRequiredMessage
            )
        }
    }

    static func expectedDefaults(for level: ActivityLevel) -> TrainingRhythmDefaults {
        ActivityTrainingDefaultsResolver().defaults(for: level)
    }
}
