//
//  OnboardingRoutingConfiguration.swift
//  Fitness Coach
//
//  Forma — Injectable onboarding shell policy for AppContainer.
//

import Foundation

struct OnboardingRoutingConfiguration: Equatable, Sendable {
    var signedOutWithProfilePolicy: SignedOutWithProfilePolicy

    init(signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn) {
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
    }

    static let production = OnboardingRoutingConfiguration()
}

extension OnboardingRoutingConfiguration {
    var allowsLocalOnlyContinuation: Bool {
        signedOutWithProfilePolicy == .allowLocalMain
    }
}

enum OnboardingShellRouting {
    static func resolve(
        _ input: OnboardingShellRouteInput,
        configuration: OnboardingRoutingConfiguration = .production
    ) -> OnboardingShellRoute {
        OnboardingShellRouteResolver.resolve(
            OnboardingShellRouteInput(
                authState: input.authState,
                hasLocalProfile: input.hasLocalProfile,
                rootState: input.rootState,
                isOnboardingModelReady: input.isOnboardingModelReady,
                signedOutWithProfilePolicy: configuration.signedOutWithProfilePolicy,
                awaitingCloudSync: input.awaitingCloudSync,
                localProfileAwaitingSignIn: input.localProfileAwaitingSignIn,
                pendingOnboardingCompletion: input.pendingOnboardingCompletion
            )
        )
    }
}
