//
//  AuthGateRoutingPolicyTests.swift
//  Fitness CoachTests
//
//  AuthGateView routing overlay and onboarding retention policy.
//

import XCTest
@testable import Fitness_Coach

final class AuthGateRoutingPolicyTests: XCTestCase {

    func testPrefersActiveOnboardingSessionOverWelcomeWhenSessionActive() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .welcome,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .onboardingStart
        )
    }

    func testDoesNotPreferOnboardingWhenSignedIn() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .onboarding,
                isSignedIn: true,
                hasActiveOnboardingSession: true
            ),
            .onboarding
        )
    }

    func testShouldClearOnboardingModelOnSignOutWhenSignedInSessionEnds() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: true,
                hasPersistedOnboardingDraft: false
            )
        )
    }

    func testShouldClearOnboardingModelOnSignOutEvenWhenDraftExists() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            )
        )
    }

    func testShouldDeferLocalProfileShortCircuitWhilePendingCompletion() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldDeferLocalProfileShortCircuit(
                pendingOnboardingCompletion: true,
                hasLocalProfile: true
            )
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldDeferLocalProfileShortCircuit(
                pendingOnboardingCompletion: false,
                hasLocalProfile: true
            )
        )
    }

    func testDraftDoesNotOverrideExistingUserSignIn() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .existingUserSignIn,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .existingUserSignIn
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldPreferActiveOnboardingSession(
                isSignedIn: false,
                hasActiveOnboardingSession: true,
                baseRoute: .existingUserSignIn
            )
        )
    }

    func testActiveOnboardingSessionOverridesWelcomeButNotExistingUserSignIn() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .welcome,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .onboardingStart
        )
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldPreferActiveOnboardingSession(
                isSignedIn: false,
                hasActiveOnboardingSession: true,
                baseRoute: .welcome
            )
        )
    }

    // MARK: - Silent auth restore (launch)

    func testShouldReloadCloudProfileOnFreshSignInWithoutLocalProfile() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: true,
                rootState: .loading,
                hasLocalProfile: false
            )
        )
    }

    func testShouldReloadCloudProfileOnSilentLaunchWhileLoading() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .loading,
                hasLocalProfile: false
            )
        )
    }

    func testShouldNotReloadCloudProfileWhenLocalProfileExists() {
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .loading,
                hasLocalProfile: true
            )
        )
    }

    func testShouldNotReloadCloudProfileWhenRootAlreadyTerminal() {
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .main,
                hasLocalProfile: false
            )
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .missingCloudProfile,
                hasLocalProfile: false
            )
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldReloadSignedInCloudProfile(
                isFreshSignIn: false,
                rootState: .existingUserProfileLookupFailed,
                hasLocalProfile: false
            )
        )
    }
}
