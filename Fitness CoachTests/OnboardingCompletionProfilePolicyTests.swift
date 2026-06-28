//
//  OnboardingCompletionProfilePolicyTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class OnboardingCompletionProfilePolicyTests: XCTestCase {

    func testDeferLocalProfileShortCircuitOnlyDuringPendingOnboardingCompletion() {
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
        XCTAssertFalse(
            AuthGateRoutingPolicy.shouldDeferLocalProfileShortCircuit(
                pendingOnboardingCompletion: true,
                hasLocalProfile: false
            )
        )
    }

    func testOnboardingConflictRoutesToDedicatedShell() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .onboardingCloudProfileConflict,
                isOnboardingModelReady: true,
            ),
            .onboardingCloudProfileConflict
        )
    }

    func testOnboardingCloudCheckFailedRoutesToDedicatedShell() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .onboardingCloudCheckFailed,
                isOnboardingModelReady: true,
            ),
            .onboardingCloudCheckFailed
        )
    }
}
