//
//  OnboardingRoutingConfiguration.swift
//  Fitness Coach
//
//  Forma — Injectable onboarding shell policy for AppContainer.
//

import Foundation

struct OnboardingRoutingConfiguration: Equatable, Sendable {
    static let production = OnboardingRoutingConfiguration()
}

enum OnboardingShellRouting {
    static func resolve(
        _ input: OnboardingShellRouteInput,
        configuration: OnboardingRoutingConfiguration = .production
    ) -> OnboardingShellRoute {
        _ = configuration
        return OnboardingShellRouteResolver.resolve(input)
    }
}
