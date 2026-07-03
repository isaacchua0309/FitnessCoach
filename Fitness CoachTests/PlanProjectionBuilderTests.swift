//
//  PlanProjectionBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — PlanProjection builder edge cases.
//

import XCTest
@testable import Fitness_Coach

final class PlanProjectionBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    func testCompleteProfileProducesEngineBackedProjection() throws {
        let formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertTrue(projection.isCalculationComplete)
        XCTAssertNil(projection.validationMessage)
        XCTAssertEqual(projection.goalLabel, PlanGoalSelectionBuilder.displayTitle(for: .loseFat))
        XCTAssertEqual(projection.goalDirection, .cut)
        XCTAssertNotNil(projection.maintenanceCalories)
        XCTAssertNotNil(projection.targetCalories)
        XCTAssertNotNil(projection.proteinTargetG)
        XCTAssertNotNil(projection.waterTargetMl)
        XCTAssertFalse(projection.difficultyLabel.isEmpty)
        XCTAssertFalse(projection.adherenceEstimate.isEmpty)
    }

    func testIncompleteInputsReturnGracefulProjection() {
        var formState = PlanFormState.defaultDraftValues()
        formState.currentWeightKgText = ""
        formState.goalWeightKgText = ""
        formState.heightCmText = ""

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertFalse(projection.isCalculationComplete)
        XCTAssertEqual(projection.validationMessage, FormaProductCopy.PlanProjection.incompleteCalculation)
        XCTAssertEqual(projection.currentWeightDisplay, FormaProductCopy.PlanEditHero.weightUnavailable)
        XCTAssertNil(projection.targetCalories)
    }

    func testFatLossTimelineUsesWeeklyPace() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"
        formState.weightLossPaceChoice = .advanced
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "1"
        )

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(projection.weightToLoseOrGainKg, 10)
        XCTAssertEqual(projection.weeklyRateKg, 1.0)
        XCTAssertEqual(projection.estimatedWeeks, 10)
        XCTAssertEqual(projection.estimatedCompletionLabel, "On track for March 2026.")
        XCTAssertNotNil(projection.monthlyRateKg)
    }

    func testMaintenanceProjectionHasNeutralEnergyBalance() throws {
        var profile = PlanMissionControlFixtures.loseProfile
        profile.currentWeightKg = 75
        profile.goalWeightKg = 75
        let formState = PlanFormState(profile: profile)

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .maintain,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(projection.goalDirection, .maintain)
        XCTAssertNil(projection.weightToLoseOrGainKg)
        XCTAssertEqual(projection.weightChangeLabel, FormaProductCopy.PlanEditHero.maintainingTarget)
        XCTAssertNil(projection.estimatedWeeks)
        XCTAssertEqual(projection.dailyDeficitOrSurplusKcal, 0)
        XCTAssertEqual(
            projection.dailyDeficitOrSurplusLabel,
            FormaProductCopy.PlanProjection.dailyBalanceNeutral
        )
    }

    func testCaloriePreviewFillsTargetsWhenEngineUnavailable() {
        var formState = PlanFormState.defaultDraftValues()
        formState.sex = .preferNotToSay
        formState.birthDate = nil
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"

        let preview = PlanPreviewData.generatedPreview
        let projection = PlanProjectionBuilder.build(
            input: PlanProjectionInput(
                goalType: .loseFat,
                formState: formState,
                caloriePreview: preview,
                goalDatePaceOverride: nil,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )

        XCTAssertFalse(projection.isCalculationComplete)
        XCTAssertEqual(projection.targetCalories, preview.targets.calorieTarget)
        XCTAssertEqual(projection.maintenanceCalories, preview.estimatedTDEE)
        XCTAssertEqual(projection.proteinTargetG, preview.targets.proteinTarget)
    }

    func testDifficultyLabelsAreUserFriendlyNotRawIDs() {
        let projection = PlanProjectionBuilder.build(
            formState: PlanFormState(profile: PlanMissionControlFixtures.loseProfile),
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertFalse(projection.difficultyLabel.contains("loseFat"))
        XCTAssertFalse(projection.difficultyLabel.contains("aggressiveDeficit"))
        let difficulty = FormaProductCopy.PlanEditDifficulty.self
        XCTAssertTrue(
            projection.difficultyLabel == difficulty.gentleCut
                || projection.difficultyLabel == difficulty.moderateCut
                || projection.difficultyLabel == difficulty.fasterCut
                || projection.difficultyLabel == difficulty.customCut
        )
    }

    func testZeroWeeklyPaceOmitsEstimatedCompletion() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "80"
        formState.goalWeightKgText = "70"
        formState.weightLossPaceChoice = .advanced
        formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(
            period: .weekly,
            amountText: "0"
        )

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .loseFat,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertNil(projection.estimatedWeeks)
        XCTAssertNil(projection.estimatedCompletionDate)
        XCTAssertNil(projection.estimatedCompletionLabel)
    }

    func testGainProjectionUsesPositiveWeightDelta() {
        var formState = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        formState.currentWeightKgText = "70"
        formState.goalWeightKgText = "73"

        let projection = PlanProjectionBuilder.build(
            formState: formState,
            goalType: .gainMuscle,
            referenceDate: referenceDate,
            calendar: calendar
        )

        XCTAssertEqual(projection.weightToLoseOrGainKg, 3)
        XCTAssertEqual(projection.weightChangeLabel, "3 kg between now and your goal.")
        XCTAssertEqual(projection.goalLabel, PlanGoalSelectionBuilder.displayTitle(for: .gainMuscle))
    }
}
