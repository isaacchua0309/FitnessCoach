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
        let state = makeState(
            goalType: .loseFat,
            currentWeightKg: 80,
            goalWeightKg: 70,
            weeklyPaceKg: 1.0
        )

        XCTAssertEqual(state.motivationalLine, FormaProductCopy.PlanEditHero.motivationalFatLoss)
        XCTAssertEqual(state.goalValue, PlanGoalType.loseFat.rawValue)
        XCTAssertEqual(state.currentWeight, "80 kg")
        XCTAssertEqual(state.targetWeight, "70 kg")
        XCTAssertEqual(state.totalChangeLine, "10 kg to your target.")
        XCTAssertEqual(state.estimatedFinishLine, "Estimated finish: March 2026.")
        XCTAssertTrue(state.accessibilitySummary.contains("10 kg to your target."))
    }

    func testMaintenanceHeroOmitsEstimatedFinish() {
        let state = makeState(
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
        let state = makeState(
            goalType: .gainMuscle,
            currentWeightKg: 70,
            goalWeightKg: 73,
            weeklyPaceKg: nil
        )

        XCTAssertEqual(state.motivationalLine, FormaProductCopy.PlanEditHero.motivationalMuscleGain)
        XCTAssertEqual(state.totalChangeLine, "3 kg to your target.")
        XCTAssertNil(state.estimatedFinishLine)
    }

    func testGoalDatePaceUsesProvidedDate() {
        let goalDate = calendar.date(from: DateComponents(year: 2027, month: 3, day: 1))!
        let state = makeState(
            goalType: .loseFat,
            currentWeightKg: 80,
            goalWeightKg: 72,
            weeklyPaceKg: nil,
            goalDatePace: goalDate
        )

        XCTAssertEqual(state.estimatedFinishLine, "Estimated finish: March 2027.")
    }

    func testMissingWeightsUseUnavailablePlaceholder() {
        let state = makeState(
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

    private func makeState(
        goalType: PlanGoalType,
        currentWeightKg: Double?,
        goalWeightKg: Double?,
        weeklyPaceKg: Double?,
        goalDatePace: Date? = nil
    ) -> PlanEditHeroState {
        PlanEditHeroStateBuilder.build(
            input: PlanEditHeroStateBuilder.Input(
                goalType: goalType,
                currentWeightKg: currentWeightKg,
                goalWeightKg: goalWeightKg,
                weeklyPaceKg: weeklyPaceKg,
                goalDatePace: goalDatePace,
                referenceDate: referenceDate,
                calendar: calendar
            )
        )
    }
}
