//
//  AuthRoutingTests.swift
//  Fitness CoachTests
//
//  FitPilot — pure auth-gated routing and sign-in policy tests (no Firebase / Google SDK).
//

import XCTest
@testable import Fitness_Coach

final class AppRouteResolverTests: XCTestCase {

    func testSignedOutRoutesToWelcome() {
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .signedOut),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .signingIn),
            .welcome
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .failed(AuthSignInUserMessage.signInFailureMessage)),
            .welcome
        )
    }

    func testUnknownRoutesToLaunchLoading() {
        XCTAssertEqual(
            AppRouteResolver.resolve(authState: .unknown),
            .launchLoading
        )
    }

    func testSignedInMissingCloudProfileRoutesToInterstitial() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
    }

    func testSignedInMissingCloudProfileDoesNotRouteToOnboardingUntilContinue() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .onboarding,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
        XCTAssertNotEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .missingCloudProfile
            ),
            .onboarding
        )
    }

    func testSignedInWithNoProfileRoutesToOnboarding() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .onboarding,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .onboarding,
                isOnboardingModelReady: false
            ),
            .onboardingInitializing
        )
    }

    func testSignedInWithProfileRoutesToMain() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .main
            ),
            .main
        )
    }

    func testSignedInWhileProfileLoadingRoutesToSignedInProfileLoading() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "google-user"),
                rootState: .loading
            ),
            .signedInProfileLoading
        )
    }

    func testShouldClearOnboardingModelOnlyAfterSignOut() {
        XCTAssertTrue(
            AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: true,
                isSignedIn: false
            )
        )
        XCTAssertFalse(
            AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: false,
                isSignedIn: false
            )
        )
        XCTAssertFalse(
            AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: true,
                isSignedIn: true
            )
        )
    }

    func testShouldRetainOnboardingModelWhenDraftExistsWithoutLocalProfile() {
        XCTAssertFalse(
            AppRouteResolver.shouldClearOnboardingModel(
                wasSignedIn: true,
                isSignedIn: false,
                hasLocalProfile: false,
                hasPersistedOnboardingDraft: true
            )
        )
    }

    func testShouldRotateSignedInSessionOnlyOnFreshSignIn() {
        XCTAssertTrue(
            AppRouteResolver.shouldRotateSignedInSession(
                wasSignedIn: false,
                isSignedIn: true
            )
        )
        XCTAssertFalse(
            AppRouteResolver.shouldRotateSignedInSession(
                wasSignedIn: true,
                isSignedIn: true
            )
        )
    }

    func testSignedInWithNoProfileRootStateRoutesToOnboarding() {
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: false), .onboarding)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "test-user"),
                rootState: .onboarding,
                isOnboardingModelReady: true
            ),
            .onboarding
        )
    }

    func testSignedInWithProfileRootStateRoutesToMain() {
        XCTAssertEqual(RootProfileRouteResolver.resolve(hasProfile: true), .main)
        XCTAssertEqual(RootProfileRouteResolver.resolve(bootstrapResult: .main), .main)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "test-user"),
                rootState: .main
            ),
            .main
        )
    }

    func testBootstrapMissingCloudProfileMapsToInterstitialShell() {
        XCTAssertEqual(
            RootProfileRouteResolver.resolve(bootstrapResult: .missingCloudProfile),
            .missingCloudProfile
        )
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "user-1"),
                rootState: .missingCloudProfile
            ),
            .noExistingProfileFound
        )
    }

    func testLogoutDoesNotDeleteLocalProfilePolicy() {
        XCTAssertFalse(AuthLogoutPolicy.deletesLocalProfileOnSignOut)
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedIn(uid: "returning-user"),
                rootState: RootProfileRouteResolver.resolve(hasProfile: true)
            ),
            .main
        )
    }

    // MARK: - Public entry routing

    func testSignedOutNoProfileRoutesToWelcomeByDefault() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: false
            ),
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
    }

    func testSignedOutCreatePlanRoutesToOnboardingStart() {
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

    func testSignedOutWithLocalProfileRoutesToWelcomeUnlessSavePlanPending() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                isOnboardingModelReady: true,
                hasLocalProfile: true
            ),
            .welcome
        )
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

    func testSignedOutWithLocalProfileCanRouteToLocalMainWhenAllowed() {
        XCTAssertEqual(
            AppRouteResolver.resolve(
                authState: .signedOut,
                hasLocalProfile: true,
                signedOutWithProfilePolicy: .allowLocalMain
            ),
            .localMain
        )
    }
}

final class AuthSignInPolicyTests: XCTestCase {

    func testIDTokenWhenSignedOutThrowsNotSignedIn() {
        XCTAssertEqual(
            AuthTokenPolicy.eligibility(hasUser: false, isGoogleUser: false),
            .notSignedIn
        )
        XCTAssertEqual(
            AuthTokenPolicy.eligibility(hasUser: true, isGoogleUser: false),
            .notSignedIn
        )
        XCTAssertEqual(
            AuthTokenPolicy.eligibility(hasUser: true, isGoogleUser: true),
            .eligible
        )
        XCTAssertEqual(AuthTokenPolicy.eligibilityToError(.notSignedIn), .notSignedIn)
    }

