//
//  WelcomeOnboardingHandoffPolicy.swift
//  Fitness Coach
//
//  Forma — Public welcome → pre-auth onboarding handoff policy.
//

import Foundation

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

    /// Pre-auth intro proof may return to the public welcome screen.
    static func canExitToWelcome(
        step: OnboardingStep,
        analyticsEntry: OnboardingAnalyticsEntry
    ) -> Bool {
        analyticsEntry == .preAuth && step == .introProof
    }
}
