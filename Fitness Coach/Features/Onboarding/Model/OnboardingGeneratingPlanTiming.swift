//
//  OnboardingGeneratingPlanTiming.swift
//  Fitness Coach
//
//  Forma — Shared timing for the onboarding plan-generation moment.
//

import Foundation

enum OnboardingGeneratingPlanTiming {

    static let initialDelay: TimeInterval = 0.35
    static let itemRevealAnimation: TimeInterval = 0.30

    /// Pause after each checklist item is revealed; later items linger slightly longer.
    static let intervalsAfterReveal: [TimeInterval] = [0.42, 0.46, 0.50, 0.54, 0.58]

    /// Brief beat after the final item so the transition to plan reveal does not feel abrupt.
    static let postCompleteHold: TimeInterval = 0.35

    /// Minimum time the generating screen stays visible while the plan is computed.
    static var minimumDisplayDuration: TimeInterval {
        initialDelay + intervalsAfterReveal.reduce(0, +) + postCompleteHold
    }

    static func validateChecklistAlignment() {
        assert(
            intervalsAfterReveal.count == FormaProductCopy.Onboarding.V2.Generating.checklist.count,
            "Generating checklist timing must match checklist copy count."
        )
    }
}
