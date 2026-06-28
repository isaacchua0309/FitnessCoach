//
//  NoExistingProfileFoundPolicy.swift
//  Fitness Coach
//
//  Forma — Pure handoff policy for the no-existing-profile interstitial.
//

import Foundation

enum NoExistingProfileFoundPolicy {

    static func onboardingEntry(isSignedIn: Bool) -> OnboardingAnalyticsEntry {
        isSignedIn ? .postAuth : .preAuth
    }

    static let useAnotherAccountDestination: PublicEntryRoute = .existingUserSignIn
}
