//
//  OnboardingStageProgressTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding v2 step model, stage mapping, and navigation policy tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingStageProgressTests: XCTestCase {

    // MARK: - Flows

    func testLegacyFlowPreservesSixSteps() {
        XCTAssertEqual(OnboardingStep.legacyFlow, [
            .welcome, .body, .goal, .activity, .preferences, .planPreview
        ])
        XCTAssertEqual(OnboardingStep.totalSteps, 6)
    }

    func testV2FlowOrder() {
        XCTAssertEqual(OnboardingStep.v2Flow, [
            .landing, .welcome, .motivation, .body, .goal, .activity, .preferences,
            .summary, .generatingPlan, .planReveal, .savePlan
        ])
        XCTAssertEqual(OnboardingStep.v2Flow.count, 11)
    }

    func testV2FlowDoesNotIncludeLegacyPlanPreview() {
        XCTAssertFalse(OnboardingStep.v2Flow.contains(.planPreview))
    }

    func testLegacyFlowDoesNotIncludeV2OnlySteps() {
        let v2Only: [OnboardingStep] = [
            .landing, .motivation, .summary, .generatingPlan, .planReveal, .savePlan
        ]
        for step in v2Only {
            XCTAssertFalse(OnboardingStep.legacyFlow.contains(step))
        }
    }

    // MARK: - Stage mapping

    func testV2StepStageMapping() {
        XCTAssertEqual(OnboardingStep.landing.stage, .start)
        XCTAssertEqual(OnboardingStep.welcome.stage, .start)
        XCTAssertEqual(OnboardingStep.motivation.stage, .start)
        XCTAssertEqual(OnboardingStep.body.stage, .basics)
        XCTAssertEqual(OnboardingStep.goal.stage, .goal)
        XCTAssertEqual(OnboardingStep.activity.stage, .activity)
        XCTAssertEqual(OnboardingStep.preferences.stage, .preferences)
        XCTAssertEqual(OnboardingStep.summary.stage, .plan)
        XCTAssertEqual(OnboardingStep.generatingPlan.stage, .plan)
        XCTAssertEqual(OnboardingStep.planReveal.stage, .plan)
        XCTAssertEqual(OnboardingStep.savePlan.stage, .save)
    }

    func testLegacyPlanPreviewMapsToPlanStage() {
        XCTAssertEqual(OnboardingStep.planPreview.stage, .plan)
    }

    func testStepsWithinSameStageShareProgressFraction() {
        let grouped = Dictionary(grouping: OnboardingStep.v2Flow, by: \.stage)
        for (stage, steps) in grouped {
            for step in steps {
                XCTAssertEqual(step.stage.progressFraction, stage.progressFraction, "\(step) stage fraction mismatch")
            }
        }
    }

    func testSavePlanIsFinalStage() {
        XCTAssertEqual(OnboardingStep.savePlan.stage.progressIndex, OnboardingStage.stageCount)
    }

    func testV2StepsUseStageTitlesFromCopy() {
        XCTAssertEqual(OnboardingStep.landing.title, FormaProductCopy.Onboarding.V2.Landing.title)
        XCTAssertEqual(OnboardingStep.motivation.title, FormaProductCopy.Onboarding.V2.Motivation.title)
        XCTAssertEqual(OnboardingStep.body.title, FormaProductCopy.Onboarding.V2.Body.title)
        XCTAssertEqual(OnboardingStep.body.subtitle, FormaProductCopy.Onboarding.V2.Body.subtitle)
        XCTAssertEqual(OnboardingStep.goal.title, FormaProductCopy.Onboarding.V2.Goal.title)
        XCTAssertEqual(OnboardingStep.goal.subtitle, FormaProductCopy.Onboarding.V2.Goal.subtitle)
        XCTAssertEqual(OnboardingStep.activity.title, FormaProductCopy.Onboarding.V2.Activity.title)
        XCTAssertEqual(OnboardingStep.activity.subtitle, FormaProductCopy.Onboarding.V2.Activity.subtitle)
        XCTAssertEqual(OnboardingStep.preferences.title, FormaProductCopy.Onboarding.V2.Preferences.title)
        XCTAssertEqual(OnboardingStep.preferences.subtitle, FormaProductCopy.Onboarding.V2.Preferences.subtitle)
        XCTAssertEqual(OnboardingStep.summary.title, FormaProductCopy.Onboarding.V2.Summary.title)
        XCTAssertEqual(OnboardingStep.summary.subtitle, FormaProductCopy.Onboarding.V2.Summary.subtitle)
        XCTAssertEqual(OnboardingStep.summary.title, FormaProductCopy.Onboarding.V2.Summary.title)
        XCTAssertEqual(OnboardingStep.savePlan.title, FormaProductCopy.Onboarding.V2.SavePlan.title)
    }

    // MARK: - Back navigation

    func testGeneratingPlanDisallowsBackNavigationInV2() {
        XCTAssertFalse(OnboardingStep.generatingPlan.allowsBackNavigation(isV2Enabled: true))
        XCTAssertNil(OnboardingStep.generatingPlan.backTarget(isV2Enabled: true))
    }

    func testLandingDisallowsBackNavigationInV2() {
        XCTAssertFalse(OnboardingStep.landing.allowsBackNavigation(isV2Enabled: true))
    }

    func testLegacyWelcomeDisallowsBackNavigation() {
        XCTAssertFalse(OnboardingStep.welcome.allowsBackNavigation(isV2Enabled: false))
    }

    func testV2WelcomeAllowsBackToLanding() {
        XCTAssertTrue(OnboardingStep.welcome.allowsBackNavigation(isV2Enabled: true))
        XCTAssertEqual(OnboardingStep.welcome.backTarget(isV2Enabled: true), .landing)
    }

    func testPlanRevealBackTargetIsSummaryInV2() {
        XCTAssertEqual(OnboardingStep.planReveal.backTarget(isV2Enabled: true), .summary)
    }

    func testPlanRevealClearsGeneratedPlanWhenNavigatingBackInV2() {
        XCTAssertTrue(OnboardingStep.planReveal.clearsGeneratedPlanWhenNavigatingBack(isV2Enabled: true))
    }

    func testSavePlanBackTargetIsPlanRevealInV2() {
        XCTAssertEqual(OnboardingStep.savePlan.backTarget(isV2Enabled: true), .planReveal)
    }

    func testSavePlanDoesNotClearGeneratedPlanWhenNavigatingBack() {
        XCTAssertFalse(OnboardingStep.savePlan.clearsGeneratedPlanWhenNavigatingBack(isV2Enabled: true))
    }

    func testLegacyPlanPreviewClearsGeneratedPlanWhenNavigatingBack() {
        XCTAssertTrue(OnboardingStep.planPreview.clearsGeneratedPlanWhenNavigatingBack(isV2Enabled: false))
    }

    // MARK: - Policy helpers

    func testPlanReviewStepResolvesByFlow() {
        XCTAssertEqual(OnboardingStep.planReviewStep(isV2Enabled: false), .planPreview)
        XCTAssertEqual(OnboardingStep.planReviewStep(isV2Enabled: true), .planReveal)
    }

    func testFromPersistedRawValueSupportsSharedAndV2Steps() {
        XCTAssertEqual(OnboardingStep.fromPersistedRawValue(1), .body)
        XCTAssertEqual(OnboardingStep.fromPersistedRawValue(12), .summary)
        XCTAssertEqual(OnboardingStep.fromPersistedRawValue(15), .savePlan)
        XCTAssertNil(OnboardingStep.fromPersistedRawValue(999))
    }

    func testNextAndBackFollowV2Flow() {
        XCTAssertEqual(OnboardingStepPolicy.next(after: .summary, isV2Enabled: true), .generatingPlan)
        XCTAssertEqual(OnboardingStepPolicy.back(from: .savePlan, isV2Enabled: true), .planReveal)
    }

    func testNextAndBackFollowLegacyFlow() {
        XCTAssertEqual(OnboardingStepPolicy.next(after: .preferences, isV2Enabled: false), .planPreview)
        XCTAssertEqual(OnboardingStepPolicy.back(from: .goal, isV2Enabled: false), .body)
    }

    func testGeneratingPlanUsesFullScreenChrome() {
        XCTAssertTrue(OnboardingStep.generatingPlan.usesFullScreenChrome)
    }

    // MARK: - G1 exhaustive stage + chrome mapping

    func testEveryV2StepMapsToExpectedStage() {
        let expected: [OnboardingStep: OnboardingStage] = [
            .landing: .start,
            .welcome: .start,
            .motivation: .start,
            .body: .basics,
            .goal: .goal,
            .activity: .activity,
            .preferences: .preferences,
            .summary: .plan,
            .generatingPlan: .plan,
            .planReveal: .plan,
            .savePlan: .save
        ]

        for step in OnboardingStep.v2Flow {
            XCTAssertEqual(step.stage, expected[step], "Unexpected stage for \(step)")
        }
    }

    func testEveryLegacyStepMapsToExpectedStage() {
        let expected: [OnboardingStep: OnboardingStage] = [
            .welcome: .start,
            .body: .basics,
            .goal: .goal,
            .activity: .activity,
            .preferences: .preferences,
            .planPreview: .plan
        ]

        for step in OnboardingStep.legacyFlow {
            XCTAssertEqual(step.stage, expected[step], "Unexpected stage for \(step)")
        }
    }

    func testProgressHeaderVisibilityForGeneratingAndSavePlan() {
        XCTAssertFalse(OnboardingStep.landing.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.generatingPlan.showsProgressHeader)
        XCTAssertTrue(OnboardingStep.savePlan.showsProgressHeader)
        XCTAssertTrue(OnboardingStep.summary.showsProgressHeader)
        XCTAssertTrue(OnboardingStep.planReveal.showsProgressHeader)
    }

    func testSavePlanUsesStandardBottomBarChrome() {
        XCTAssertFalse(OnboardingStep.savePlan.usesFullScreenChrome)
        XCTAssertTrue(OnboardingStep.savePlan.showsProgressHeader)
    }
}
