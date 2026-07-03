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

    func testBirthdayAndSexStepRequiresBothFields() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.birthDate = nil
        formState.sex = .preferNotToSay

        XCTAssertFalse(
            PlanEditWizardStepGate.canAdvance(
                from: .birthdayAndSex,
                formState: formState,
                goalType: .loseFat,
                goalWeightValidationMessage: nil,
                pacePreview: .empty
            )
        )

        formState.birthDate = Calendar.current.date(from: DateComponents(year: 1995, month: 5, day: 10))
        formState.sex = .female

        XCTAssertTrue(
            PlanEditWizardStepGate.canAdvance(
                from: .birthdayAndSex,
                formState: formState,
                goalType: .loseFat,
                goalWeightValidationMessage: nil,
                pacePreview: .empty
            )
        )
    }

    func testBodyBaselineStepBlocksInvalidHeightOrWeight() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.heightCmText = "abc"

        let validation = PlanBodyBaselineValidationBuilder.validate(
            heightText: formState.heightCmText,
            weightText: formState.currentWeightKgText
        )

        XCTAssertFalse(
            PlanEditWizardStepGate.canAdvance(
                from: .heightAndWeight,
                formState: formState,
                goalType: .loseFat,
                goalWeightValidationMessage: nil,
                pacePreview: .empty
            )
        )
        XCTAssertNotNil(validation.heightMessage)
    }
}
