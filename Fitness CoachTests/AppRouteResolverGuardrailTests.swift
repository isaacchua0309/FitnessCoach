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

    func testBootstrapOnboardingMapsToOnboardingShell() {
        let root = RootProfileRouteResolver.resolve(bootstrapResult: .onboarding)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: root,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
    }

    func testHasProfileFalseAlwaysOnboardingRegardlessOfBootstrapCache() {
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: false), .onboarding)
    }
}
