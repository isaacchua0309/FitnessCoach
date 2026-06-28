//
//  AuthProfileRouteSafetyTestSupport.swift
//  Fitness CoachTests
//
//  Lightweight harness for auth/profile route safety tests (no AppContainer / Firebase).
//

import Foundation
@testable import Fitness_Coach

@MainActor
enum AuthProfileRouteSafetyTestSupport {

    struct ServiceHarness {
        let profileService: UserProfileService
        let cloudStore: MockCloudUserProfileStore
        let syncStore: ProfileCloudSyncStore
        let bootstrapService: ProfileBootstrapService
        let coordinator: ProfileBootstrapCoordinatorService
    }

    static func makeServiceHarness() throws -> ServiceHarness {
        let harness = try ProfileBootstrapTestSupport.makeHarness()
        return ServiceHarness(
            profileService: harness.profileService,
            cloudStore: harness.cloudStore,
            syncStore: harness.syncStore,
            bootstrapService: harness.bootstrapService,
            coordinator: harness.makeCoordinator()
        )
    }

    static func reconcileInput(
        uid: String = "signed-in-user",
        pendingOnboardingCompletion: Bool = false,
        pendingExistingUserSignIn: Bool = false,
        hasLocalProfile: Bool = true,
        localOwnerUID: String? = nil,
        isFreshSignIn: Bool = false,
        rootState: RootViewState = .main,
        isSyncedForCurrentUID: Bool = false,
        cloudResult: CloudProfileLookupResult? = nil
    ) -> SignedInProfileReconcileInput {
        SignedInProfileReconcileInput(
            uid: uid,
            pendingOnboardingCompletion: pendingOnboardingCompletion,
            pendingExistingUserSignIn: pendingExistingUserSignIn,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            isFreshSignIn: isFreshSignIn,
            rootState: rootState,
            isSyncedForCurrentUID: isSyncedForCurrentUID,
            cloudResult: cloudResult
        )
    }

    static func ownershipInput(
        signedInUID: String = "signed-in-user",
        hasLocalProfile: Bool = true,
        localOwnerUID: String? = nil,
        pendingOnboardingCompletion: Bool = false,
        cloudResult: CloudProfileLookupResult? = nil,
        signInContext: SignInContext = .returningUser,
        isSyncedForCurrentUID: Bool = false
    ) -> ProfileOwnershipInput {
        ProfileOwnershipInput(
            signedInUID: signedInUID,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            hasLocalProfilePendingOnboardingCompletion: pendingOnboardingCompletion,
            cloudResult: cloudResult,
            signInContext: signInContext,
            isSyncedForCurrentUID: isSyncedForCurrentUID
        )
    }
}
