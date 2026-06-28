//
//  OnboardingCopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — UX guardrails for onboarding copy tone and claims.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingCopyGuardrailTests: XCTestCase {

    private let bannedTerms = [
        "guaranteed",
        "perfect plan",
        "will lose",
        "transformation",
        "you failed",
        "you must",
        "step "
    ]

    func testOnboardingCopyAvoidsOverclaimsAndShameLanguage() {
        let samples = onboardingCopySamples()

        for sample in samples {
            let lowered = sample.lowercased()
            for term in bannedTerms {
                XCTAssertFalse(
                    lowered.contains(term),
                    "Unexpected term \"\(term)\" in: \(sample)"
                )
            }
        }
    }

    func testCanonicalFlowUsesIntroProofEntry() {
        XCTAssertEqual(OnboardingEntry.initialStep(for: .preAuth), .introProof)
        XCTAssertEqual(OnboardingStep.flow.first, .introProof)
    }

    // MARK: - Helpers

    private func onboardingCopySamples() -> [String] {
        let shared = FormaProductCopy.Onboarding.V2.self
        let flow = FormaProductCopy.Onboarding.Flow.self
        return [
            flow.IntroProof.title,
            flow.IntroProof.subtitle,
            flow.IntroProof.caption,
            flow.HeightWeight.subtitle,
            flow.HeightWeight.helper,
            flow.TargetWeight.subtitle,
            flow.TargetEncouragement.subtitle,
            flow.Birthday.subtitle,
            flow.Activity.subtitle,
            flow.AppleHealth.subtitle,
            flow.AlmostThere.subtitle,
            flow.FormaProof.subtitle,
            flow.Summary.subtitle,
            flow.Summary.buildPlanCTA,
            flow.PlanReveal.subtitle,
            flow.SavePlan.subtitle,
            flow.SavePlan.trustNote,
            shared.MissingCloudProfile.title,
            shared.MissingCloudProfile.body,
            shared.BootstrapError.title,
            shared.BootstrapError.body,
            shared.Goal.goalMustBeBelowCurrent,
            shared.Generating.failureMessage,
            shared.Generating.checklist.joined(separator: " "),
            shared.PlanReveal.subtitle,
            shared.PlanReveal.cutCalorieExplanation,
            shared.PlanReveal.viewMacrosCTA,
            shared.PlanReveal.savePlanCTA,
            shared.PlanReveal.signedOutSaveTrustNote,
            shared.PlanReveal.signedInSaveTrustNote,
            shared.PlanReveal.Status.sustainableTitle,
            shared.PlanReveal.Status.aggressiveDeficitTitle,
            shared.PlanReveal.Status.aggressiveDeficitBody,
            shared.PlanReveal.Reassurance.title,
            shared.PlanReveal.Reassurance.body,
            shared.PlanReveal.Reassurance.bullets.joined(separator: " "),
            shared.SavePlan.subtitle,
            shared.SavePlan.trustNote,
            shared.SavePlan.localOnlyHint,
            shared.SavePlan.signedInSubtitle,
            shared.SavePlan.signInRetryMessage,
            shared.ProfileConflict.title,
            shared.ProfileConflict.body,
            shared.ProfileConflict.restoreCTA,
            shared.ProfileConflict.useDevicePlanCTA,
            shared.CloudCheckFailed.title,
            shared.CloudCheckFailed.body,
            shared.CloudUploadFailed.title,
            shared.CloudUploadFailed.body,
            shared.CloudUploadFailed.continueCTA,
            FormaProductCopy.Common.completeRequiredFields
        ]
    }
}
