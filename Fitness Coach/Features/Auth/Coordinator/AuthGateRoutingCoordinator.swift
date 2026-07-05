//
//  AuthGateRoutingCoordinator.swift
//  Fitness Coach
//
//  Pure route input assembly and AppShellRoute resolution for the auth gate.
//

import Foundation

/// Snapshot of coordinator state that influences `AuthGateCoordinator.effectiveRoute`.
struct AuthGateRouteInputs: Equatable, Sendable {
    var authState: AuthState
    var rootState: RootViewState
    var isOnboardingModelReady: Bool
    var awaitingCloudSync: Bool
    var pendingOnboardingCompletion: Bool
    var publicEntryDestination: PublicEntryRoute
    var suppressAutomaticPublicEntryResume: Bool

    var isSignedIn: Bool {
        AppRouteResolver.isSignedIn(authState)
    }

    var hasActiveOnboardingSession: Bool {
        isOnboardingModelReady
    }
}

/// Stateless route resolver for the auth-gated shell.
enum AuthGateRoutingCoordinator {

    static func baseRoute(
        inputs: AuthGateRouteInputs,
        container: AppContainer
    ) -> AppShellRoute {
        container.resolveAppShellRoute(
            authState: inputs.authState,
            rootState: inputs.rootState,
            isOnboardingModelReady: inputs.isOnboardingModelReady,
            awaitingCloudSync: inputs.awaitingCloudSync,
            pendingOnboardingCompletion: inputs.pendingOnboardingCompletion,
            publicEntryDestination: inputs.publicEntryDestination
        )
    }

    static func effectiveRoute(
        inputs: AuthGateRouteInputs,
        container: AppContainer
    ) -> AppShellRoute {
        let base = baseRoute(inputs: inputs, container: container)
        return AuthGateRoutingPolicy.effectiveRoute(
            baseRoute: base,
            isSignedIn: inputs.isSignedIn,
            hasActiveOnboardingSession: inputs.hasActiveOnboardingSession,
            suppressAutomaticPublicEntryResume: inputs.suppressAutomaticPublicEntryResume
        )
    }
}
