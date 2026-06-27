//
//  AuthGateRoutingPolicyTests.swift
//  Fitness CoachTests
//
//  AuthGateView routing overlay and onboarding retention policy.
//

import XCTest
@testable import Fitness_Coach

final class AuthGateRoutingPolicyTests: XCTestCase {

    func testPrefersActiveOnboardingSessionOverSignInWhenLocalProfileExists() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .signIn,
                isV2Enabled: true,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .localOnboarding
        )
    }

    func testDoesNotPreferOnboardingWhenV2Disabled() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .signIn,
                isV2Enabled: false,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .signIn
        )
    }

    func testDoesNotPreferOnboardingWhenSignedIn() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .onboarding,
                isV2Enabled: true,
                isSignedIn: true,
                hasActiveOnboardingSession: true
            ),
            .onboarding
        )
    }

    func testExistingAccountHandoffSignsOutWhenSessionAlreadyActive() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldSignOutBeforeExistingAccountSignIn(isSignedIn: true)
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldSignOutBeforeExistingAccountSignIn(isSignedIn: false)
        )
    }

    func testReloadSignedInCloudProfileWhenPreAuthOnboardingIsActive() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .onboarding,
                hasLocalProfile: false
            )
        )
    }

    func testSkipsReloadWhenMissingCloudProfileInterstitialIsShowing() {
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .missingCloudProfile,
                hasLocalProfile: false
            )
        )
    }

    func testPreAuthInitializingWhenModelNotReady() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .localOnboardingInitializing,
                isV2Enabled: true,
                isSignedIn: false,
                hasActiveOnboardingSession: false
            ),
            .localOnboardingInitializing
        )
    }

    func testRetainsOnboardingModelWhenDraftExistsWithoutLocalProfile() {
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            )
        )
    }

    func testClearsOnboardingModelAfterSignOutWhenProfileSaved() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: true,
                hasPersistedOnboardingDraft: true
            )
        )
    }

    func testClearsOnboardingModelAfterSignOutWithoutDraft() {
        XCTAssertTrue(
            AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: true,
                isSignedIn: false
            )
        )
    }
}
