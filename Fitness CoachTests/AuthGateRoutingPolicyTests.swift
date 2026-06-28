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

    func testExistingAccountHandoffSignsOutWhenSessionAlreadyActive() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldSignOutBeforeExistingAccountSignIn(isSignedIn: true)
        )
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldSignOutBeforeExistingAccountSignIn(isSignedIn: false)
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

    func testShouldNotClearOnboardingModelWhenDraftExistsWithoutProfile() {
        XCTAssertFalse(
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

    func testPrefersActiveOnboardingSessionOverExistingUserSignInWhenDraftExists() {
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .existingUserSignIn,
                isSignedIn: false,
                hasActiveOnboardingSession: true
            ),
            .onboardingStart
        )
    }
}
