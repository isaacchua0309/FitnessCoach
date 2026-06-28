//
//  PublicEntryRouteTests.swift
//  Fitness CoachTests
//
//  Forma — Public entry route transitions for logged-out users.
//

import XCTest
@testable import Fitness_Coach

@MainActor
final class PublicEntryRouteTests: XCTestCase {

    // MARK: - Logged out → welcome

    func testLoggedOutRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .signedOut),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                localProfileAwaitingSignIn: false
            ),
            .welcome
        )
    }

    // MARK: - Welcome → onboarding

    func testWelcomeCreatePlanRoutesToOnboardingStart() {
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
    }

    // MARK: - Welcome → existing-user sign-in

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
    }

    // MARK: - Signed-in outcomes

    func testSuccessfulSignInWithProfileRoutesToMain() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "returning-user"),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .main),
            .main
        )
    }

    func testSuccessfulSignInWithoutProfileRoutesToNoExistingProfileFound() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "new-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .missingCloudProfile),
            .missingCloudProfile
        )
    }

    // MARK: - Resume without welcome

    func testSavePlanHandoffBypassesWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                localProfileAwaitingSignIn: true
            ),
            .onboardingStart
        )
    }

    func testPersistedDraftBypassesWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            ),
            .onboardingStart
        )
    }

    // MARK: - Existing-user sign-in intent

    func testExistingUserEntryDoesNotUploadUnownedLocalProfile() {
        let outcome = ProfileOwnershipResolver.resolve(
            AuthProfileRouteSafetyTestSupport.ownershipInput(
                localOwnerUID: nil,
                cloudResult: .missing,
                signInContext: .existingUserEntry
            )
        )
        XCTAssertEqual(outcome, ProfileOwnershipOutcome.showAccountMismatch)
    }

    func testExistingUserSignInUsesDedicatedReconcileContext() {
        let context = ProfileBootstrapCoordinator.signInContext(
            for: SignedInProfileReconcileInput(
                uid: "user-1",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true,
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: nil
            )
        )
        XCTAssertEqual(context, .existingUserEntry)
    }

    func testOnboardingCompletionSignInStillUsesOnboardingContext() {
        let context = ProfileBootstrapCoordinator.signInContext(
            for: SignedInProfileReconcileInput(
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
        XCTAssertEqual(context, .onboardingCompletion)
    }
}
