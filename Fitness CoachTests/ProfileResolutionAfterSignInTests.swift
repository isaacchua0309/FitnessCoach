//
//  ProfileResolutionAfterSignInTests.swift
//  Fitness CoachTests
//
//  Forma — Post-sign-in profile resolution and shell routing outcomes.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class ProfileResolutionAfterSignInTests: XCTestCase {

    private let uid = "remote-user"
    private let referenceDate = ProfileTestFixtures.referenceDate

    // MARK: - Existing profile → main

    func testSignInWithExistingCloudProfileEntersApp() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.storedDocument = ProfileTestFixtures.cloudDocument()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.profileFound(.cloudRestored)))
        XCTAssertNotNil(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    func testSignInWithOwnedLocalProfileEntersAppWithoutCloudFetch() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        try harness.profileService.createProfile(ProfileTestFixtures.sampleDraft)
        _ = try harness.profileService.assignOwnerUID(uid)

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.profileFound(.localOwned)))
        XCTAssertEqual(harness.cloudStore.fetchCallCount, 0)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    // MARK: - No profile → interstitial

    func testSignInWithNoProfileShowsNoProfileScreen() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: "new-user",
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.noProfileFound))
        XCTAssertNil(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .missingCloudProfile,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
    }

    // MARK: - Network failure → retry, not new user

    func testNetworkFailureDoesNotClassifyUserAsNew() async throws {
        let harness = try AuthProfileRouteSafetyTestSupport.makeServiceHarness()
        harness.cloudStore.fetchError = NSError(domain: "ProfileResolutionAfterSignInTests", code: 1)

        let outcome = await harness.coordinator.resolveExistingUserSignIn(
            uid: uid,
            isFreshSignIn: true,
            rootState: .loading
        )

        XCTAssertEqual(outcome, .resolution(.lookupFailed))
        XCTAssertNil(try harness.profileService.getCurrentProfile())
        XCTAssertEqual(
            ExistingUserSignInResolutionMapper.fromReconcileDecision(
                .showCloudFetchFailed(uid: uid)
            ),
            .lookupFailed
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .existingUserProfileLookupFailed
            ),
            .existingUserProfileLookupFailed
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .existingUserProfileLookupFailed
            ),
            .noExistingProfileFound
        )
    }

    func testBootstrapFetchFailureRoutesToProfileErrorNotNoProfile() {
        let message = FormaProductCopy.Onboarding.V2.BootstrapError.body
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .error(message)
            ),
            .profileError(message)
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: uid),
                rootState: .error(message)
            ),
            .noExistingProfileFound
        )
    }
}
