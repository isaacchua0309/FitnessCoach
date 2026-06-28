//
//  AuthGateRoutingPolicy.swift
//  Fitness Coach
//
//  AuthGateView shell routing overlays (testable without SwiftUI).
//

import Foundation

enum AuthGateRoutingPolicy {

    /// Signed-in users tapping "Sign in with Google" on the landing screen need a fresh
    /// sign-in flow instead of clearing the onboarding model into a signed-in initializing shell.
    static func shouldSignOutBeforeExistingAccountSignIn(isSignedIn: Bool) -> Bool {
        isSignedIn
    }

    /// Whether a signed-in session without a local profile should (re)run cloud bootstrap.
    static func shouldReloadSignedInCloudProfile(
        isFreshSignIn: Bool,
        rootState: RootViewState,
        hasLocalProfile: Bool
    ) -> Bool {
        guard !hasLocalProfile else { return false }
        if isFreshSignIn { return true }
        switch rootState {
        case .loading, .onboarding:
            return true
        case .missingCloudProfile, .onboardingCloudProfileConflict, .onboardingCloudCheckFailed, .main, .error:
            return false
        }
    }

    /// When v2 pre-auth onboarding is active, keep the user on onboarding instead of
    /// the standalone sign-in screen (e.g. savePlan sign-in or in-progress draft).
    static func effectiveRoute(
        baseRoute: AppShellRoute,
        isV2Enabled: Bool,
        isSignedIn: Bool,
        hasActiveOnboardingSession: Bool
    ) -> AppShellRoute {
        guard shouldPreferActiveOnboardingSession(
            isV2Enabled: isV2Enabled,
            isSignedIn: isSignedIn,
            hasActiveOnboardingSession: hasActiveOnboardingSession,
            baseRoute: baseRoute
        ) else {
            return baseRoute
        }
        return hasActiveOnboardingSession ? .localOnboarding : .localOnboardingInitializing
    }

    static func shouldPreferActiveOnboardingSession(
        isV2Enabled: Bool,
        isSignedIn: Bool,
        hasActiveOnboardingSession: Bool,
        baseRoute: AppShellRoute
    ) -> Bool {
        guard isV2Enabled, hasActiveOnboardingSession, !isSignedIn else { return false }
        switch baseRoute {
        case .signIn, .localOnboarding, .localOnboardingInitializing:
            return true
        default:
            return false
        }
    }

    /// Defer the signed-in local-profile short-circuit while onboarding completion sign-in resolves cloud presence.
    static func shouldDeferLocalProfileShortCircuit(
        pendingOnboardingCompletion: Bool,
        hasLocalProfile: Bool
    ) -> Bool {
        pendingOnboardingCompletion && hasLocalProfile
    }

    static func shouldClearOnboardingModelOnSignOut(
        wasSignedIn: Bool,
        isSignedIn: Bool,
        hasLocalProfile: Bool,
        hasPersistedOnboardingDraft: Bool
    ) -> Bool {
        guard wasSignedIn, !isSignedIn else { return false }
        if hasPersistedOnboardingDraft, !hasLocalProfile {
            return false
        }
        return true
    }
}
