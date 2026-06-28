//
//  ProfileSignInCopyPolicy.swift
//  Fitness Coach
//
//  Forma — Context-specific Google sign-in presentation copy.
//

import Foundation

enum ProfileSignInCopyPolicy {

    static func googleButtonTitle(for intent: ProfileSignInIntent) -> String {
        switch intent {
        case .existingUserRestore:
            return FormaProductCopy.PublicEntry.ExistingUserSignIn.googleSignInCTA
        case .onboardingCompletion:
            return FormaProductCopy.Onboarding.V2.SavePlan.googleSignInCTA
        }
    }

    static func googleButtonAccessibilityHint(for intent: ProfileSignInIntent) -> String {
        switch intent {
        case .existingUserRestore:
            return FormaProductCopy.PublicEntry.ExistingUserSignIn.googleSignInAccessibilityHint
        case .onboardingCompletion:
            return FormaProductCopy.Onboarding.V2.SavePlan.googleSignInAccessibilityHint
        }
    }

    /// Guardrail: returning-member sign-in must not use onboarding protect-progress phrasing.
    static func usesOnboardingCompletionLanguage(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("protect your progress")
            || normalized.contains("protect with google")
            || normalized.contains("keep your personalized plan safe")
            || normalized.contains("saving your progress")
    }

    @available(*, deprecated, renamed: "usesOnboardingCompletionLanguage")
    static func usesSavePlanLanguage(_ text: String) -> Bool {
        usesOnboardingCompletionLanguage(text)
    }
}
