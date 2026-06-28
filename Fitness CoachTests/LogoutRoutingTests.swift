//
//  LogoutRoutingTests.swift
//  Fitness CoachTests
//
//  Forma — Sign-out routes through public welcome entry.
//

import XCTest
@testable import Fitness_Coach

final class LogoutRoutingTests: XCTestCase {

    func testLogoutReturnsToWelcome() {
        XCTAssertEqual(
            AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
                returnToExistingUserSignIn: false,
                hasExistingUserSignInError: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
                hasLocalProfile: false,
                publicEntryDestination: .welcome,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }

    func testLogoutAfterProfileExistsRoutesToWelcomeNotMain() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .main,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .main,
                hasLocalProfile: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .main
        )
    }

    func testLogoutRetainedLocalProfileHiddenUntilSignIn() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .requireSignIn,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }

    func testLogoutWithDraftRoutesToWelcomeUntilCreateMyPlan() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
        XCTAssertFalse(
            WelcomeOnboardingHandoffPolicy.shouldBypassWelcome(
                PublicEntryRouteResolver.Input(
                    destination: .welcome,
                    isOnboardingModelReady: false,
                    localProfileAwaitingSignIn: false,
                    hasPersistedOnboardingDraft: true,
                    hasLocalProfile: false,
                    pendingOnboardingCompletion: false,
                    signedOutWithProfilePolicy: .requireSignIn,
                    suppressAutomaticPublicEntryResume: true
                )
            )
        )
    }

    func testLogoutClearsOnboardingModelEvenWhenDraftExists() {
        XCTAssertTrue(
            AuthGateRoutingPolicy.shouldClearOnboardingModelOnSignOut(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            )
        )
    }

    func testUseAnotherAccountAfterLogoutRoutesToExistingUserSignIn() {
        XCTAssertEqual(
            AuthLogoutPolicy.publicEntryDestinationAfterSignOut(
                returnToExistingUserSignIn: true,
                hasExistingUserSignInError: false
            ),
            .existingUserSignIn
        )
    }
}

final class LogoutSessionStoreTests: XCTestCase {

    func testExplicitSignOutMarksSuppressResumeUntilCreateMyPlan() {
        let defaults = UserDefaults(suiteName: "LogoutRoutingTests.\(UUID().uuidString)")!
        let store = PublicEntrySessionStore(userDefaults: defaults)

        XCTAssertFalse(store.suppressAutomaticPublicEntryResume)
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: store)
        XCTAssertTrue(store.suppressAutomaticPublicEntryResume)

        store.clearExplicitSignOut()
        XCTAssertFalse(store.suppressAutomaticPublicEntryResume)
    }

    func testUserInitiatedLogoutSetsPendingEntrySource() {
        let defaults = UserDefaults(suiteName: "LogoutRoutingTests.\(UUID().uuidString)")!
        let store = PublicEntrySessionStore(userDefaults: defaults)

        store.markUserInitiatedLogout()
        XCTAssertEqual(store.pendingEntrySource, .logout)
        XCTAssertEqual(store.consumePendingEntrySource(), .logout)
        XCTAssertNil(store.pendingEntrySource)
    }

    func testSignBackInRestoresOwnedLocalProfileAfterLogoutHygiene() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "signed-in-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false,
                hasLocalProfile: true,
                localOwnerUID: "signed-in-user",
                isFreshSignIn: true,
                rootState: .main,
                isSyncedForCurrentUID: false
            )
        )

        XCTAssertEqual(decision, .routeToMain)
    }
}
