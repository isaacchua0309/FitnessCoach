//
//  OnboardingV4FeatureFlag.swift
//  Fitness Coach
//
//  Forma — Onboarding v4 rollout flag (marketing-first flow skeleton).
//

import Foundation

enum OnboardingV4FeatureFlag {

    static let enabledKey = "forma.onboarding.v4.enabled"

    #if DEBUG
    static let debugEnabledEnvironmentKey = "FORMA_ONBOARDING_V4"
    #endif

    /// Master switch for onboarding v4. Defaults to `false`; opt in via UserDefaults or DEBUG env.
    static var isEnabled: Bool {
        #if DEBUG
        if let override = ProcessInfo.processInfo.environment[debugEnabledEnvironmentKey] {
            return override == "1"
        }
        #endif
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: enabledKey) != nil else {
            return false
        }
        return defaults.bool(forKey: enabledKey)
    }

    /// V4 requires the v2 onboarding shell and takes precedence over v3 when active.
    static var isActive: Bool {
        isEnabled && OnboardingV2FeatureFlag.isV2Active
    }

    #if DEBUG
    static func setEnabled(_ enabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(enabled, forKey: enabledKey)
    }
    #endif
}
