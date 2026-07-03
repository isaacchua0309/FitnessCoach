//
//  PlanEditWizardStepGateTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class PlanEditWizardStepGateTests: XCTestCase {

    func testSaveDisabledWhenNoChanges() {
        let profile = PlanMissionControlFixtures.loseProfile
        let formState = PlanFormState(profile: profile)

        XCTAssertFalse(
            PlanEditWizardStepGate.canSave(
                targetPreview: PlanPreviewData.generatedPreview,
                reviewHasChanges: false,
                isSaving: false
            )
        )
        XCTAssertTrue(
            PlanEditWizardStepGate.hasUnsavedChanges(
                baseline: profile,
                formState: formState
            ) == false
        )
    }

    func testSaveEnabledWhenReviewHasChanges() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "70"

        XCTAssertTrue(
            PlanEditWizardStepGate.canSave(
                targetPreview: PlanPreviewData.generatedPreview,
                reviewHasChanges: true,
                isSaving: false
            )
        )
    }

    func testGoalStepBlocksInvalidGoalWeight() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.goalWeightKgText = "90"

        let message = PlanGoalWeightValidationBuilder.validate(
            goalWeightText: formState.goalWeightKgText,
            currentWeightKg: 80,
            heightCm: 170,
            goalType: .loseFat
        )

        XCTAssertFalse(
            PlanEditWizardStepGate.canAdvance(
                from: .goalAndTargetWeight,
                formState: formState,
                goalType: .loseFat,
                goalWeightValidationMessage: message,
                pacePreview: .empty
            )
        )
    }

    func testGainGoalStepDoesNotRequirePaceSaveable() {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)

        XCTAssertTrue(
            PlanEditWizardStepGate.canAdvance(
                from: .goalAndTargetWeight,
                formState: formState,
                goalType: .gainMuscle,
                goalWeightValidationMessage: nil,
                pacePreview: WeightLossPacePreviewModel(
                    weeklyLossKg: nil,
                    monthlyLossKg: nil,
                    dailyDeficitKcal: nil,
                    safetyDisplay: nil,
                    warningMessage: nil,
                    deficitSummaryLine: nil,
                    isSaveable: false,
                    validationError: "blocked"
                )
            )
        )
    }

    func testWarnsWhenActivityChangedAfterCustomPace() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .advanced
        formState.customPaceActivityLevel = .moderatelyActive
        formState.selectActivityLevel(.veryActive)

        XCTAssertTrue(
            PlanEditWizardStepGate.shouldWarnCustomPaceAfterActivityChange(formState: formState)
        )
    }

    func testNonCutGoalShowsPaceNoticeForAdvancedChoice() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .advanced

        XCTAssertEqual(
            PlanEditWizardStepGate.nonCutPaceNotice(goalType: .gainMuscle, formState: formState),
            FormaProductCopy.PlanEditPace.gainGoalIgnoresCutPace
        )
    }

    func testResetPaceForNonCutGoalClearsCustomCapture() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.weightLossPaceChoice = .advanced
        formState.customPaceActivityLevel = .moderatelyActive

        formState.resetPaceForNonCutGoal()

        XCTAssertEqual(formState.weightLossPaceChoice, .moderate)
        XCTAssertNil(formState.customPaceActivityLevel)
    }
}
