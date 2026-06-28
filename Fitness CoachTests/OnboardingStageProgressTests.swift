//
//  OnboardingStageProgressTests.swift
//  Fitness CoachTests
//
//  Forma — Onboarding stage mapping and navigation policy tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingStageProgressTests: XCTestCase {

    func testStepStageMapping() {
        XCTAssertEqual(OnboardingStep.introProof.stage, .start)
        XCTAssertEqual(OnboardingStep.heightWeight.stage, .body)
        XCTAssertEqual(OnboardingStep.targetWeight.stage, .destination)
        XCTAssertEqual(OnboardingStep.activityLevel.stage, .activity)
        XCTAssertEqual(OnboardingStep.formaProof.stage, .proof)
        XCTAssertEqual(OnboardingStep.review.stage, .plan)
        XCTAssertEqual(OnboardingStep.savePlan.stage, .save)
    }

    func testSavePlanIsFinalStage() {
        XCTAssertEqual(OnboardingStep.savePlan.stage.progressIndex, OnboardingStage.stageCount)
    }

    func testGeneratingPlanDisallowsBackNavigation() {
        XCTAssertFalse(
            OnboardingStep.generatingPlan.allowsBackNavigation(in: OnboardingStep.flow)
        )
    }

    func testPlanRevealBackTargetIsReview() {
        XCTAssertEqual(
            OnboardingStep.planReveal.backTarget(in: OnboardingStep.flow),
            .review
        )
    }

    func testPlanRevealClearsGeneratedPlanWhenNavigatingBack() {
        XCTAssertTrue(
            OnboardingStep.planReveal.clearsGeneratedPlanWhenNavigatingBack(in: OnboardingStep.flow)
        )
    }

    func testNextAndBackFollowFlow() {
        XCTAssertEqual(OnboardingStepPolicy.next(after: .review), .generatingPlan)
        XCTAssertEqual(OnboardingStepPolicy.back(from: .savePlan, notBefore: .introProof), .planReveal)
    }

    func testPostAuthEntryBlocksBackNavigationToIntroProof() {
        XCTAssertFalse(
            OnboardingStep.heightWeight.allowsBackNavigation(
                in: OnboardingStep.flow,
                notBefore: .heightWeight
            )
        )
        XCTAssertTrue(
            OnboardingStep.targetWeight.allowsBackNavigation(
                in: OnboardingStep.flow,
                notBefore: .heightWeight
            )
        )
    }

    func testGeneratingPlanUsesFullScreenChrome() {
        XCTAssertTrue(OnboardingStep.generatingPlan.usesFullScreenChrome)
        XCTAssertFalse(OnboardingStep.introProof.usesFullScreenChrome)
    }

    func testProgressHeaderVisibility() {
        XCTAssertFalse(OnboardingStep.introProof.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.heightWeight.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.targetWeight.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.birthday.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.activityLevel.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.appleHealth.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.almostThere.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.generatingPlan.showsProgressHeader)
        XCTAssertFalse(OnboardingStep.savePlan.showsProgressHeader)
    }

    func testGeneratingPlanTimingMatchesChecklist() {
        XCTAssertEqual(
            OnboardingGeneratingPlanTiming.intervalsAfterReveal.count,
            FormaProductCopy.Onboarding.V2.Generating.checklist.count
        )
        XCTAssertEqual(
            OnboardingModel.minimumGenerationDisplayDuration,
            OnboardingGeneratingPlanTiming.minimumDisplayDuration
        )
        XCTAssertGreaterThanOrEqual(OnboardingGeneratingPlanTiming.minimumDisplayDuration, 2.5)
    }
}
