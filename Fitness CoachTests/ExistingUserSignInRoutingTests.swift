//
//  ExistingUserSignInRoutingTests.swift
//  Fitness CoachTests
//
//  Forma — Returning-member sign-in shell routing.
//

import XCTest
@testable import Fitness_Coach

final class ExistingUserSignInRoutingTests: XCTestCase {

    func testWelcomeSignInRoutesToExistingUserSignIn() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                publicEntryDestination: .existingUserSignIn
            ),
            .existingUserSignIn
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signingIn,
                publicEntryDestination: .existingUserSignIn
            ),
            .existingUserSignIn
        )
        XCTAssertEqual(
            PublicEntryRouteResolver.resolveSignedOutShell(
                PublicEntryRouteResolver.Input(
                    destination: .existingUserSignIn,
                    isOnboardingModelReady: false,
                    localProfileAwaitingSignIn: false,
                    hasPersistedOnboardingDraft: false,
                    hasLocalProfile: false,
                    pendingOnboardingCompletion: false,
                    signedOutWithProfilePolicy: .requireSignIn
                )
            ),
            .existingUserSignIn
        )
    }

    func testDraftDoesNotOverrideExistingUserSignIn() {
        let input = PublicEntryRouteResolver.Input(
            destination: .existingUserSignIn,
            isOnboardingModelReady: true,
            localProfileAwaitingSignIn: false,
            hasPersistedOnboardingDraft: true,
            hasLocalProfile: false,
            pendingOnboardingCompletion: false,
            signedOutWithProfilePolicy: .requireSignIn
        )

        XCTAssertEqual(PublicEntryRouteResolver.resolveSignedOutShell(input), .existingUserSignIn)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .existingUserSignIn,
                hasPersistedOnboardingDraft: true
            ),
            .existingUserSignIn
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .existingUserSignIn,
                hasPersistedOnboardingDraft: true
            ),
            .onboardingStart
        )
    }

    func testExistingUserSignInWinsOverActiveOnboardingSessionOverlay() {
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
}
