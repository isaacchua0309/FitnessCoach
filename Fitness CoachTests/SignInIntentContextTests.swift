//
//  SignInIntentContextTests.swift
//  Fitness CoachTests
//
//  Forma — Sign-in intent separation: restore vs onboarding save-plan.
//

import XCTest
@testable import Fitness_Coach

final class SignInIntentContextTests: XCTestCase {

    private let uid = "remote-user"
    private let referenceDate = ProfileTestFixtures.referenceDate

    // MARK: - Intent resolution

    func testIntentMapsToDistinctSignInContexts() {
        XCTAssertEqual(
            ProfileSignInIntent.existingUserRestore.signInContext,
            .existingUserEntry
        )
        XCTAssertEqual(
            ProfileSignInIntent.onboardingCompletion.signInContext,
            .onboardingCompletion
        )
        XCTAssertNotEqual(
            ProfileSignInIntent.existingUserRestore.signInContext,
            ProfileSignInIntent.onboardingCompletion.signInContext
        )
    }

    func testIntentResolvesFromSessionFlags() {
        XCTAssertEqual(
            ProfileSignInIntent(
                pendingOnboardingCompletion: true,
                pendingExistingUserSignIn: false
            ),
            .onboardingCompletion
        )
        XCTAssertEqual(
            ProfileSignInIntent(
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: true
            ),
            .existingUserRestore
        )
        XCTAssertNil(
            ProfileSignInIntent(
                pendingOnboardingCompletion: false,
                pendingExistingUserSignIn: false
            )
        )
    }

    func testOnboardingCompletionTakesPrecedenceOverExistingUserIntent() {
        XCTAssertEqual(
            ProfileBootstrapCoordinator.profileSignInIntent(
                for: SignedInProfileReconcileInput(
                    uid: uid,
                    pendingOnboardingCompletion: true,
                    pendingExistingUserSignIn: true,
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    isFreshSignIn: true,
                    rootState: .loading,
                    isSyncedForCurrentUID: false
                )
            ),
            .onboardingCompletion
        )
    }

    // MARK: - Existing user restore

    func testExistingSignInNoProfileRoutesToNoProfileFound() {
        let decision = reconcile(
            pendingExistingUserSignIn: true,
            hasLocalProfile: false,
            cloudResult: .missing
        )

        XCTAssertEqual(decision, .presentMissingCloudProfile(uid: uid))
        XCTAssertEqual(
            ProfileBootstrapCoordinator.profileSignInIntent(
                for: reconcileInput(
                    pendingExistingUserSignIn: true,
                    hasLocalProfile: false,
                    cloudResult: .missing
                )
            ),
            .existingUserRestore
        )
    }

    func testExistingSignInDoesNotUploadEmptyProfile() {
        let decision = reconcile(
            pendingExistingUserSignIn: true,
            hasLocalProfile: false,
            cloudResult: .missing
        )

        XCTAssertEqual(decision, .presentMissingCloudProfile(uid: uid))
        XCTAssertNotEqual(decision, .syncLocalProfileToCloud(uid: uid))
        XCTAssertEqual(
            ProfileOwnershipResolver.resolve(
                ProfileOwnershipInput(
                    signedInUID: uid,
                    hasLocalProfile: false,
                    localOwnerUID: nil,
                    hasLocalProfilePendingOnboardingCompletion: false,
                    cloudResult: .missing,
                    signInContext: .existingUserEntry,
                    isSyncedForCurrentUID: false
                )
            ),
            .showMissingCloudProfile
        )
    }

    func testExistingSignInWithCloudProfileRestoresFromCloud() {
        let decision = reconcile(
            pendingExistingUserSignIn: true,
            hasLocalProfile: false,
            cloudResult: .found(CloudProfileSummary(updatedAt: referenceDate))
        )

        XCTAssertEqual(decision, .loadCloudProfile(uid: uid))
        XCTAssertNotEqual(decision, .syncLocalProfileToCloud(uid: uid))
    }

