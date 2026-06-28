//
//  PublicEntryCopyGuardrail.swift
//  Fitness Coach
//
//  Forma — Copy guardrails for public entry screens.
//

import Foundation

enum PublicEntryCopyGuardrail {

    /// Marketing claims that must not appear on public entry surfaces.
    static let bannedTrustPhrases = [
        "200M",
        "200m",
        "million users",
        "4.9",
        "#1 app",
        "#1 fitness",
        "rated #1",
        "app store's #1"
    ]

    /// All user-visible public-entry strings for regression scanning.
    static var allUserFacingStrings: [String] {
        let welcome = FormaProductCopy.PublicEntry.Welcome.self
        let signIn = FormaProductCopy.PublicEntry.ExistingUserSignIn.self
        let signInError = FormaProductCopy.PublicEntry.ExistingUserSignIn.Error.self
        let lookupFailed = FormaProductCopy.PublicEntry.ExistingUserSignIn.ProfileLookupFailed.self
        let noPlan = FormaProductCopy.PublicEntry.NoExistingPlan.self
        let loading = FormaProductCopy.PublicEntry.Loading.self

        return [
            welcome.title,
            welcome.headline,
            welcome.supportingCopy,
            welcome.createMyPlanCTA,
            welcome.existingAccountPrompt,
            welcome.signInCTA,
            welcome.createPlanAccessibilityHint,
            welcome.signInAccessibilityLabel,
            welcome.signInAccessibilityHint,
            welcome.benefitsAccessibilityLabel
        ]
        + welcome.benefits.map(\.title)
        + [
            signIn.title,
            signIn.subtitle,
            signIn.supportingCopy,
            signIn.resolvingMessage,
            signIn.newToFormaPrompt,
            signIn.createMyPlanCTA,
            signIn.createMyPlanAccessibilityHint,
            signIn.backAccessibilityLabel,
            signIn.googleSignInCTA,
            signIn.googleSignInAccessibilityHint,
            signInError.cancelledTitle,
            signInError.cancelledMessage,
            signInError.authFailedTitle,
            signInError.authFailedMessage,
            signInError.networkFailedTitle,
            signInError.networkFailedMessage,
            signInError.profileLookupFailedTitle,
            signInError.profileLookupFailedMessage,
            lookupFailed.title,
            lookupFailed.body,
            lookupFailed.retryCTA,
            noPlan.title,
            noPlan.subtitle,
            noPlan.supportingCopy,
            noPlan.startOnboardingCTA,
            noPlan.useAnotherAccountCTA,
            noPlan.startOnboardingAccessibilityHint,
            noPlan.useAnotherAccountAccessibilityHint,
            loading.appLaunch,
            loading.restoringPlan
        ]
    }

    static func containsBannedTrustClaim(_ text: String) -> Bool {
        let normalized = text.lowercased()
        return bannedTrustPhrases.contains { normalized.contains($0.lowercased()) }
    }
}
