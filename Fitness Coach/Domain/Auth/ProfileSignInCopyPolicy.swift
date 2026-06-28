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

    /// Guardrail: returning-member sign-in must not use onboarding save-plan phrasing.
    static func usesSavePlanLanguage(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return normalized.contains("save your plan")
            || normalized.contains("save my plan")
    }
}
