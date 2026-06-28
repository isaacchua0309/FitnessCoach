//
//  ProfileSignInIntent.swift
//  Fitness Coach
//
//  Forma — Product sign-in intents for profile restore vs onboarding save-plan.
//

import Foundation

/// The two user-facing Google sign-in flows that differ in copy and profile resolution.
enum ProfileSignInIntent: Equatable, Sendable {
    /// Returning member restoring an existing Forma profile from the public entry funnel.
    case existingUserRestore
    /// Onboarding save-plan sign-in after the user built a plan on-device.
    case onboardingCompletion

    var signInContext: SignInContext {
        switch self {
        case .existingUserRestore:
            return .existingUserEntry
        case .onboardingCompletion:
            return .onboardingCompletion
        }
    }

    /// Resolves the active intent from AuthGate session flags (`nil` when neither flow is active).
    init?(
        pendingOnboardingCompletion: Bool,
        pendingExistingUserSignIn: Bool
    ) {
        if pendingOnboardingCompletion {
            self = .onboardingCompletion
            return
        }
        if pendingExistingUserSignIn {
            self = .existingUserRestore
            return
        }
        return nil
    }
}

extension ProfileBootstrapCoordinator {

    static func profileSignInIntent(
        for input: SignedInProfileReconcileInput
    ) -> ProfileSignInIntent? {
        ProfileSignInIntent(
            pendingOnboardingCompletion: input.pendingOnboardingCompletion,
            pendingExistingUserSignIn: input.pendingExistingUserSignIn
        )
    }

    static func signInContext(for input: SignedInProfileReconcileInput) -> SignInContext {
        if let intent = profileSignInIntent(for: input) {
            return intent.signInContext
        }
        if input.isFreshSignIn {
            return .returningUser
        }
        return .normalLaunch
    }
}
