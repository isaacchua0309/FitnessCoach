//
//  AuthGateRoutingPolicy.swift
//  Fitness Coach
//
//  AuthGateView shell routing overlays (testable without SwiftUI).
//

import Foundation

enum AuthGateRoutingPolicy {

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
        case .missingCloudProfile, .onboardingCloudProfileConflict, .onboardingCloudCheckFailed,
             .existingUserProfileLookupFailed, .cloudProfileUploadFailed, .accountProfileMismatch,
             .main, .error:
            return false
        }
    }

    /// Keep the user on onboarding instead of welcome or sign-in
    /// while an onboarding session is active (e.g. save-plan sign-in or in-progress draft).
    static func effectiveRoute(
        baseRoute: AppShellRoute,
        isSignedIn: Bool,
        hasActiveOnboardingSession: Bool,
        suppressAutomaticPublicEntryResume: Bool = false
    ) -> AppShellRoute {
        guard shouldPreferActiveOnboardingSession(
            isSignedIn: isSignedIn,
            hasActiveOnboardingSession: hasActiveOnboardingSession,
            baseRoute: baseRoute,
            suppressAutomaticPublicEntryResume: suppressAutomaticPublicEntryResume
        ) else {
            return baseRoute
        }
        return hasActiveOnboardingSession ? .onboardingStart : .onboardingStartInitializing
    }

    static func shouldPreferActiveOnboardingSession(
        isSignedIn: Bool,
        hasActiveOnboardingSession: Bool,
        baseRoute: AppShellRoute,
        suppressAutomaticPublicEntryResume: Bool = false
    ) -> Bool {
        guard !suppressAutomaticPublicEntryResume else { return false }
        guard hasActiveOnboardingSession, !isSignedIn else { return false }
        switch baseRoute {
        case .welcome, .onboardingStart, .onboardingStartInitializing:
            return true
        case .existingUserSignIn:
            // Returning-member sign-in must not be replaced by an in-progress draft session.
            return false
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
        hasLocalProfile: Bool = false,
        hasPersistedOnboardingDraft: Bool = false
    ) -> Bool {
        guard wasSignedIn, !isSignedIn else { return false }
        _ = hasLocalProfile
        _ = hasPersistedOnboardingDraft
        return true
    }
}
