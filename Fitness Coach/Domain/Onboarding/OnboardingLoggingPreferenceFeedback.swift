//
//  OnboardingLoggingPreferenceFeedback.swift
//  Fitness Coach
//
//  Forma — Logging preference feedback for onboarding v2.
//

import Foundation

enum OnboardingLoggingPreferenceFeedback {

    static func message(for selections: Set<OnboardingLoggingPreference>) -> String? {
        let copy = FormaProductCopy.Onboarding.V2.Preferences.self
        if selections.contains(.naturalLanguage) {
            return copy.naturalLanguageFeedback
        }
        if selections.contains(.noPressure) {
            return copy.noPressureFeedback
        }
        return nil
    }
}
