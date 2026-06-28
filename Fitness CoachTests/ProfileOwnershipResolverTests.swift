//
//  ProfileOwnershipResolverTests.swift
//  Fitness CoachTests
//
//  Forma — Table-driven tests for pure profile ownership resolution (Stage 2).
//

import XCTest
@testable import Fitness_Coach

final class ProfileOwnershipResolverTests: XCTestCase {

    private let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let signedInUID = "signed-in-user"
    private let otherUID = "other-user"

    private var cloudSummary: CloudProfileSummary {
        CloudProfileSummary(updatedAt: referenceDate)
    }

    // MARK: - Table

    private struct Case: Sendable {
        var name: String
        var input: ProfileOwnershipInput
        var expected: ProfileOwnershipOutcome
    }

    private var cases: [Case] {
        [
            // Owner matches → use local.
            Case(
                name: "owner_matches_use_local",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: signedInUID,
                    cloudResult: .missing
                ),
                expected: .useLocalProfile
            ),
            Case(
                name: "owner_matches_use_local_even_when_not_synced",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: signedInUID,
                    cloudResult: .found(cloudSummary),
                    isSyncedForCurrentUID: false
                ),
                expected: .useLocalProfile
            ),

            // Owner mismatch → account mismatch.
            Case(
                name: "owner_mismatch_account_mismatch",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: otherUID,
                    cloudResult: .missing
                ),
                expected: .showAccountMismatch
            ),
            Case(
                name: "owner_mismatch_cloud_found_still_account_mismatch",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: otherUID,
                    cloudResult: .found(cloudSummary)
                ),
                expected: .showAccountMismatch
            ),

            // Synced metadata alone does not override owner mismatch.
            Case(
                name: "synced_metadata_does_not_override_owner_mismatch",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: otherUID,
                    cloudResult: .missing,
                    isSyncedForCurrentUID: true
                ),
                expected: .showAccountMismatch
            ),

            // Owner nil + cloud found → conflict.
            Case(
                name: "owner_nil_cloud_found_conflict",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .found(cloudSummary)
                ),
                expected: .showProfileConflict
            ),

            // Owner nil + cloud missing + onboarding completion → upload local.
            Case(
                name: "owner_nil_cloud_missing_onboarding_completion_upload",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .missing,
                    signInContext: .onboardingCompletion
                ),
                expected: .uploadLocalProfile
            ),
            Case(
                name: "pending_onboarding_completion_cloud_missing_upload",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: .missing
                ),
                expected: .uploadLocalProfile
            ),

            // Owner nil + cloud failed → cloud failed, no upload.
            Case(
                name: "owner_nil_cloud_failed_no_upload",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .failed
                ),
                expected: .showCloudFetchFailed
            ),
            Case(
                name: "owner_nil_cloud_failed_onboarding_completion_no_upload",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: .failed
                ),
                expected: .showCloudFetchFailed
            ),

            // No local + cloud found → restore.
            Case(
                name: "no_local_cloud_found_restore",
                input: baseInput(
                    hasLocalProfile: false,
                    cloudResult: .found(cloudSummary)
                ),
                expected: .restoreCloudProfile
            ),

            // No local + cloud missing → missing cloud profile.
            Case(
                name: "no_local_cloud_missing_interstitial",
                input: baseInput(
                    hasLocalProfile: false,
                    cloudResult: .missing
                ),
                expected: .showMissingCloudProfile
            ),

            // No local + cloud failed → cloud failed.
            Case(
                name: "no_local_cloud_failed",
                input: baseInput(
                    hasLocalProfile: false,
                    cloudResult: .failed
                ),
                expected: .showCloudFetchFailed
            ),

            // Onboarding completion + cloud found → conflict.
            Case(
                name: "onboarding_completion_cloud_found_conflict",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: signedInUID,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: .found(cloudSummary)
                ),
                expected: .showProfileConflict
            ),
            Case(
                name: "onboarding_completion_cloud_found_conflict_even_nil_owner",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: .found(cloudSummary)
                ),
                expected: .showProfileConflict
            ),

            // Cloud failure never uploads local (returning user pre-auth link path).
            Case(
                name: "cloud_failure_never_uploads_returning_user",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .failed,
                    signInContext: .returningUser,
                    isSyncedForCurrentUID: false
                ),
                expected: .showCloudFetchFailed
            ),

            // Require cloud lookup when result not yet available.
            Case(
                name: "no_local_requires_cloud_lookup",
                input: baseInput(
                    hasLocalProfile: false,
                    cloudResult: nil
                ),
                expected: .requireCloudLookup
            ),
            Case(
                name: "unowned_local_requires_cloud_lookup",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: nil
                ),
                expected: .requireCloudLookup
            ),
            Case(
                name: "pending_onboarding_completion_requires_cloud_lookup",
                input: baseInput(
                    hasLocalProfile: true,
                    hasLocalProfilePendingOnboardingCompletion: true,
                    cloudResult: nil
                ),
                expected: .requireCloudLookup
            ),

            // Transitional sync hint for legacy unowned local + missing cloud.
            Case(
                name: "unowned_local_missing_cloud_sync_hint_use_local",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .missing,
                    signInContext: .returningUser,
                    isSyncedForCurrentUID: true
                ),
                expected: .useLocalProfile
            ),

            // Account switch with unowned local + missing cloud → mismatch (no upload).
            Case(
                name: "account_switch_unowned_local_missing_cloud_mismatch",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .missing,
                    signInContext: .accountSwitch
                ),
                expected: .showAccountMismatch
            ),

            // Pre-auth first link: unowned local + missing cloud + not synced → upload.
            Case(
                name: "unowned_local_missing_cloud_first_link_upload",
                input: baseInput(
                    hasLocalProfile: true,
                    localOwnerUID: nil,
                    cloudResult: .missing,
                    signInContext: .returningUser,
                    isSyncedForCurrentUID: false
                ),
                expected: .uploadLocalProfile
            ),
        ]
    }

    func testResolveTable() {
        for testCase in cases {
            let outcome = ProfileOwnershipResolver.resolve(testCase.input)
            XCTAssertEqual(
                outcome,
                testCase.expected,
                "Failed case: \(testCase.name)"
            )
        }
    }

    func testCloudFailureNeverProducesUpload() {
        let failureInputs: [ProfileOwnershipInput] = [
            baseInput(hasLocalProfile: true, localOwnerUID: nil, cloudResult: .failed),
            baseInput(
                hasLocalProfile: true,
                localOwnerUID: nil,
                hasLocalProfilePendingOnboardingCompletion: true,
                cloudResult: .failed
            ),
            baseInput(hasLocalProfile: false, cloudResult: .failed),
            baseInput(
                hasLocalProfile: true,
                localOwnerUID: nil,
                cloudResult: .failed,
                signInContext: .onboardingCompletion
            ),
        ]

        for input in failureInputs {
            let outcome = ProfileOwnershipResolver.resolve(input)
            XCTAssertNotEqual(
                outcome,
                .uploadLocalProfile,
                "Cloud failure must not upload for input: \(input)"
            )
        }
    }

    // MARK: - Helpers

    private func baseInput(
        hasLocalProfile: Bool = true,
        localOwnerUID: String? = nil,
        hasLocalProfilePendingOnboardingCompletion: Bool = false,
        cloudResult: CloudProfileLookupResult? = nil,
        signInContext: SignInContext = .normalLaunch,
        isSyncedForCurrentUID: Bool = false
    ) -> ProfileOwnershipInput {
        ProfileOwnershipInput(
            signedInUID: signedInUID,
            hasLocalProfile: hasLocalProfile,
            localOwnerUID: localOwnerUID,
            hasLocalProfilePendingOnboardingCompletion: hasLocalProfilePendingOnboardingCompletion,
            cloudResult: cloudResult,
            signInContext: signInContext,
            isSyncedForCurrentUID: isSyncedForCurrentUID
        )
    }
}
