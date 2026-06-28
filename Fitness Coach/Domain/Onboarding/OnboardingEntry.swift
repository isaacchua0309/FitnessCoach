//
//  OnboardingEntry.swift
//  Fitness Coach
//
//  Forma — Entry step and back-navigation floor for the canonical onboarding flow.
//

import Foundation

enum OnboardingEntry {

    /// First step when there is no restorable draft and no committed profile session.
    static func initialStep(for analyticsEntry: OnboardingAnalyticsEntry) -> OnboardingStep {
        switch analyticsEntry {
        case .preAuth:
            return .introProof
        case .postAuth:
            return .heightWeight
        }
    }

    /// Earliest step the user may navigate back to in this session.
    static func flowFloor(
        analyticsEntry: OnboardingAnalyticsEntry,
        currentStep: OnboardingStep
    ) -> OnboardingStep {
        if analyticsEntry == .postAuth, currentStep != .introProof {
            return .heightWeight
        }
        return .introProof
    }
}
