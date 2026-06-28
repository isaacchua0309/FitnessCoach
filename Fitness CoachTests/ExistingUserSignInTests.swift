//
//  ExistingUserSignInTests.swift
//  Fitness CoachTests
//
//  Forma — Returning-member sign-in policy, copy, and analytics tests.
//

import XCTest
@testable import Fitness_Coach

final class ExistingUserSignInTests: XCTestCase {

    // MARK: - Copy

    func testExistingUserSignInCopyMatchesProductSpec() {
        let copy = FormaProductCopy.PublicEntry.ExistingUserSignIn.self
        XCTAssertEqual(copy.title, "Welcome back")
        XCTAssertEqual(copy.subtitle, "Sign in to continue your Forma plan.")
        XCTAssertEqual(
            copy.supportingCopy,
            "Your plan, progress, and settings will be restored if they exist for this account."
        )
        XCTAssertEqual(copy.resolvingMessage, "Looking for your Forma plan…")
        XCTAssertEqual(copy.newToFormaPrompt, "New to Forma?")
        XCTAssertEqual(copy.createMyPlanCTA, "Create My Plan")
    }

    func testExistingUserSignInErrorCopyIsDistinctFromOnboardingSavePlan() {
        let errorCopy = FormaProductCopy.PublicEntry.ExistingUserSignIn.Error.self
        let savePlanCopy = FormaProductCopy.Onboarding.V2.SavePlan.self

        XCTAssertEqual(errorCopy.cancelledTitle, "Sign-in cancelled")
        XCTAssertNotEqual(errorCopy.profileLookupFailedTitle, savePlanCopy.title)
        XCTAssertNotEqual(errorCopy.profileLookupFailedMessage, savePlanCopy.signInRetryMessage)
    }

    // MARK: - Analytics

    func testExistingUserSignInAnalyticsEventNames() {
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInViewed.rawValue,
            "existing_sign_in_viewed"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInStarted.rawValue,
            "existing_sign_in_started"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInSucceeded.rawValue,
            "existing_sign_in_succeeded"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInFailed.rawValue,
            "existing_sign_in_failed"
        )
        XCTAssertEqual(
            PublicEntryAnalyticsEvent.existingSignInNoProfileFound.rawValue,
            "existing_sign_in_no_profile_found"
        )
    }

    func testFailedAnalyticsIncludesReasonParameter() {
        let properties = PublicEntryAnalyticsProperties(reason: ExistingUserSignInFailureKind.authCancelled.analyticsReason)
        XCTAssertEqual(properties.asParameters(), ["reason": "authCancelled"])
    }

    // MARK: - Auth failure classification

    func testAuthCancelledMapsFromSigningInToSignedOut() {
        let kind = ExistingUserSignInPolicy.failureKind(
            from: .signingIn,
            to: .signedOut
        )
        XCTAssertEqual(kind, .authCancelled)
    }

    func testNetworkFailureMapsFromCanonicalSignInMessage() {
        let kind = ExistingUserSignInPolicy.failureKind(
            from: .signingIn,
            to: .failed(AuthSignInUserMessage.signInFailureMessage)
        )
        XCTAssertEqual(kind, .networkFailed)
    }

    func testAuthFailedMapsFromNonCanonicalFailureMessage() {
        let kind = ExistingUserSignInPolicy.failureKind(
            from: .signingIn,
            to: .failed("Google sign-in is temporarily unavailable.")
        )
        XCTAssertEqual(kind, .authFailed)
    }

    func testSuccessfulAuthTransitionIsNotClassifiedAsFailure() {
        XCTAssertNil(
            ExistingUserSignInPolicy.failureKind(
                from: .signingIn,
                to: .signedIn(uid: "user-1")
            )
        )
    }

    func testFailurePresentationsCoverAllKinds() {
        for kind in [
            ExistingUserSignInFailureKind.authCancelled,
            .authFailed,
            .networkFailed,
            .profileLookupFailed
        ] {
            let presentation = ExistingUserSignInPolicy.presentation(for: kind)
            XCTAssertEqual(presentation.kind, kind)
            XCTAssertFalse(presentation.title.isEmpty)
            XCTAssertFalse(presentation.message.isEmpty)
        }
    }

    // MARK: - Profile reconcile (existing user entry)

    func testExistingUserSignInRestoresCloudProfileWhenFound() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "remote-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true,
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: CloudProfileLookupResult.found(
                    CloudProfileSummary(updatedAt: ProfileTestFixtures.referenceDate)
                )
            )
        )

        XCTAssertEqual(
            decision,
            SignedInProfileReconcileDecision.loadCloudProfile(uid: "remote-user")
        )
    }

    func testExistingUserSignInWithoutCloudProfileRoutesToMissingProfile() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "remote-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true,
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: CloudProfileLookupResult.missing
            )
        )

        XCTAssertEqual(
            decision,
            SignedInProfileReconcileDecision.presentMissingCloudProfile(uid: "remote-user")
        )
    }

    func testExistingUserSignInCloudLookupFailureRoutesToFetchFailed() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "remote-user",
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true,
                hasLocalProfile: false,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: CloudProfileLookupResult.failed
            )
        )

        XCTAssertEqual(
            decision,
            SignedInProfileReconcileDecision.showCloudFetchFailed(uid: "remote-user")
        )
    }

    func testOnboardingCompletionTakesPrecedenceOverExistingUserSignIn() {
        let decision = ProfileBootstrapCoordinator.reconcileDecision(
            SignedInProfileReconcileInput(
                uid: "remote-user",
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: true,
                hasLocalProfile: true,
                localOwnerUID: nil,
                isFreshSignIn: true,
                rootState: .loading,
                isSyncedForCurrentUID: false,
                cloudResult: nil
            )
        )

        XCTAssertEqual(
            decision,
            SignedInProfileReconcileDecision.resolveOnboardingCompletion(uid: "remote-user")
        )
    }
}