    func testSignInFailureMapsToFriendlyCopy() {
        let underlying = NSError(domain: "com.google.GIDSignIn", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "The operation couldn’t be completed. (com.google.GIDSignIn error -1.)"
        ])

        let message = AuthSignInErrorClassifier.userFacingSignInFailureMessage(for: underlying)

        XCTAssertEqual(message, AuthSignInUserMessage.signInFailure)
        XCTAssertFalse(message.localizedCaseInsensitiveContains("firebase"))
        XCTAssertFalse(message.localizedCaseInsensitiveContains("GIDSignIn"))
    }

    func testGoogleCancellationDoesNotSurfaceScaryError() {
        let cancellation = NSError(
            domain: AuthSignInErrorClassifier.googleSignInErrorDomain,
            code: AuthSignInErrorClassifier.canceledErrorCode
        )

        XCTAssertTrue(AuthSignInErrorClassifier.isCancellation(cancellation))
        XCTAssertFalse(AuthSignInErrorClassifier.shouldSurfaceSignInFailure(for: cancellation))
        XCTAssertEqual(AuthSignInErrorClassifier.userFacingSignInFailureMessage(for: cancellation), "")
        XCTAssertNil(
            AuthSignInPresentationPolicy.failurePresentation(authState: .signedOut)
        )
    }

    func testFailedAuthStateUsesFriendlyBannerCopy() {
        let presentation = AuthSignInPresentationPolicy.failurePresentation(
            authState: .failed("com.google.GIDSignIn error -1.")
        )

        XCTAssertEqual(presentation?.title, AuthSignInUserMessage.signInFailureTitle)
        XCTAssertEqual(presentation?.message, AuthSignInUserMessage.signInFailureMessage)
    }

    func testFailurePresentationIgnoresRawErrorMessage() {
        let presentation = AuthSignInPresentationPolicy.failurePresentation(
            authState: .failed("Firebase Auth error 17020.")
        )

        XCTAssertEqual(presentation?.title, AuthSignInUserMessage.signInFailureTitle)
        XCTAssertEqual(presentation?.message, AuthSignInUserMessage.signInFailureMessage)
        XCTAssertFalse(presentation!.message.localizedCaseInsensitiveContains("firebase"))
        XCTAssertFalse(presentation!.message.localizedCaseInsensitiveContains("GIDSignIn"))
        XCTAssertFalse(presentation!.message.localizedCaseInsensitiveContains("token"))
    }

    func testLaunchUsesStartListeningOnly() {
        XCTAssertEqual(LaunchAuthPolicy.launchAction, .startListeningOnly)
        XCTAssertFalse(AuthCapabilities.supportsAnonymousSignIn)
    }

    func testAuthGateLaunchDoesNotAutoSignInAnonymously() {
        XCTAssertEqual(LaunchAuthPolicy.launchAction, .startListeningOnly)
        XCTAssertFalse(AuthCapabilities.supportsAnonymousSignIn)
    }

    func testGoogleUserSessionIsAccepted() {
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: true,
                isGoogleUser: true,
                currentAuthState: .unknown
            ),
            .acceptSignedIn
        )
    }

    func testNonGoogleUserSessionIsRejected() {
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: true,
                isGoogleUser: false,
                currentAuthState: .unknown
            ),
            .rejectNonGoogleSession
        )
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: true,
                isGoogleUser: false,
                currentAuthState: .signedOut
            ),
            .rejectNonGoogleSession
        )
    }

    func testNilUserWhileSigningInPreservesSigningIn() {
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: false,
                isGoogleUser: false,
                currentAuthState: .signingIn
            ),
            .preserveSigningIn
        )
    }

    func testNilUserWhileFailedPreservesFailed() {
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: false,
                isGoogleUser: false,
                currentAuthState: .failed(AuthSignInUserMessage.signInFailure)
            ),
            .preserveFailed
        )
    }

    func testNilUserWhileSignedOutStaysSignedOut() {
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: false,
                isGoogleUser: false,
                currentAuthState: .signedOut
            ),
            .signedOut
        )
        XCTAssertEqual(
            AuthSessionPolicy.resolve(
                hasUser: false,
                isGoogleUser: false,
                currentAuthState: .unknown
            ),
            .signedOut
        )
    }

    func testFreshInstallClearsPersistedSessionOnLaunch() {
        XCTAssertTrue(
            AuthInstallPolicy.isFreshInstall(hasInstallMarker: false)
        )
        XCTAssertFalse(
            AuthInstallPolicy.isFreshInstall(hasInstallMarker: true)
        )
        XCTAssertTrue(
            AuthInstallPolicy.shouldClearPersistedSessionOnLaunch(isFreshInstall: true)
        )
        XCTAssertFalse(
            AuthInstallPolicy.shouldClearPersistedSessionOnLaunch(isFreshInstall: false)
        )
    }
}
