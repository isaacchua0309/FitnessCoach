//
//  ProfileOwnershipResolver.swift
//  Fitness Coach
//
//  Forma — Pure signed-in profile ownership and bootstrap routing policy.
//

import Foundation

enum ProfileOwnershipResolver {

    static func resolve(_ input: ProfileOwnershipInput) -> ProfileOwnershipOutcome {
        if input.hasLocalProfilePendingOnboardingCompletion {
            return resolveOnboardingCompletion(input)
        }

        guard input.hasLocalProfile else {
            return resolveWithoutLocalProfile(input)
        }

        return resolveWithLocalProfile(input)
    }

    // MARK: - Onboarding completion

    private static func resolveOnboardingCompletion(
        _ input: ProfileOwnershipInput
    ) -> ProfileOwnershipOutcome {
        guard input.hasLocalProfile else {
            return resolveWithoutLocalProfile(input)
        }

        guard let cloudResult = input.cloudResult else {
            return .requireCloudLookup
        }

        switch cloudResult {
        case .found:
            return .showProfileConflict
        case .missing:
            return .uploadLocalProfile
        case .failed:
            return .showCloudFetchFailed
        }
    }

    // MARK: - No local profile

    private static func resolveWithoutLocalProfile(
        _ input: ProfileOwnershipInput
    ) -> ProfileOwnershipOutcome {
        guard let cloudResult = input.cloudResult else {
            return .requireCloudLookup
        }

        switch cloudResult {
        case .found:
            return .restoreCloudProfile
        case .missing:
            return .showMissingCloudProfile
        case .failed:
            return .showCloudFetchFailed
        }
    }

    // MARK: - Local profile present

    private static func resolveWithLocalProfile(
        _ input: ProfileOwnershipInput
    ) -> ProfileOwnershipOutcome {
        if let localOwnerUID = input.localOwnerUID {
            return resolveOwnedLocalProfile(
                localOwnerUID: localOwnerUID,
                signedInUID: input.signedInUID
            )
        }

        return resolveUnownedLocalProfile(input)
    }

    private static func resolveOwnedLocalProfile(
        localOwnerUID: String,
        signedInUID: String
    ) -> ProfileOwnershipOutcome {
        if localOwnerUID == signedInUID {
            return .useLocalProfile
        }
        return .showAccountMismatch
    }

    private static func resolveUnownedLocalProfile(
        _ input: ProfileOwnershipInput
    ) -> ProfileOwnershipOutcome {
        guard let cloudResult = input.cloudResult else {
            return .requireCloudLookup
        }

        switch cloudResult {
        case .found:
            return .showProfileConflict
        case .failed:
            return .showCloudFetchFailed
        case .missing:
            return resolveUnownedLocalWithMissingCloud(input)
        }
    }

    private static func resolveUnownedLocalWithMissingCloud(
        _ input: ProfileOwnershipInput
    ) -> ProfileOwnershipOutcome {
        switch input.signInContext {
        case .onboardingCompletion:
            return .uploadLocalProfile
        case .accountSwitch, .existingUserEntry:
            return .showAccountMismatch
        case .normalLaunch, .returningUser:
            if input.isSyncedForCurrentUID {
                return .useLocalProfile
            }
            return .uploadLocalProfile
        }
    }
}
