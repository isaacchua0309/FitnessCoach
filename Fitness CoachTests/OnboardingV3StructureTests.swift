//
//  OnboardingV3StructureTests.swift
//  Fitness CoachTests
//
//  Forma — Tap-first onboarding v3 structure and interaction policy tests.
//

import XCTest
@testable import Fitness_Coach

final class OnboardingV3StructureTests: XCTestCase {

    private var v3FlagPrevious: Bool?
    private var v4FlagPrevious: Bool?

    override func setUp() {
        super.setUp()
        v3FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV3FeatureFlag.enabledKey) as? Bool
        v4FlagPrevious = UserDefaults.standard.object(forKey: OnboardingV4FeatureFlag.enabledKey) as? Bool
        UserDefaults.standard.set(true, forKey: OnboardingV2FeatureFlag.enabledKey)
        UserDefaults.standard.set(true, forKey: OnboardingV3FeatureFlag.enabledKey)
        UserDefaults.standard.set(false, forKey: OnboardingV4FeatureFlag.enabledKey)
    }

    override func tearDown() {
        if let v3FlagPrevious {
            UserDefaults.standard.set(v3FlagPrevious, forKey: OnboardingV3FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV3FeatureFlag.enabledKey)
        }
        if let v4FlagPrevious {
            UserDefaults.standard.set(v4FlagPrevious, forKey: OnboardingV4FeatureFlag.enabledKey)
        } else {
            UserDefaults.standard.removeObject(forKey: OnboardingV4FeatureFlag.enabledKey)
        }
        super.tearDown()
    }

    func testV3EnabledByDefaultWhenKeyAbsent() {
        UserDefaults.standard.removeObject(forKey: OnboardingV3FeatureFlag.enabledKey)
        XCTAssertTrue(OnboardingV3FeatureFlag.isEnabled)
    }

    func testPlanRevealAndSaveHideProgressHeader() {
        XCTAssertFalse(OnboardingV3Step.planReveal.showsProgressHeader)
        XCTAssertFalse(OnboardingV3Step.savePlan.showsProgressHeader)
        XCTAssertTrue(OnboardingV3Step.review.showsProgressHeader)
    }

    func testV3PlanRevealCopyUsesConversionFocusedStrings() {
        XCTAssertEqual(
            OnboardingV3Step.planReveal.title,
            FormaProductCopy.Onboarding.V3.PlanReveal.title
        )
        XCTAssertEqual(
            OnboardingV3Step.savePlan.title,
            FormaProductCopy.Onboarding.V3.SavePlan.title
        )
    }

    func testFullV3FlowOrder() {
        XCTAssertEqual(OnboardingV3Step.fullFlow, [
            .landing, .motivation,
            .bodyBasics,
            .goalWeight,
            .activityLevel, .trainingRhythm,
            .preferences,
            .review, .generatingPlan, .planReveal, .savePlan
        ])
    }

    func testV3FlowSkipsWelcome() {
        XCTAssertEqual(OnboardingV3Step.fullFlow.first, .landing)
        XCTAssertEqual(OnboardingV3Step.fullFlow[1], .motivation)
    }

    func testMaintainGoalSkipsPaceValidationOnDestinationStep() {
        var form = OnboardingFormState()
        form.currentWeightKgText = "70"
        form.goalWeightKgText = "70"

        XCTAssertEqual(
            OnboardingV3Step.goalWeight.next(in: OnboardingV3Step.fullFlow, formState: form, session: .init()),
            .activityLevel
        )
        XCTAssertTrue(form.canAdvanceV3(from: .goalWeight))
        XCTAssertFalse(form.isPaceApplicable())
    }

    func testInteractionPolicyDisallowsKeyboardOnRequiredBodySteps() {
        XCTAssertFalse(
            OnboardingV3InteractionPolicy.rules(for: .bodyBasics).allowsKeyboardForRequiredInput
        )
        for step in [OnboardingV3Step.goalWeight] {
            XCTAssertFalse(OnboardingV3InteractionPolicy.rules(for: step).allowsKeyboardForRequiredInput)
        }
    }

    func testDraftBridgeMapsBodyBasicsToLegacyBody() {
        XCTAssertEqual(
            OnboardingV3DraftBridge.persistedLegacyStep(for: .bodyBasics, formState: OnboardingFormState()),
            .body
        )
    }

    func testInteractionPolicyMarksMotivationOptional() {
        let rules = OnboardingV3InteractionPolicy.rules(for: .motivation)
        XCTAssertTrue(rules.isOptional)
        XCTAssertFalse(rules.validatesOnContinue)
    }

    func testDailyStepsBandMapsToStoredSteps() {
        var form = OnboardingFormState()
        form.dailyStepsBand = .high
        XCTAssertEqual(form.averageStepsText, "9000")
        XCTAssertEqual(form.dailyStepsBand, .high)
    }

    func testDraftBridgeMapsBodySubStepsToLegacyBody() {
        XCTAssertEqual(
            OnboardingV3DraftBridge.persistedLegacyStep(for: .height, formState: OnboardingFormState()),
            .body
        )
        XCTAssertEqual(
            OnboardingV3DraftBridge.persistedLegacyStep(for: .review, formState: OnboardingFormState()),
            .summary
        )
    }

    func testFlowScopeUsesV3WhenFlagActiveAndV4Off() {
        UserDefaults.standard.set(false, forKey: OnboardingV4FeatureFlag.enabledKey)
        let scope = OnboardingFlowScope.v2Full
        XCTAssertTrue(scope.usesV3Steps)
        XCTAssertFalse(scope.usesV4Steps)
        XCTAssertEqual(scope.entryV3Step, .landing)
    }

    func testVisiblePaceChoicesExcludeAdvanced() {
        XCTAssertEqual(
            OnboardingV3InteractionPolicy.visiblePaceChoices,
            [.gentle, .moderate, .aggressive]
        )
    }
}