    // MARK: - Onboarding completion

    func testOnboardingSignInUploadsNewProfileWhenCloudMissing() {
        let decision = reconcile(
            pendingOnboardingCompletion: true,
            hasLocalProfile: true,
            localOwnerUID: nil,
            cloudResult: .missing
        )

        XCTAssertEqual(decision, .syncLocalProfileToCloud(uid: uid))
        XCTAssertEqual(
            ProfileOwnershipResolver.resolve(
                ProfileOwnershipInput(
                    signedInUID: uid,
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: .missing,
                    signInContext: .onboardingCompletion,
                    isSyncedForCurrentUID: false
                )
            ),
            .uploadLocalProfile
        )
    }

    func testOnboardingSignInWithCloudProfileShowsConflict() {
        let decision = reconcile(
            pendingOnboardingCompletion: true,
            hasLocalProfile: true,
            localOwnerUID: nil,
            cloudResult: .found(CloudProfileSummary(updatedAt: referenceDate))
        )

        XCTAssertEqual(decision, .showProfileConflict(uid: uid))
    }

    func testOnboardingCompletionRequiresDedicatedCloudResolutionPath() {
        let decision = reconcile(
            pendingOnboardingCompletion: true,
            hasLocalProfile: true,
            localOwnerUID: nil,
            cloudResult: nil
        )

        XCTAssertEqual(decision, .resolveOnboardingCompletion(uid: uid))
    }

    // MARK: - Copy separation

    func testExistingUserSignInCopyDoesNotUseSavePlanLanguage() {
        let title = ProfileSignInCopyPolicy.googleButtonTitle(for: .existingUserRestore)
        let hint = ProfileSignInCopyPolicy.googleButtonAccessibilityHint(for: .existingUserRestore)

        XCTAssertFalse(ProfileSignInCopyPolicy.usesSavePlanLanguage(title))
        XCTAssertFalse(ProfileSignInCopyPolicy.usesSavePlanLanguage(hint))
        XCTAssertEqual(title, FormaProductCopy.SignIn.continueWithGoogle)
    }

    func testOnboardingCompletionKeepsSavePlanLanguage() {
        let title = ProfileSignInCopyPolicy.googleButtonTitle(for: .onboardingCompletion)
        let hint = ProfileSignInCopyPolicy.googleButtonAccessibilityHint(for: .onboardingCompletion)

        XCTAssertTrue(ProfileSignInCopyPolicy.usesSavePlanLanguage(hint))
        XCTAssertEqual(title, FormaProductCopy.Onboarding.V2.SavePlan.googleSignInCTA)
    }

    // MARK: - Helpers

    private func reconcileInput(
        pendingOnboardingCompletion: Bool = false,
        pendingExistingUserSignIn: Bool = false,
        hasLocalProfile: Bool,
        localOwnerUID: String? = nil,
        cloudResult: CloudProfileLookupResult? = nil
    ) -> SignedInProfileReconcileInput {
        SignedInProfileReconcileInput(
            uid: uid,
            pendingOnboardingCompletion: pendingOnboardingCompletion,
            pendingExistingUserSignIn: pendingExistingUserSignIn,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            isFreshSignIn: true,
            rootState: .loading,
            isSyncedForCurrentUID: false,
            cloudResult: cloudResult
        )
    }

    private func reconcile(
        pendingOnboardingCompletion: Bool = false,
        pendingExistingUserSignIn: Bool = false,
        hasLocalProfile: Bool,
        localOwnerUID: String? = nil,
        cloudResult: CloudProfileLookupResult? = nil
    ) -> SignedInProfileReconcileDecision {
        ProfileBootstrapCoordinator.reconcileDecision(
            reconcileInput(
                pendingOnboardingCompletion: pendingOnboardingCompletion,
                pendingExistingUserSignIn: pendingExistingUserSignIn,
                hasLocalProfile: hasLocalProfile,
                localOwnerUID: localOwnerUID,
                cloudResult: cloudResult
            )
        )
    }
}
