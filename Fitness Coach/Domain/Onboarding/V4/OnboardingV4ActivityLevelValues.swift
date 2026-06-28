//
//  OnboardingV4ActivityLevelValues.swift
//  Fitness Coach
//
//  Forma — V4 activity selection and hidden training rhythm defaults.
//

import Foundation

enum OnboardingV4ActivityLevelValues {

    static let orderedLevels: [ActivityLevel] = ActivityLevel.allCases

    static func optionDescription(for level: ActivityLevel) -> String {
        switch level {
        case .sedentary:
            return FormaProductCopy.Onboarding.V4.Activity.sedentaryDescription
        case .lightlyActive:
            return FormaProductCopy.Onboarding.V4.Activity.lightlyActiveDescription
        case .moderatelyActive:
            return FormaProductCopy.Onboarding.V4.Activity.moderatelyActiveDescription
        case .veryActive:
            return FormaProductCopy.Onboarding.V4.Activity.veryActiveDescription
        case .athlete:
            return FormaProductCopy.Onboarding.V4.Activity.extraActiveDescription
        }
    }

    static func applyDefaultsIfNeeded(to formState: inout OnboardingFormState) {
        formState.applyTrainingRhythmDefaultsForCurrentActivity()
    }

    static func select(_ level: ActivityLevel, in formState: inout OnboardingFormState) {
        formState.selectActivityLevel(level)
        formState.applyTrainingRhythmDefaultsForCurrentActivity()
    }

    static func expectedDefaults(for level: ActivityLevel) -> TrainingRhythmDefaults {
        ActivityTrainingDefaultsResolver().defaults(for: level)
    }
}
