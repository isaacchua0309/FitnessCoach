//
//  OnboardingLocalCompletionMarker.swift
//  Fitness Coach
//
//  Forma — Tracks when onboarding finished on-device without account linking.
//

import Foundation

enum OnboardingLocalCompletionMarker {

    private static let key = "forma.onboarding.localCompletionAcknowledged"

    static func markAcknowledged(userDefaults: UserDefaults = .standard) {
        userDefaults.set(true, forKey: key)
    }

    static func isAcknowledged(userDefaults: UserDefaults = .standard) -> Bool {
        userDefaults.bool(forKey: key)
    }

    static func clear(userDefaults: UserDefaults = .standard) {
        userDefaults.removeObject(forKey: key)
    }
}
