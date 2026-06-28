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

    func testOnboardingCopyAvoidsRemovedManualCollectionLanguage() {
        let samples = onboardingCopySamples()
        let forbidden = [
            "dynamic calor",
            "body fat",
            "enter your age",
            "gym session",
            "log your steps",
            "training rhythm"
        ]

        for sample in samples {
            let lowered = sample.lowercased()
            for term in forbidden {
                XCTAssertFalse(
                    lowered.contains(term),
                    "Unexpected removed-flow term \"\(term)\" in: \(sample)"
                )
            }
        }
    }

    // MARK: - Helpers

    private func onboardingCopySamples() -> [String] {
        let shared = FormaProductCopy.Onboarding.V2.self
        let flow = FormaProductCopy.Onboarding.Flow.self
        return [
            flow.IntroProof.title,
            flow.IntroProof.subtitle,
            flow.IntroProof.takeaway,
            flow.HeightWeight.subtitle,
            flow.HeightWeight.helper,
            flow.TargetWeight.subtitle,
            flow.TargetWeight.interactionHint,
            flow.TargetWeight.maintainGoalTitle,
            flow.TargetWeight.maintainGoalBody,
            flow.TargetWeight.realisticTargetTitle,
            flow.TargetWeight.realisticTargetBody,
            flow.TargetWeight.gainGoalTitle,
            flow.TargetWeight.gainGoalBody,
            flow.TargetEncouragement.title,
            flow.TargetEncouragement.subtitle,
            flow.TargetEncouragement.reassuranceTitle,
            flow.TargetEncouragement.reassuranceBody,
            flow.TargetEncouragement.fallbackHero,
            flow.TargetEncouragement.maintainHero,
            flow.TargetEncouragement.benefits.map(\.title).joined(separator: " "),
            flow.TargetEncouragement.benefits.map(\.subtitle).joined(separator: " "),
            flow.Birthday.title,
            flow.Birthday.subtitle,
            flow.Birthday.birthdayLabel,
            flow.Birthday.sexExplanation,
            flow.Birthday.ageExplanation,
            flow.Birthday.trustNote,
            flow.Birthday.trustCardCopy,
            flow.Birthday.agePreviewPlaceholder,
            flow.Birthday.birthDateRequiredMessage,
            flow.Birthday.sexRequiredMessage,
            flow.Activity.subtitle,
            flow.Activity.selectionRequiredMessage,
            flow.Activity.explanationPlaceholder,
            flow.Activity.explanationSupporting,
            flow.Activity.moderatelyActiveExplanationHeadline,
            flow.AppleHealth.subtitle,
            flow.AppleHealth.privacyTitle,
            flow.AppleHealth.privacyBody,
            flow.AppleHealth.connectCTA,
            flow.AppleHealth.skipCTA,
            flow.AppleHealth.deniedMessage,
            flow.AppleHealth.summaryCardTitle,
            flow.AppleHealth.readableDataRows.joined(separator: " "),
            flow.AlmostThere.subtitle,
            flow.AlmostThere.summaryHeadline,
            flow.AlmostThere.summarySupporting,
            flow.AlmostThere.valueSectionTitle,
            flow.AlmostThere.valueSectionAccessibilityLabel,
            flow.AlmostThere.trustStrip,
            flow.AlmostThere.accessibilitySummary,
            flow.AlmostThereFeatures.bullets.map(\.title).joined(separator: " "),
            flow.AlmostThereFeatures.bullets.map(\.subtitle).joined(separator: " "),
            flow.FormaProof.Fallback.title,
            flow.FormaProof.Loss.title,
            flow.FormaProof.Gain.title,
            flow.FormaProof.Maintain.title,
            flow.FormaProof.Comparison.withoutBullets.joined(separator: " "),
            flow.FormaProof.Comparison.withFormaBullets.joined(separator: " "),
            flow.FormaProof.Trust.personalized,
            flow.Summary.title,
            flow.Summary.subtitle,
            flow.Summary.goalFallbackHero,
            flow.Summary.Insight.loss,
            flow.Summary.Insight.gain,
            flow.Summary.Insight.maintain,
            flow.Summary.Basis.title,
            flow.Summary.Basis.age,
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
