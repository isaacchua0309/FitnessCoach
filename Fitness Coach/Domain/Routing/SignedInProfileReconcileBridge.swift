//
//  SignedInProfileReconcileBridge.swift
//  Fitness Coach
//
//  Forma — Maps ownership resolver outcomes to signed-in reconcile decisions.
//

import Foundation

extension SignedInProfileReconcileInput {

    var ownershipInput: ProfileOwnershipInput {
        ProfileOwnershipInput(
            signedInUID: uid,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            hasLocalProfilePendingOnboardingCompletion: pendingOnboardingCompletion,
            cloudResult: cloudResult,
            signInContext: ProfileBootstrapCoordinator.signInContext(for: self),
            isSyncedForCurrentUID: isSyncedForCurrentUID
        )
    }
}

extension ProfileBootstrapCoordinator {

    static func mapOwnershipOutcome(
        _ outcome: ProfileOwnershipOutcome,
        input: SignedInProfileReconcileInput
    ) -> SignedInProfileReconcileDecision {
        switch outcome {
        case .useLocalProfile:
            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": input.uid, "route": "main", "reason": "ownerMatches"]
            )
            return .routeToMain

        case .restoreCloudProfile:
            return .loadCloudProfile(uid: input.uid)

        case .showMissingCloudProfile:
            return .presentMissingCloudProfile(uid: input.uid)

        case .showCloudFetchFailed:
            return .showCloudFetchFailed(uid: input.uid)

        case .showAccountMismatch:
            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": input.uid, "route": "accountMismatch"]
            )
            return .showAccountMismatch(uid: input.uid)

        case .showProfileConflict:
            return .showProfileConflict(uid: input.uid)

        case .uploadLocalProfile:
            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": input.uid, "route": "uploadAfterLookup"]
            )
            return .syncLocalProfileToCloud(uid: input.uid)

        case .requireCloudLookup:
            if input.pendingOnboardingCompletion {
                return .resolveOnboardingCompletion(uid: input.uid)
            }

            if !input.hasLocalProfile {
                let shouldLoadCloudProfile = AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                    isFreshSignIn: input.isFreshSignIn,
                    rootState: input.rootState,
                    hasLocalProfile: input.hasLocalProfile
                )
                return shouldLoadCloudProfile
                    ? .loadCloudProfile(uid: input.uid)
                    : .skip
            }

            ProfileBootstrapDebugLogger.event(
                "local_profile_found",
                fields: ["uid": input.uid, "route": "ownershipCloudLookupRequired"]
            )
            return .requireOwnershipCloudLookup(uid: input.uid)
        }
    }
}
