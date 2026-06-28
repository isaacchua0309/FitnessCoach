//
//  OnboardingFlowScope.swift
//  Fitness Coach
//
//  Forma — Isolated onboarding flow variants behind the v2 feature flag.
//

import Foundation

/// Which step graph and handoff rules apply for the current onboarding session.
enum OnboardingFlowScope: Equatable, Sendable {
    /// Auth-first legacy wizard (welcome → plan preview).
    case legacy
    /// Full v2 flow including pre-auth landing/welcome.
    case v2Full
    /// Pre-sign-in teaser only: landing + welcome, then Google sign-in handoff.
    case v2ValueFirstTeaser
    /// Post-sign-in v2 continuation (motivation onward).
    case v2PostAuth

    var usesV2Steps: Bool {
        switch self {
        case .legacy:
            return false
        case .v2Full, .v2ValueFirstTeaser, .v2PostAuth:
            return true
        }
    }

    /// Marketing-first v4 step graph (requires v2 shell; gated by `OnboardingV4FeatureFlag`).
    var usesV4Steps: Bool {
        usesV2Steps && OnboardingV4FeatureFlag.isActive
    }

    /// Tap-first v3 step graph (requires v2 shell; gated by `OnboardingV3FeatureFlag`).
    var usesV3Steps: Bool {
        usesV2Steps && OnboardingV3FeatureFlag.isActive && !usesV4Steps
    }

    var v4Flow: [OnboardingV4Step] {
        OnboardingV4Step.flow(for: self)
    }

    var entryV4Step: OnboardingV4Step {
        v4Flow.first ?? .introProof
    }

    var v3Flow: [OnboardingV3Step] {
        OnboardingV3Step.flow(for: self)
    }

    var entryV3Step: OnboardingV3Step {
        v3Flow.first ?? .landing
    }

    var entryStep: OnboardingStep {
        switch self {
        case .legacy:
            return .welcome
        case .v2Full, .v2ValueFirstTeaser:
            return .landing
        case .v2PostAuth:
            return .motivation
        }
    }

    var flow: [OnboardingStep] {
        switch self {
        case .legacy:
            return OnboardingStep.legacyFlow
        case .v2Full:
            return OnboardingStep.v2Flow
        case .v2ValueFirstTeaser:
            return OnboardingStep.v2ValueFirstTeaserFlow
        case .v2PostAuth:
            return OnboardingStep.v2PostAuthFlow
        }
    }

    /// After welcome, request Google sign-in instead of continuing to motivation.
    var completesWithSignInAfterWelcome: Bool {
        self == .v2ValueFirstTeaser
    }

    static func resolve(
        routingMode: OnboardingV2RoutingMode,
        entry: OnboardingAnalyticsEntry,
        isV2Enabled: Bool = OnboardingV2FeatureFlag.isEnabled
    ) -> OnboardingFlowScope {
        guard isV2Enabled else { return .legacy }

        switch routingMode {
        case .preAuth:
            return entry == .preAuth ? .v2Full : .v2PostAuth
        case .valueFirstFallback:
            return entry == .preAuth ? .v2ValueFirstTeaser : .v2PostAuth
        }
    }
}

extension OnboardingStep {

    static let v2ValueFirstTeaserFlow: [OnboardingStep] = [.landing, .welcome]

    static let v2PostAuthFlow: [OnboardingStep] = [
        .motivation, .body, .goal, .activity, .preferences,
        .summary, .generatingPlan, .planReveal, .savePlan
    ]

    func isValid(for scope: OnboardingFlowScope) -> Bool {
        scope.flow.contains(self)
    }
}
