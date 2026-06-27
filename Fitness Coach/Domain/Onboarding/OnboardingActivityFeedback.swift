//
//  OnboardingActivityFeedback.swift
//  Fitness Coach
//
//  Forma — Activity step feedback copy for onboarding v2.
//

import Foundation

enum OnboardingActivityFeedback {

    static func message(for level: ActivityLevel) -> String {
        let copy = FormaProductCopy.Onboarding.V2.ActivityFeedback.self
        switch level {
        case .sedentary:
            return copy.sedentaryFeedback
        case .moderatelyActive:
            return copy.moderatelyActiveFeedback
        case .athlete:
            return copy.athleteFeedback
        case .lightlyActive, .veryActive:
            return copy.defaultFeedback
        }
    }
}
