//
//  PublicEntryRoute.swift
//  Fitness Coach
//
//  Forma — Public entry destinations for logged-out users (welcome funnel).
//

import Foundation

/// User-selected or resumed destination before authentication.
enum PublicEntryRoute: Equatable, Sendable {
    case welcome
    case existingUserSignIn
    case onboardingStart
}

enum PublicEntryRouteResolver {

    struct Input: Equatable, Sendable {
        var destination: PublicEntryRoute
        var isOnboardingModelReady: Bool
        var localProfileAwaitingSignIn: Bool
        var hasPersistedOnboardingDraft: Bool
        var hasLocalProfile: Bool
        var pendingOnboardingCompletion: Bool
        var signedOutWithProfilePolicy: SignedOutWithProfilePolicy
        /// When true (after explicit sign-out), draft/save-plan handoff must not bypass welcome.
        var suppressAutomaticPublicEntryResume: Bool

        init(
            destination: PublicEntryRoute,
            isOnboardingModelReady: Bool,
            localProfileAwaitingSignIn: Bool,
            hasPersistedOnboardingDraft: Bool,
            hasLocalProfile: Bool,
            pendingOnboardingCompletion: Bool,
            signedOutWithProfilePolicy: SignedOutWithProfilePolicy,
            suppressAutomaticPublicEntryResume: Bool = false
        ) {
            self.destination = destination
            self.isOnboardingModelReady = isOnboardingModelReady
            self.localProfileAwaitingSignIn = localProfileAwaitingSignIn
            self.hasPersistedOnboardingDraft = hasPersistedOnboardingDraft
            self.hasLocalProfile = hasLocalProfile
            self.pendingOnboardingCompletion = pendingOnboardingCompletion
            self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
            self.suppressAutomaticPublicEntryResume = suppressAutomaticPublicEntryResume
        }
    }

    /// Resolves the signed-out app shell route from public entry state.
    static func resolveSignedOutShell(_ input: Input) -> AppShellRoute {
        // Explicit navigation beats automatic draft / save-plan resume.
        switch input.destination {
        case .existingUserSignIn:
            return .existingUserSignIn
        case .onboardingStart:
            return onboardingShell(isOnboardingModelReady: input.isOnboardingModelReady)
        case .welcome:
            if shouldBypassWelcome(input) {
                return onboardingShell(isOnboardingModelReady: input.isOnboardingModelReady)
            }
            return .welcome
        }
    }

    /// Resume save-plan handoff or in-progress draft without showing welcome.
    static func shouldBypassWelcome(_ input: Input) -> Bool {
        if input.suppressAutomaticPublicEntryResume { return false }
        if input.pendingOnboardingCompletion { return true }
        if input.localProfileAwaitingSignIn { return true }
        if input.hasPersistedOnboardingDraft, !input.hasLocalProfile { return true }
        return false
    }

    private static func onboardingShell(isOnboardingModelReady: Bool) -> AppShellRoute {
        isOnboardingModelReady ? .onboardingStart : .onboardingStartInitializing
    }
}
