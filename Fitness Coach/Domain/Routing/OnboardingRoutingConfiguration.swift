//
//  OnboardingRoutingConfiguration.swift
//  Fitness Coach
//
//  Forma — Injectable onboarding shell routing policy for AppContainer.
//

import Foundation

struct OnboardingRoutingConfiguration: Equatable, Sendable {
    var isV2Enabled: Bool
    var routingMode: OnboardingV2RoutingMode
    var signedOutWithProfilePolicy: SignedOutWithProfilePolicy

    init(
        isV2Enabled: Bool = OnboardingV2FeatureFlag.isEnabled,
        routingMode: OnboardingV2RoutingMode = OnboardingV2FeatureFlag.routingMode,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn
    ) {
        self.isV2Enabled = isV2Enabled
        self.routingMode = routingMode
        self.signedOutWithProfilePolicy = signedOutWithProfilePolicy
    }

    static let production = OnboardingRoutingConfiguration()

    var usesPreAuthShellRouting: Bool {
        isV2Enabled && routingMode.usesPreAuthShell
    }
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
                isOnboardingV2Enabled: configuration.isV2Enabled,
                signedOutWithProfilePolicy: configuration.signedOutWithProfilePolicy,
                awaitingCloudSync: input.awaitingCloudSync
            )
        )
    }
}
