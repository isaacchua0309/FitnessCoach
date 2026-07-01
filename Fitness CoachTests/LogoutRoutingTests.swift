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

    func testFreshInstallRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .welcome
        )
        XCTAssertEqual(
            AuthLogoutPolicy.signedOutPhase(
                publicEntryDestination: .welcome,
                hasPersistedOnboardingDraft: false,
                hasLocalProfile: false,
                localProfileAwaitingSignIn: false,
                pendingOnboardingCompletion: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .unauthenticatedPublicEntry
        )
    }

    func testNewUserCreatePlanRoutesToOnboardingStart() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart,
                suppressAutomaticPublicEntryResume: false
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            AuthLogoutPolicy.signedOutPhase(
                publicEntryDestination: .onboardingStart,
                hasPersistedOnboardingDraft: false,
                hasLocalProfile: false,
                localProfileAwaitingSignIn: false,
                pendingOnboardingCompletion: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .explicitPreAuthOnboarding
        )
    }

    func testExistingUserLoginWithCompletedProfileRoutesToMain() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "existing-user"),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
    }

    func testExistingUserLoginWithMissingProfileRoutesToMissingCloudInterstitial() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "existing-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "existing-user"),
                rootState: .onboarding,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
    }

    func testLoggedInUserLogoutRoutesToWelcomeNotOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .main,
                isOnboardingModelReady: true,
                hasLocalProfile: true,
                publicEntryDestination: .welcome,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
        XCTAssertEqual(
            AuthGateRoutingPolicy.effectiveRoute(
                baseRoute: .welcome,
                isSignedIn: false,
                hasActiveOnboardingSession: true,
                suppressAutomaticPublicEntryResume: true
            ),
            .welcome
        )
    }

    func testForceQuitAfterLogoutRelaunchRoutesToWelcome() {
        let defaults = UserDefaults(suiteName: "LogoutRoutingTests.relaunch.\(UUID().uuidString)")!
        let sessionStore = PublicEntrySessionStore(userDefaults: defaults)
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: sessionStore)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: sessionStore.suppressAutomaticPublicEntryResume
            ),
            .welcome
        )
        XCTAssertNil(
            AuthLogoutPolicy.coldLaunchPublicEntryDestination(
                hasPersistedOnboardingDraft: true,
                hasLocalProfile: false,
                suppressAutomaticPublicEntryResume: true
            )
        )
    }

    func testStaleIncompleteDraftWhileSignedOutAfterLogoutRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: false,
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

    func testColdLaunchDraftResumeStillBypassesWelcomeWhenNotAfterLogout() {
        XCTAssertEqual(
            AuthLogoutPolicy.coldLaunchPublicEntryDestination(
                hasPersistedOnboardingDraft: true,
                hasLocalProfile: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            AuthLogoutPolicy.signedOutPhase(
                publicEntryDestination: .welcome,
                hasPersistedOnboardingDraft: true,
                hasLocalProfile: false,
                localProfileAwaitingSignIn: false,
                pendingOnboardingCompletion: false,
                suppressAutomaticPublicEntryResume: false
            ),
            .resumingPreAuthOnboarding
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

    func testPrepareForSignOutSetsSuppressBeforeAuthStateChanges() {
        let defaults = UserDefaults(suiteName: "LogoutRoutingTests.prepare.\(UUID().uuidString)")!
        let sessionStore = PublicEntrySessionStore(userDefaults: defaults)

        XCTAssertFalse(sessionStore.suppressAutomaticPublicEntryResume)
        AuthLogoutPolicy.prepareForSignOut(
            sessionStore: sessionStore,
            source: "test",
            wasSignedIn: true,
            hasLocalProfile: true,
            hasPersistedOnboardingDraft: true,
            publicEntryDestination: .welcome
        )
        XCTAssertTrue(sessionStore.suppressAutomaticPublicEntryResume)
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

@MainActor
final class RootModelSignedOutResetTests: XCTestCase {

    func testResetForSignedOutSessionUsesNeutralLoadingState() {
        let container = try! AppContainer(inMemory: true)
        let rootModel = container.makeRootModel()
        rootModel.resolveLocalProfile()
        XCTAssertEqual(rootModel.state, .onboarding)

        rootModel.resetForSignedOutSession()

        XCTAssertEqual(rootModel.state, .loading)
        XCTAssertEqual(rootModel.bootstrapPhase, .idle)
    }
}

@MainActor
final class AuthGateCoordinatorLogoutTests: XCTestCase {

    func testSignedOutTransitionResetsAuthenticatedShellState() throws {
        let container = try AppContainer(inMemory: true)
        let coordinator = AuthGateCoordinator(container: container)
        coordinator.rootModel.didCompleteOnboarding()
        coordinator.awaitingCloudSync = true
        let priorSessionID = coordinator.signedInSessionID

        coordinator.handleSignedOutTransition(
            from: .signedIn(uid: "signed-in-user"),
            to: .signedOut,
            wasSignedIn: true
        )

        XCTAssertEqual(coordinator.publicEntryDestination, .welcome)
        XCTAssertEqual(coordinator.rootModel.state, .loading)
        XCTAssertNil(coordinator.onboardingModel)
        XCTAssertFalse(coordinator.awaitingCloudSync)
        XCTAssertNotEqual(coordinator.signedInSessionID, priorSessionID)
        XCTAssertTrue(container.publicEntrySessionStore.suppressAutomaticPublicEntryResume)
    }

    func testEffectiveRouteAfterSignedOutTransitionIsWelcome() throws {
        let container = try AppContainer(inMemory: true)
        let coordinator = AuthGateCoordinator(container: container)
        coordinator.rootModel.didCompleteOnboarding()
        container.authManager.startListening()
        container.authManager.signOut()

        coordinator.handleSignedOutTransition(
            from: .signedIn(uid: "signed-in-user"),
            to: .signedOut,
            wasSignedIn: true
        )

        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
        XCTAssertNotEqual(coordinator.effectiveRoute, .main)
    }

    func testColdLaunchAfterLogoutWithDraftAndLocalProfileRoutesToWelcome() throws {
        let sessionDefaults = UserDefaults(suiteName: "LogoutRoutingTests.cold.\(UUID().uuidString)")!
        let sessionStore = PublicEntrySessionStore(userDefaults: sessionDefaults)
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: sessionStore)

        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .main,
                hasLocalProfile: true,
                publicEntryDestination: .welcome,
                hasPersistedOnboardingDraft: true,
                suppressAutomaticPublicEntryResume: sessionStore.suppressAutomaticPublicEntryResume
            ),
            .welcome
        )
    }

    @MainActor
    func testBootstrapOnboardingSkippedAfterExplicitSignOutUntilCreateMyPlan() throws {
        let container = try AppContainer(inMemory: true)
        let coordinator = AuthGateCoordinator(container: container)
        AuthLogoutPolicy.applyExplicitSignOut(sessionStore: container.publicEntrySessionStore)
        coordinator.publicEntryDestination = .welcome
        container.authManager.startListening()
        container.authManager.signOut()

        coordinator.bootstrapOnboardingIfNeeded()

        XCTAssertNil(coordinator.onboardingModel)
        XCTAssertEqual(coordinator.effectiveRoute, .welcome)
    }
}
