//
//  WelcomeOnboardingHandoffPolicy.swift
//  Fitness Coach
//
//  Forma — Public welcome → pre-auth onboarding handoff policy.
//

import Foundation

enum WelcomeOnboardingHandoffSource: Equatable, Sendable {
    /// User tapped Create My Plan on the public welcome screen.
    case welcomeCreatePlan
    /// Cold launch resumed an in-progress draft without showing welcome.
    case coldLaunchResume
    /// Save-plan handoff while signed out (local profile awaiting sign-in).
    case savePlanHandoff
}

enum WelcomeOnboardingHandoffPolicy {

    static let createPlanDestination: PublicEntryRoute = .onboardingStart
    static let preAuthEntry: OnboardingAnalyticsEntry = .preAuth

    static var canonicalFirstStep: OnboardingStep {
        OnboardingEntry.initialStep(for: preAuthEntry)
    }

    static func shouldBypassWelcome(_ input: PublicEntryRouteResolver.Input) -> Bool {
        PublicEntryRouteResolver.shouldBypassWelcome(input)
    }

    static func shellRoute(isOnboardingModelReady: Bool) -> AppShellRoute {
        isOnboardingModelReady ? .onboardingStart : .onboardingStartInitializing
    }

    /// Pre-auth onboarding from welcome never requires sign-in before the flow starts.
    static let requiresSignInBeforeOnboarding = false

    /// Save-plan completion for pre-auth onboarding still uses Google sign-in at the tail.
    static var requiresGoogleSignInAtSavePlan: Bool { true }
}
