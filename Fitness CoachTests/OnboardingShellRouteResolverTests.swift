//
//  OnboardingShellRouteResolverTests.swift
//  Fitness CoachTests
//
//  Forma — Pure onboarding v2 shell routing tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingShellRouteResolverTests: XCTestCase {

    private let v2Disabled = false
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

    // MARK: - Signed out, no profile (v2)

    func testSignedOutNoProfileRoutesToPreAuthOnboarding() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true
            ),
            .preAuthOnboarding
        )
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: false
            ),
            .preAuthOnboardingInitializing
        )
        XCTAssertEqual(
            resolve(
                authState: .signingIn,
                hasLocalProfile: false,
                isOnboardingModelReady: true
            ),
            .preAuthOnboarding
        )
    }

    // MARK: - Signed out, has profile (v2)

    func testSignedOutHasProfileRoutesToPreAuthLandingByDefault() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                isOnboardingModelReady: false,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .preAuthOnboardingInitializing
        )
        XCTAssertEqual(
            resolve(
                authState: .failed("Sign-in failed"),
                hasLocalProfile: true,
                isOnboardingModelReady: true,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .preAuthOnboarding
        )
    }

    func testSignedOutHasProfileCanRouteToLocalMainWhenAllowed() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .allowLocalMain
            ),
            .localMain
        )
    }

    // MARK: - Signed in, no profile

    func testSignedInNoCloudProfileRoutesToMissingCloudProfileInterstitial() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .missingCloudProfile
            ),
            .missingCloudProfile
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

    // MARK: - Legacy / feature flag off

    func testFeatureFlagOffPreservesLegacySignedOutRouting() {
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingV2Enabled: v2Disabled
            ),
            .signIn
        )
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                isOnboardingV2Enabled: v2Disabled,
                signedOutWithProfilePolicy: .allowLocalMain
            ),
            .signIn
        )
    }

    func testFeatureFlagOffPreservesLegacySignedInRouting() {
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: false,
                rootState: .onboarding,
                isOnboardingModelReady: true,
                isOnboardingV2Enabled: v2Disabled
            ),
            .onboarding
        )
        XCTAssertEqual(
            resolve(
                authState: signedInUser,
                hasLocalProfile: true,
                rootState: .main,
                isOnboardingV2Enabled: v2Disabled,
                awaitingCloudSync: true
            ),
            .main
        )
    }

    func testFeatureFlagOffUnknownStillRoutesToLaunchLoading() {
        XCTAssertEqual(
            resolve(
                authState: .unknown,
                hasLocalProfile: false,
                isOnboardingV2Enabled: v2Disabled
            ),
            .launchLoading
        )
    }

    // MARK: - G1 routing matrix

    func testG1RoutingMatrixCoversSignedOutSignedInAndFlagOff() {
        // auth unknown → loading
        XCTAssertEqual(
            resolve(authState: .unknown, hasLocalProfile: false),
            .launchLoading
        )

        // signed out / no profile → pre-auth onboarding (v2 on)
        XCTAssertEqual(
            resolve(authState: .signedOut, hasLocalProfile: false, isOnboardingModelReady: true),
            .preAuthOnboarding
        )

        // signed out / has profile → pre-auth landing or local main per policy
        XCTAssertEqual(
            resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                isOnboardingModelReady: true,
                signedOutWithProfilePolicy: .requireSignIn
            ),
            .preAuthOnboarding
        )
        XCTAssertEqual(
            resolve(authState: .signedOut, hasLocalProfile: true, signedOutWithProfilePolicy: .allowLocalMain),
            .localMain
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

        // flag off → legacy sign-in for signed-out users
        XCTAssertEqual(
            resolve(authState: .signedOut, hasLocalProfile: false, isOnboardingV2Enabled: v2Disabled),
            .signIn
        )
    }

    // MARK: - Helpers

    private func resolve(
        authState: AuthState,
        hasLocalProfile: Bool,
        rootState: RootViewState = .loading,
        isOnboardingModelReady: Bool = false,
        isOnboardingV2Enabled: Bool = true,
        signedOutWithProfilePolicy: SignedOutWithProfilePolicy = .requireSignIn,
        awaitingCloudSync: Bool = false
    ) -> OnboardingShellRoute {
        OnboardingShellRouteResolver.resolve(
            authState: authState,
            hasLocalProfile: hasLocalProfile,
            rootState: rootState,
            isOnboardingModelReady: isOnboardingModelReady,
            isOnboardingV2Enabled: isOnboardingV2Enabled,
            signedOutWithProfilePolicy: signedOutWithProfilePolicy,
            awaitingCloudSync: awaitingCloudSync
        )
    }
}
