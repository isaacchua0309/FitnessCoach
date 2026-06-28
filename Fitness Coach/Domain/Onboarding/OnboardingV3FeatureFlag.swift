//
//  OnboardingV3FeatureFlag.swift
//  Fitness Coach
//
//  Forma — Tap-first onboarding v3 rollout flag (Stage 1 foundation).
//

import Foundation

enum OnboardingV3FeatureFlag {

    static let enabledKey = "forma.onboarding.v3.enabled"

    #if DEBUG
    static let debugEnabledEnvironmentKey = "FORMA_ONBOARDING_V3"
    #endif

    /// Master switch for onboarding v3. Defaults to `true` for new installs; set `false` in UserDefaults to roll back.
    static var isEnabled: Bool {
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

    /// V3 requires the v2 onboarding shell (landing, save plan, plan reveal, etc.).
    static var isActive: Bool {
        isEnabled && OnboardingV2FeatureFlag.isV2Active
    }

    #if DEBUG
    static func setEnabled(_ enabled: Bool, userDefaults: UserDefaults = .standard) {
        userDefaults.set(enabled, forKey: enabledKey)
    }
    #endif
}
