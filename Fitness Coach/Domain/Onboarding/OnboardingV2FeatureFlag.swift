//
//  OnboardingV2FeatureFlag.swift
//  Fitness Coach
//
//  Forma — Single source of truth for onboarding v2 rollout and rollback.
//

import Foundation

/// How onboarding v2 is exposed in the app shell when the master flag is on.
enum OnboardingV2RoutingMode: String, Equatable, Sendable, CaseIterable {
    /// Full pre-auth onboarding (landing → save plan → optional Google sign-in).
    case preAuth
    /// Value-first teaser: landing + welcome before Google, then motivation onward post-sign-in.
    case valueFirstFallback

    nonisolated var usesPreAuthShell: Bool {
        switch self {
        case .preAuth, .valueFirstFallback:
            return true
        }
    }
}

enum OnboardingV2FeatureFlag {

    nonisolated static let enabledKey = "forma.onboarding.v2.enabled"
    nonisolated static let routingModeKey = "forma.onboarding.v2.routingMode"

    #if DEBUG
    nonisolated static let debugEnabledEnvironmentKey = "FORMA_ONBOARDING_V2"
    nonisolated static let debugRoutingEnvironmentKey = "FORMA_ONBOARDING_V2_ROUTING"
    #endif

    /// Master switch — defaults to `true` for new installs; set `false` in UserDefaults to roll back.
    nonisolated static var isEnabled: Bool {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment[debugEnabledEnvironmentKey] {
            return override == "1"
        }
        #endif
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: enabledKey) != nil else {
            return true
        }
        return defaults.bool(forKey: enabledKey)
    }

    /// Active routing mode when `isEnabled`; `.preAuth` when disabled (legacy path).
    nonisolated static var routingMode: OnboardingV2RoutingMode {
        guard isEnabled else { return .preAuth }
        return resolvedRoutingMode()
    }

    /// Whether any v2 onboarding UI/logic should run (master flag only).
    nonisolated static var isV2Active: Bool { isEnabled }

    /// Whether shell routing should use the signed-out onboarding route.
    nonisolated static var usesPreAuthShellRouting: Bool {
        isEnabled && routingMode.usesPreAuthShell
    }

    #if DEBUG
    /// QA helper — enable v2 pre-auth routing in DEBUG builds without editing UserDefaults.
    static func setEnabled(_ enabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(enabled, forKey: enabledKey)
    }

    static func setRoutingMode(
        _ mode: OnboardingV2RoutingMode,
        userDefaults: UserDefaults = .standard
    ) {
        userDefaults.set(mode.rawValue, forKey: routingModeKey)
    }
    #endif

    nonisolated private static func resolvedRoutingMode() -> OnboardingV2RoutingMode {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment[debugRoutingEnvironmentKey],
           let mode = OnboardingV2RoutingMode(rawValue: override) {
            return mode
        }
        #endif
        if let stored = UserDefaults.standard.string(forKey: routingModeKey),
           let mode = OnboardingV2RoutingMode(rawValue: stored) {
            return mode
        }
        return .preAuth
    }
}
