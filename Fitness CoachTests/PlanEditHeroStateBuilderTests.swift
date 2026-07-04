//
//  PlanEditHeroStateBuilderTests.swift
//  Fitness CoachTests
//
//  Forma — Edit Plan hero card state builder tests.
//

import XCTest
@testable import Fitness_Coach

final class PlanEditHeroStateBuilderTests: XCTestCase {

    private var calendar: Calendar!
    private var referenceDate: Date!

    override func setUp() {
        super.setUp()
        calendar = Calendar(identifier: .gregorian)
        referenceDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    func testFatLossHeroIncludesMotivationChangeAndEstimatedFinish() {
        let state = makeHeroState(
            goalType: .loseFat,
            currentWeightKg: 80,
            goalWeightKg: 70,
            weeklyPaceKg: 1.0
        )

        XCTAssertEqual(state.motivationalLine, FormaProductCopy.PlanEditHero.motivationalFatLoss)
        XCTAssertEqual(state.goalValue, PlanGoalSelectionBuilder.displayTitle(for: .loseFat))
        XCTAssertEqual(state.currentWeight, "80 kg")
        XCTAssertEqual(state.targetWeight, "70 kg")
        XCTAssertEqual(state.totalChangeLine, "10 kg between now and your goal.")
        XCTAssertEqual(state.estimatedFinishLine, "On track for March 2026.")
        XCTAssertTrue(state.accessibilitySummary.contains("10 kg between now and your goal."))
    }

    func testMaintenanceHeroOmitsEstimatedFinish() {
        let state = makeHeroState(
            goalType: .maintain,
            currentWeightKg: 75,
            goalWeightKg: 75,
            weeklyPaceKg: 0.5
        )

        XCTAssertEqual(state.motivationalLine, FormaProductCopy.PlanEditHero.motivationalMaintenance)
        XCTAssertEqual(state.totalChangeLine, FormaProductCopy.PlanEditHero.maintainingTarget)
        XCTAssertNil(state.estimatedFinishLine)
    }

    func testMuscleGainHeroShowsGainDelta() {
        let state = makeHeroState(
            goalType: .gainMuscle,
            currentWeightKg: 70,
            goalWeightKg: 73,
            weeklyPaceKg: nil
        )

        XCTAssertEqual(state.motivationalLine, FormaProductCopy.PlanEditHero.motivationalMuscleGain)
        XCTAssertEqual(state.totalChangeLine, "3 kg between now and your goal.")
        XCTAssertNil(state.estimatedFinishLine)
    }

    func testGoalDatePaceUsesProvidedDate() {
        let goalDate = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1))!
        let projection = makeProjection(
            goalType: .loseFat,
            currentWeightKg: 80,
            goalWeightKg: 72,
            weeklyPaceKg: nil,
            goalDatePace: goalDate
        )
        let state = PlanEditHeroStateBuilder.build(projection: projection)

        XCTAssertEqual(state.estimatedFinishLine, "On track for March 2027.")
    }

    func testMissingWeightsUseUnavailablePlaceholder() {
        let state = makeHeroState(
            goalType: .loseFat,
            currentWeightKg: nil,
            goalWeightKg: nil,
            weeklyPaceKg: nil
        )

        XCTAssertEqual(state.currentWeight, FormaProductCopy.PlanEditHero.weightUnavailable)
        XCTAssertEqual(state.targetWeight, FormaProductCopy.PlanEditHero.weightUnavailable)
        XCTAssertNil(state.totalChangeLine)
        XCTAssertNil(state.estimatedFinishLine)
    }

    // MARK: - Helpers

    private func makeHeroState(
        goalType: PlanGoalType,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        weeklyPaceKg: Double?,
        goalDatePace: Date? = nil
    ) -> PlanEditHeroState {
        let projection = makeProjection(
            goalType: goalType,
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            weeklyPaceKg: weeklyPaceKg,
            goalDatePace: goalDatePace
        )
        return PlanEditHeroStateBuilder.build(projection: projection)
    }

    private func makeProjection(
        goalType: PlanGoalType,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        weeklyPaceKg: Double?,
        goalDatePace: Date? = nil
    ) -> PlanProjection {
        var formState = formState(
            currentWeightKg: currentWeightKg,
            goalWeightKg: goalWeightKg,
            weeklyPaceKg: weeklyPaceKg
        )
        if let weeklyPaceKg, weeklyPaceKg > 0 {
            formState.weightLossPaceChoice = .advanced
            formState.advancedPaceDraft = WeightLossAdvancedPaceDraft(
                period: .weekly,
                amountText: formatPaceAmount(weeklyPaceKg)
            )
        }

        return PlanProjectionBuilder.build(
            input: PlanProjectionInput(
                goalType: goalType,
                formState: formState,
                caloriePreview: nil,
                goalDatePaceOverride: goalDatePace,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }

    private func formState(
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        weeklyPaceKg: Double?
    ) -> PlanFormState {
        var state = PlanFormState(profile: PlanMissionControlFixtures.loseProfile)
        if let currentWeightKg {
            state.currentWeightKgText = formatWeight(currentWeightKg)
        } else {
            state.currentWeightKgText = ""
        }
        if let goalWeightKg {
            state.goalWeightKgText = formatWeight(goalWeightKg)
        } else {
            state.goalWeightKgText = ""
        }
        if weeklyPaceKg != nil {
            state.weightLossPaceChoice = .moderate
        }
        return state
    }

    private func formatWeight(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }

    private func formatPaceAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? "\(Int(value))"
            : "\(value)"
    }
}
