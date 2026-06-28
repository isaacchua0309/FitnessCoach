//
//  ExistingUserSignInResolutionTests.swift
//  Fitness CoachTests
//
//  Forma — Returning-member profile resolution outcomes and service orchestration.
//

import XCTest
@testable import Fitness_Coach

final class ExistingUserSignInResolutionMapperTests: XCTestCase {

    func testMapsLocalOwnedDecisionToProfileFound() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(.routeToMain),
            .profileFound(.localOwned)
        )
    }

    func testMapsMissingCloudDecisionToNoProfileFound() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .presentMissingCloudProfile(uid: "user-1")
            ),
            .noProfileFound
        )
    }

    func testMapsCloudFetchFailureToLookupFailed() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .showCloudFetchFailed(uid: "user-1")
            ),
            .lookupFailed
        )
    }

    func testMapsProfileConflictDecisionToConflict() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .showProfileConflict(uid: "user-1")
            ),
            .conflict
        )
    }

    func testDeferredDecisionsReturnNil() {
        XCTAssertNil(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .loadCloudProfile(uid: "user-1")
            )
        )
        XCTAssertNil(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .resolveOnboardingCompletion(uid: "user-1")
            )
        )
    }

    func testBootstrapMainMapsToCloudRestored() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromBootstrapResult(.main),
            .profileFound(.cloudRestored)
        )
    }

    func testBootstrapMissingMapsToNoProfileFound() {
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromBootstrapResult(.missingCloudProfile),
            .noProfileFound
        )
    }
}

final class OnboardingDraftPolicyTests: XCTestCase {

    func testClearsStaleDraftOnlyWhenDraftExists() {
        XCTAssertTrue(
            OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(hasPersistedDraft: true)
        )
        XCTAssertFalse(
            OnboardingDraftPolicy.shouldClearStaleDraftAfterExistingUserRestore(hasPersistedDraft: false)
        )
    }
}

@MainActor
final class ExistingUserSignInResolutionServiceTests: XCTestCase {

    func testCloudProfileFoundRestoresLocally() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "remote-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.profileFound(.cloudRestored)))
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(try harness.profileService.getCurrentProfile()?.ownerUID, "remote-user")
    }

    func testLocalOwnedProfileRoutesToMainWithoutCloudFetch() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        _ = try harness.profileService.assignOwnerUID("remote-user")

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "remote-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.profileFound(.localOwned)))
        XCTAssertEqual(harness.cloudStore.fetchCallCount, 0)
    }

    func testNoLocalOrCloudProfileReturnsNoProfileFound() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "new-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.noProfileFound))
        XCTAssertNil(try harness.profileService.getCurrentProfile())
    }

    func testNetworkFailureReturnsLookupFailedWithoutCreatingProfile() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.fetchError = NSError(domain: "ExistingUserSignInTests", code: 1)

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "remote-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.lookupFailed))
        XCTAssertNil(try harness.profileService.getCurrentProfile())
    }

    func testUnownedLocalWithCloudProfileReturnsConflict() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "remote-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.conflict))
    }

    func testUnownedLocalWithoutCloudReturnsAccountMismatch() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "remote-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .accountMismatch)
    }
}

final class ExistingUserSignInResolutionRoutingTests: XCTestCase {

    func testLookupFailedRoutesToDedicatedRetryScreen() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .existingUserProfileLookupFailed
            ),
            .existingUserProfileLookupFailed
        )
    }

    func testLookupFailedDoesNotRouteToOnboardingOrNoProfileFound() {
        let route = AppRouteResolver.resolve(
            authState: .signedIn(uid: "user-1"),
            rootState: .existingUserProfileLookupFailed,
            isOnboardingModelReady: true
        )
        XCTAssertNotEqual(route, .onboarding)
        XCTAssertNotEqual(route, .noExistingProfileFound)
        XCTAssertNotEqual(route, .onboardingCloudCheckFailed)
    }

    func testOnboardingCompletionDecisionStillDefersToCompletionFlow() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "user-1",
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: nil
            )
        )

        XCTAssertEqual(decision, .resolveOnboardingCompletion(uid: "user-1"))
    }
}
