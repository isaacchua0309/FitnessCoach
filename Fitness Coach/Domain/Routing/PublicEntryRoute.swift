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
    }

    /// Resolves the signed-out app shell route from public entry state.
    static func resolveSignedOutShell(_ input: Input) -> AppShellRoute {
        if input.hasLocalProfile,
           input.signedOutWithProfilePolicy == .allowLocalMain,
           !input.pendingOnboardingCompletion {
            return .localMain
        }

        if shouldBypassWelcome(input) {
            return onboardingShell(isOnboardingModelReady: input.isOnboardingModelReady)
        }

        switch input.destination {
        case .welcome:
            return .welcome
        case .existingUserSignIn:
            return .existingUserSignIn
        case .onboardingStart:
            return onboardingShell(isOnboardingModelReady: input.isOnboardingModelReady)
        }
    }

    /// Resume save-plan handoff or in-progress draft without showing welcome.
    static func shouldBypassWelcome(_ input: Input) -> Bool {
        if input.pendingOnboardingCompletion { return true }
        if input.localProfileAwaitingSignIn { return true }
        if input.hasPersistedOnboardingDraft, !input.hasLocalProfile { return true }
        return false
    }

    private static func onboardingShell(isOnboardingModelReady: Bool) -> AppShellRoute {
        isOnboardingModelReady ? .onboardingStart : .onboardingStartInitializing
    }
}
