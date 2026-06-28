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
            "learns your trend",
            "adjust as real",
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
            flow.AlmostThere.headline,
            flow.AlmostThere.supporting,
            flow.AlmostThere.trustFooter,
            flow.AlmostThere.benefitsAccessibilityLabel,
            flow.AlmostThere.accessibilitySummary,
            flow.AlmostThereBenefits.items.map(\.title).joined(separator: " "),
            flow.FormaProof.visionHeadline,
            flow.FormaProof.Fallback.supporting,
            flow.FormaProof.Loss.supporting(targetWeightLabel: "70 kg"),
            flow.FormaProof.Gain.supporting(targetWeightLabel: "70 kg"),
            flow.FormaProof.Maintain.supporting(targetWeightLabel: "70 kg"),
            flow.FormaProof.Loss.benefits.map(\.title).joined(separator: " "),
            flow.FormaProof.Gain.benefits.map(\.title).joined(separator: " "),
            flow.FormaProof.Maintain.benefits.map(\.title).joined(separator: " "),
            flow.FormaProof.Comparison.withoutBullets.joined(separator: " "),
            flow.FormaProof.Comparison.withFormaBullets.joined(separator: " "),
            flow.FormaProof.Trust.personalized,
            flow.Summary.title,
            flow.Summary.subtitle,
            flow.Summary.buildPlanCTA,
            flow.Summary.buildPlanAnticipationHeadline,
            flow.Summary.buildPlanAnticipationSubline,
            flow.Summary.buildPlanAnticipationAccessibilityLabel,
            flow.Summary.GoalCard.maintainTimeline,
            flow.Summary.PremiumFeatures.items.map(\.title).joined(separator: " "),
            flow.Summary.GeneratedSummary.title,
            flow.Summary.GeneratedSummary.activityLevel,
            flow.Summary.GeneratedSummary.currentWeight,
            flow.Summary.GeneratedSummary.goal,
            flow.Summary.GeneratedSummary.nutritionTargets,
            flow.Summary.GeneratedSummary.lifestyle,
            flow.Summary.GeneratedSummary.trainingRhythm,
            flow.Summary.GeneratedSummary.nutritionDetail,
            flow.Summary.GeneratedSummary.accessibilityLabel,
            flow.PlanReveal.title,
            flow.PlanReveal.subtitle,
            flow.PlanReveal.signedOutSaveTrustNote,
            flow.PlanReveal.signedInSaveTrustNote,
            flow.SavePlan.subtitle,
            flow.SavePlan.trustNote,
            flow.SavePlan.signedInSubtitle,
            flow.SavePlan.signedInTrustNote,
            shared.MissingCloudProfile.title,
            shared.MissingCloudProfile.body,
            shared.BootstrapError.title,
            shared.BootstrapError.body,
            shared.Goal.goalMustBeBelowCurrent,
            shared.Generating.title,
            shared.Generating.successTitle,
            shared.Generating.anticipationText,
            shared.Generating.slowGenerationMessage,
            shared.Generating.failureTitle,
            shared.Generating.failureMessage,
            shared.Generating.tryAgainCTA,
            shared.Generating.goBackCTA,
            shared.Generating.Subtitle.loss,
            shared.Generating.Subtitle.gain,
            shared.Generating.Subtitle.maintain,
            shared.Generating.Subtitle.fallback,
            shared.Generating.checklist.joined(separator: " "),
            shared.PlanReveal.subtitle,
            shared.PlanReveal.fallbackSubtitle,
            shared.PlanReveal.dailyMissionSectionTitle,
            shared.PlanReveal.nextStepLine,
            shared.PlanReveal.GoalHero.maintainSupport,
            shared.PlanReveal.GoalHero.lossSupport,
            shared.PlanReveal.GoalHero.gainSupport,
            shared.PlanReveal.Cards.destinationBadge,
            shared.PlanReveal.Cards.journeyTitle,
            shared.PlanReveal.Cards.firstWeekTitle,
            shared.PlanReveal.Cards.dailyFuelTitle,
            shared.PlanReveal.JourneyBelief.maintain,
            shared.PlanReveal.JourneyBelief.gain,
            shared.PlanReveal.FirstWeek.logMealsCut,
            shared.PlanReveal.FirstWeek.proteinCut,
            shared.PlanReveal.FirstWeek.weighCut,
            shared.PlanReveal.Coach.cut(goalWeight: "70 kg"),
            shared.PlanReveal.Coach.maintain,
            shared.PlanReveal.Coach.gain(goalWeight: "70 kg"),
            shared.PlanReveal.FirstWeek.logDaysMaintain,
            shared.PlanReveal.FirstWeek.caloriesMaintain,
            shared.PlanReveal.FirstWeek.waterMaintain,
            shared.PlanReveal.FirstWeek.mealsGain,
            shared.PlanReveal.FirstWeek.proteinGain,
            shared.PlanReveal.FirstWeek.weighGain,
            shared.PlanReveal.Accessibility.goal,
            shared.PlanReveal.Accessibility.journey,
            shared.PlanReveal.Accessibility.firstWeek,
            shared.PlanReveal.Accessibility.dailyFuel,
            shared.PlanReveal.Focus.maintainBody,
            shared.PlanReveal.Focus.lossBody,
            shared.PlanReveal.Focus.gainBody,
            shared.PlanReveal.cutCalorieExplanation,
            shared.PlanReveal.maintainCalorieExplanation,
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
            shared.SavePlan.signedInTrustNote,
            shared.SavePlan.signInRetryMessage,
            shared.SavePlan.signInRetryHeadline,
            shared.SavePlan.signInRetryReassurance,
            shared.SavePlan.signInRetryInvitation,
            shared.SavePlan.signInRetryAccessibilitySummary,
            shared.SavePlan.googleSignInCTA,
            shared.SavePlan.googleSignInAccessibilityHint,
            shared.SavePlan.googleSignInLoadingTitle,
            shared.SavePlan.googleSignInSuccessTitle,
            shared.SavePlan.googleSignInSuccessAccessibilityLabel,
            shared.SavePlan.signedInContinueCTA,
            shared.SavePlan.skipCTA,
            shared.SavePlan.planAchievementTitle,
            shared.SavePlan.planAchievementReachVerb,
            shared.SavePlan.planAchievementMaintainVerb,
            shared.SavePlan.planAchievementGainVerb,
            shared.SavePlan.planAchievementCurrentLabel,
            shared.SavePlan.planAchievementBuiltForYou,
            shared.SavePlan.signInTrustAccessibilitySummary,
            shared.SavePlan.signInTrustRows.map(\.title).joined(separator: " "),
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
