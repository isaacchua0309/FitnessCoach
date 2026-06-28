//
//  AppRouteResolverGuardrailTests.swift
//  Fitness CoachTests
//
//  Additional pure routing cases for the auth-gated app shell.
//

import XCTest
@testable import Fitness_Coach

final class AppRouteResolverGuardrailTests: XCTestCase {

    func testSignedInProfileErrorSurfacesMessage() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .error("Cloud restore failed.")
            ),
            .profileError("Cloud restore failed.")
        )
    }

    func testIsSignedInOnlyTrueForSignedInState() {
        XCTAssertFalse(AppRouteResolver.isSignedIn(.unknown))
        XCTAssertFalse(AppRouteResolver.isSignedIn(.signedOut))
        XCTAssertTrue(AppRouteResolver.isSignedIn(.signedIn(uid: "abc")))
    }

    func testBootstrapMainMapsToSignedInMainShell() {
        let root = RootProfileRouteResolver.resolve(bootstrapResult: .main)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: root
            ),
            .main
        )
    }

    func testBootstrapMissingCloudProfileMapsToInterstitialShell() {
        let root = RootProfileRouteResolver.resolve(bootstrapResult: .missingCloudProfile)
        XCTAssertEqual(root, .missingCloudProfile)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: root
            ),
            .noExistingProfileFound
        )
    }

    func testHasProfileFalseAlwaysOnboardingRegardlessOfBootstrapCache() {
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: false), .onboarding)
    }

    func testSignedOutV2LocalOnboardingRoutesDoNotRequireSignedInRootState() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .loading,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStart
        )
    }

    func testSignedInExistingUserWithProfileStillRoutesToMainWhenV2Enabled() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "existing-user"),
                rootState: .main,
                hasLocalProfile: true,
            ),
            .main
        )
    }

    func testOnboardingShellRouteMapsToLocalOnboardingAppShellRoute() {
        XCTAssertEqual(
            AppShellRoute(onboardingShellRoute: .onboardingStart),
            .onboardingStart
        )
        XCTAssertEqual(
            AppShellRoute(onboardingShellRoute: .onboardingStartInitializing),
            .onboardingStartInitializing
        )
    }

    func testResolveLocalProfileUsesRootProfileRouteResolver() {
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: false), .onboarding)
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: true), .main)
    }

    func testPreAuthOnboardingRouteWhenSignedOutWithoutProfileAndV2Enabled() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                rootState: .loading,
                isOnboardingModelReady: true,
                hasLocalProfile: false,
                publicEntryDestination: .onboardingStart
            ),
            .onboardingStart
        )
        XCTAssertEqual(
            OnboardingShellRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: false,
                isOnboardingModelReady: true,
            ),
            .welcome
        )
    }

    func testExistingSignedInUserWithProfileSkipsOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "existing-user"),
                rootState: .main,
                hasLocalProfile: true
            ),
            .main
        )
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: true), .main)
    }
}
