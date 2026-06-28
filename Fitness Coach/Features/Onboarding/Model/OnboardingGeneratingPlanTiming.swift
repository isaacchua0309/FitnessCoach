//
//  OnboardingGeneratingPlanTiming.swift
//  Fitness Coach
//
//  Forma — Shared timing for the onboarding plan-generation moment.
//

import Foundation

enum OnboardingGeneratingPlanTiming {

    static let heroAppearDelay: TimeInterval = 0
    static let titleSubtitleDelay: TimeInterval = 0.30
    static let firstStepDelay: TimeInterval = 0.60
    static let stepTransitionAnimation: TimeInterval = 0.28

    /// Pause while each step is active before advancing to the next.
    static let stepActiveDurations: [TimeInterval] = [0.58, 0.62, 0.66, 0.62, 0.58]

    /// Brief success beat after the final step before routing to plan reveal.
    static let successHold: TimeInterval = 0.55

    /// Reassuring copy when generation outlasts the staged animation.
    static let slowGenerationThreshold: TimeInterval = 3.5

    /// Minimum staged presentation time before the success beat can begin.
    static var minimumPresentationBeforeSuccess: TimeInterval {
        firstStepDelay + stepActiveDurations.reduce(0, +)
    }

    /// Minimum time the generating screen stays visible while the plan is computed.
    static var minimumDisplayDuration: TimeInterval {
        minimumPresentationBeforeSuccess + successHold
    }

    static func validateChecklistAlignment() {
        assert(
            stepActiveDurations.count == FormaProductCopy.Onboarding.V2.Generating.checklist.count,
            "Generating step timing must match checklist copy count."
        )
    }
}
