//
//  PublicEntryCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — UX guardrails for public entry copy and trust claims.
//

import XCTest
@testable import Fitness_Coach

final class PublicEntryCopyGuardrailTests: XCTestCase {

    func testPublicEntryCopyAvoidsBannedTrustClaims() {
        for sample in PublicEntryCopyGuardrail.allUserFacingStrings {
            XCTAssertFalse(
                PublicEntryCopyGuardrail.containsBannedTrustClaim(sample),
                "Banned trust claim in: \(sample)"
            )
        }
    }

    func testExistingUserSignInCopyAvoidsOnboardingSavePlanLanguage() {
        let signIn = FormaProductCopy.PublicEntry.ExistingUserSignIn.self
        let savePlan = FormaProductCopy.Onboarding.V2.SavePlan.self
        let samples = [
            signIn.title,
            signIn.subtitle,
            signIn.supportingCopy,
            signIn.googleSignInCTA,
            signIn.googleSignInAccessibilityHint
        ]

        for sample in samples {
            XCTAssertFalse(
                sample.localizedCaseInsensitiveContains("save plan"),
                "Save-plan language in existing-user sign-in copy: \(sample)"
            )
            XCTAssertNotEqual(sample, savePlan.title)
            XCTAssertNotEqual(sample, savePlan.signInRetryMessage)
        }
    }

    func testPublicEntryLoadingCopyUsesCentralizedStrings() {
        let loading = FormaProductCopy.PublicEntry.Loading.self
        XCTAssertEqual(loading.appLaunch, FormaProductCopy.Loading.app)
        XCTAssertEqual(
            loading.restoringPlan,
            FormaProductCopy.PublicEntry.ExistingUserSignIn.resolvingMessage
        )
    }
}
