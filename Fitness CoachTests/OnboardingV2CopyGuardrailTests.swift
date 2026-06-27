//
//  OnboardingV2CopyGuardrailTests.swift
//  Fitness CoachTests
//
//  Forma — UX guardrails for onboarding v2 copy tone and claims.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV2CopyGuardrailTests: XCTestCase {

    private let bannedTerms = [
        "guaranteed",
        "perfect plan",
        "will lose",
        "transformation",
        "you failed",
        "you must",
        "step "
    ]

    func testV2CopyAvoidsOverclaimsAndShameLanguage() {
        let samples = onboardingV2CopySamples()

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

    func testLegacyProgressHeaderUsesStepCounterOnlyWhenNotV2Flow() {
        XCTAssertTrue(OnboardingStep.body.progressIndex >= 1)
        XCTAssertEqual(OnboardingStep.totalSteps, 6)
        XCTAssertTrue(OnboardingFlowScope.v2Full.usesV2Steps)
        XCTAssertFalse(OnboardingFlowScope.legacy.usesV2Steps)
    }

    // MARK: - Helpers

    private func onboardingV2CopySamples() -> [String] {
        let v2 = FormaProductCopy.Onboarding.V2.self
        return [
            v2.Landing.subtitle,
            v2.Landing.bullets.joined(separator: " "),
            v2.Landing.existingAccountAction,
            v2.MissingCloudProfile.title,
            v2.MissingCloudProfile.body,
            v2.BootstrapError.title,
            v2.BootstrapError.body,
            v2.Welcome.subtitle,
            v2.Welcome.microcopy,
            v2.Motivation.subtitle,
            v2.Motivation.optionalHint,
            v2.Motivation.confidenceFeedback,
            v2.Motivation.performanceFeedback,
            v2.Motivation.lowStressFeedback,
            v2.Motivation.defaultFeedback,
            v2.Body.subtitle,
            v2.Body.bodyFatHelper,
            v2.Body.bodyFatDisclosureLabel,
            v2.BodyFeedback.message,
            v2.Goal.subtitle,
            v2.Goal.goalMustBeBelowCurrent,
            v2.ActivityFeedback.sedentaryFeedback,
            v2.ActivityFeedback.moderatelyActiveFeedback,
            v2.ActivityFeedback.athleteFeedback,
            v2.Summary.title,
            v2.Summary.subtitle,
            v2.Generating.failureMessage,
            v2.Generating.checklist.joined(separator: " "),
            v2.PlanReveal.subtitle,
            v2.PlanReveal.firstWeekBullets.joined(separator: " "),
            v2.SavePlan.subtitle,
            v2.SavePlan.trustNote,
            v2.SavePlan.localOnlyHint,
            v2.SavePlan.signedInSubtitle,
            v2.SavePlan.signInRetryMessage,
            FormaProductCopy.Common.completeRequiredFields
        ] + OnboardingMotivation.allCases.flatMap { [$0.title, $0.subtitle] }
    }
}
