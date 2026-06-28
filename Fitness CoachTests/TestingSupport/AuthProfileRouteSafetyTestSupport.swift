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
        let base = try DailyLogServiceTestSupport.makeHarness()
        let cloudStore = MockCloudUserProfileStore()
        let syncStore = ProfileCloudSyncStore(
            userDefaults: UserDefaults(suiteName: "AuthProfileRouteSafety.\(UUID().uuidString)")!
        )
        let bootstrapService = ProfileBootstrapService(
            userProfileService: base.profileService,
            cloudStore: cloudStore,
            cloudSyncStore: syncStore
        )
        let coordinator = ProfileBootstrapCoordinatorService(
            profileBootstrapService: bootstrapService,
            cloudSyncStore: syncStore
        )
        return ServiceHarness(
            profileService: base.profileService,
            cloudStore: cloudStore,
            syncStore: syncStore,
            bootstrapService: bootstrapService,
            coordinator: coordinator
        )
    }

    static func reconcileInput(
        uid: String = "signed-in-user",
        pendingOnboardingCompletion: Bool = false,
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
