//
//  OnboardingShellRouteResolverTests.swift
//  Fitness CoachTests
//
//  Forma — Canonical public-entry and onboarding shell routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingShellRouteResolverTests: XCTestCase {

    private let signedInUser = AuthState.signedIn(uid: "google-user")

    // MARK: - Unknown auth

    func testUnknownAuthRoutesToLaunchLoading() {
        XCTAssertEqual(
            resolve(authState: .unknown, hasLocalProfile: false),
            .launchLoading
        )
        XCTAssertEqual(
            resolve(authState: .unknown, hasLocalProfile: true),
            .launchLoading
        )
    }

    // MARK: - Signed out, no profile

    func testSignedOutNoProfileRoutesToWelcome() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true
            ),
            .welcome
        )
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: false
            ),
            .welcome
        )
        XCTAssertEqual(
            resolve(
                authState: .signingIn,
                hasLocalProfile: false,
                isOnboardingModelReady: true
            ),
            .welcome
        )
    }

    func testSignedOutCreatePlanRoutesToOnboardingStart() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: false,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStartInitializing
        )
    }

    // MARK: - Signed out, has profile

    func testSignedOutHasProfileRoutesToWelcomeByDefault() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                isOnboardingModelReady: false,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .welcome
        )
        XCTAssertEqual(
            resolve(
                authState: .failed("Sign-in failed"),
                hasLocalProfile: true,
                isOnboardingModelReady: true,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .welcome
        )
    }

    // MARK: - Signed in, no profile

    func testSignedInNoCloudProfileRoutesToNoExistingProfileFound() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
    }

    func testSignedInOnboardingCloudProfileConflictRoutesToConflictShell() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: true,
                rootState: .onboardingCloudProfileConflict
            ),
            .onboardingCloudProfileConflict
        )
    }

    func testSignedInOnboardingCloudCheckFailedRoutesToRetryShell() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: true,
                rootState: .onboardingCloudCheckFailed
            ),
            .onboardingCloudCheckFailed
        )
    }

    func testSignedInNoProfileRoutesToOnboarding() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .onboarding,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .onboarding,
                isOnboardingModelReady: false
            ),
            .onboardingInitializing
        )
    }

    func testSignedInWhileProfileLoadingRoutesToSignedInProfileLoading() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .loading
            ),
            .signedInProfileLoading
        )
    }

    // MARK: - Signed in, has profile

    func testSignedInHasProfileRoutesToMain() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: true,
                rootState: .main
            ),
            .main
        )
    }

    func testSignedInHasProfileAwaitingCloudSyncRoutesToMainAwaitingCloudSync() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: true,
                rootState: .main,
                awaitingCloudSync: true
            ),
            .mainAwaitingCloudSync
        )
    }

    func testSignedInProfileErrorSurfacesMessage() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .error("Cloud restore failed.")
            ),
            .profileError("Cloud restore failed.")
        )
    }

    // MARK: - G1 routing matrix

    func testG1RoutingMatrixCoversSignedOutAndSignedInPaths() {
        // auth unknown → loading
        XCTAssertEqual(
            resolve(authState: .unknown, hasLocalProfile: false),
            .launchLoading
        )

        // signed out / no profile → welcome
        XCTAssertEqual(
            resolve(authState: .signedOut, hasLocalProfile: false, isOnboardingModelReady: true),
            .welcome
        )

        // signed out / has profile → welcome or local main per policy
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                isOnboardingModelReady: true,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .welcome
        )

        // signed in / no profile → onboarding
        XCTAssertEqual(
            resolve(authState: signedInUser, hasLocalProfile: false, rootState: .onboarding, isOnboardingModelReady: true),
            .onboarding
        )

        // signed in / has profile → main
        XCTAssertEqual(
            resolve(authState: signedInUser, hasLocalProfile: true, rootState: .main),
            .main
        )
    }

    // MARK: - Helpers

    private func resolve(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        awaitingCloudSync: Bool = false,
        publicEntryDestination: PublicEntryRoute = .welcome
    ) -> OnboardingShellRoute {
        OnboardingShellRouteResolver.resolve(
            OnboardingShellRouteInput(
                authState: authState,
                hasLocalProfile: hasLocalProfile,
                rootState: rootState,
                isOnboardingModelReady: isOnboardingModelReady,
                signedOutWithProfilePolicy: signedOutWithProfilePolicy,
                awaitingCloudSync: awaitingCloudSync,
                publicEntryDestination: publicEntryDestination
            )
        )
    }
}
