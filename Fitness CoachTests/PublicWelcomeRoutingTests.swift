//
//  PublicWelcomeRoutingTests.swift
//  Fitness CoachTests
//
//  Forma — Public welcome entry routing for logged-out users.
//

import XCTest
@testable import Fitness_Coach

final class PublicWelcomeRoutingTests: XCTestCase {

    func testLoggedOutStartsAtWelcome() {
        XCTAssertEqual(AppRouteResolver.resolve(authState: .signedOut), .welcome)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
        XCTAssertEqual(AppRouteResolver.resolve(authState: .unknown), .launchLoading)
    }

    func testCreatePlanStartsOnboarding() {
        XCTAssertEqual(
            WelcomeOnboardingHandoffPolicy.createPlanDestination,
            .onboardingStart
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStartInitializing
        )
        XCTAssertEqual(WelcomeOnboardingHandoffPolicy.canonicalFirstStep, .introProof)
        XCTAssertEqual(
            OnboardingEntry.initialStep(for: WelcomeOnboardingHandoffPolicy.preAuthEntry),
            .introProof
        )
    }

    func testCreatePlanDoesNotRouteToExistingUserSignIn() {
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: WelcomeOnboardingHandoffPolicy.createPlanDestination
            ),
            .existingUserSignIn
        )
    }

    func testExplicitWelcomeDoesNotBypassWhenSignOutSuppressesResume() {
        XCTAssertFalse(
            PublicEntryRouteResolver.shouldBypassWelcome(
                PublicEntryRouteResolver.Input(
                    destination: .welcome,
                    isOnboardingModelReady: true,
                    localProfileAwaitingSignIn: false,
                    hasPersistedOnboardingDraft: true,
                    hasLocalProfile: false,
                    pendingOnboardingCompletion: false,
                    signedOutWithProfilePolicy: .requireSignIn,
                    suppressAutomaticPublicEntryResume: true
                )
            )
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }
}
