//
//  EndOfDayWrapUpEngineTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class EndOfDayWrapUpEngineTests: XCTestCase {

    func testHiddenBeforeEveningThreshold() {
        let morning = TodayDashboardFixtures.date(hour: 9)
        let wrapUp = resolve(
            date: morning,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 79,
            waterConsumedMl: 1_200,
            calorieConsumed: 710
        )

        XCTAssertFalse(wrapUp.isVisible)
        XCTAssertEqual(wrapUp, .hidden)
    }

    func testShowsAfterEveningThreshold() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let wrapUp = resolve(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 79,
            waterConsumedMl: 1_200,
            calorieConsumed: 710
        )

        XCTAssertTrue(wrapUp.isVisible)
        XCTAssertEqual(wrapUp.sectionTitle, FormaProductCopy.Today.EndOfDay.sectionTitle)
    }

    func testCompletedDayStateShowsGreatWork() {
        let evening = TodayDashboardFixtures.date(hour: 21)
        let wrapUp = resolve(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 165,
            waterConsumedMl: 3_400,
            calorieConsumed: 1_400,
            hasWorkout: true,
            appleHealthWorkoutCount: 1
        )

        XCTAssertEqual(wrapUp.overallMessage, FormaProductCopy.Today.EndOfDay.overallGreatWork)
        XCTAssertNil(wrapUp.noLogsMessage)
        XCTAssertEqual(wrapUp.rows.count, 4)
        XCTAssertEqual(wrapUp.rows[3].valueText, FormaProductCopy.Today.EndOfDay.workoutCompleted)
        XCTAssertEqual(wrapUp.journeyActionTitle, FormaProductCopy.Today.EndOfDay.seeJourneyAction)
    }

    func testPartialDayStateShowsGoodStart() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let wrapUp = resolve(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 79,
            waterConsumedMl: 1_200,
            calorieConsumed: 710,
            calorieProgress: 0.39
        )

        XCTAssertEqual(wrapUp.overallMessage, FormaProductCopy.Today.EndOfDay.overallGoodStart)
        XCTAssertEqual(wrapUp.rows[0].status, .partial)
        XCTAssertEqual(wrapUp.rows[1].status, .partial)
    }

    func testPartialDayWithLaterProgressShowsStillTime() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let wrapUp = resolve(
            date: evening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 120,
            waterConsumedMl: 2_000,
            calorieConsumed: 1_200,
            calorieProgress: 0.67
        )

        XCTAssertEqual(wrapUp.overallMessage, FormaProductCopy.Today.EndOfDay.overallStillTime)
    }

    func testNoLogsStateShowsEncouragement() {
        let evening = TodayDashboardFixtures.date(hour: 20)
        let wrapUp = resolve(
            date: evening,
            foodEntries: [],
            proteinConsumed: 0,
            waterConsumedMl: 0,
            calorieConsumed: 0,
            hasWorkout: false
        )

        XCTAssertTrue(wrapUp.isVisible)
        XCTAssertEqual(wrapUp.noLogsMessage, FormaProductCopy.Today.EndOfDay.noLogsMessage)
        XCTAssertNil(wrapUp.overallMessage)
        XCTAssertTrue(wrapUp.rows.isEmpty)
    }

    func testHourBeforeEightPMStaysHidden() {
        let beforeEvening = TodayDashboardFixtures.date(hour: 19)
        let wrapUp = resolve(
            date: beforeEvening,
            foodEntries: TodayPreviewData.foodEntries,
            proteinConsumed: 79,
            waterConsumedMl: 1_200,
            calorieConsumed: 710
        )

        XCTAssertFalse(wrapUp.isVisible)
    }

    // MARK: - Fixtures

    private func resolve(
        date: Date,
        foodEntries: [FoodEntry],
        proteinConsumed: Double,
        proteinTarget: Double = 170,
        waterConsumedMl: Int,
        waterTargetMl: Int = 3_500,
        calorieConsumed: Int,
        calorieTarget: Int = 1_800,
        calorieProgress: Double? = nil,
        hasWorkout: Bool = false,
        appleHealthWorkoutCount: Int? = nil,
        weightLoggedToday: Bool = false
    ) -> TodayEndOfDayState {
        let proteinRemaining = max(proteinTarget - proteinConsumed, 0)
        let waterRemaining = max(waterTargetMl - waterConsumedMl, 0)
        let remaining = max(calorieTarget - calorieConsumed, 0)
        let progress = calorieProgress ?? (calorieTarget > 0 ? Double(calorieConsumed) / Double(calorieTarget) : 0)

        return EndOfDayWrapUpEngine.resolve(
            EndOfDayWrapUpInput(
                date: date,
                calendar: Calendar(identifier: .gregorian),
                foodEntries: foodEntries,
                calorieSummary: CalorieSummary(
                    consumed: calorieConsumed,
                    target: calorieTarget,
                    remaining: remaining,
                    progress: progress,
                    isOverTarget: calorieConsumed > calorieTarget
                ),
                proteinProgress: MacroProgress(
                    consumed: proteinConsumed,
                    target: proteinTarget,
                    remaining: proteinRemaining,
                    progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                ),
                waterSummary: WaterSummary(
                    consumedMl: waterConsumedMl,
                    targetMl: waterTargetMl,
                    remainingMl: waterRemaining,
                    progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
                ),
                workoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                activityContext: TodayActivityContext(
                    trainingIntegration: .connected,
                    trainingDataSource: .appleHealth,
                    appleHealthWorkoutCount: appleHealthWorkoutCount,
                    stepsToday: nil
                ),
                weightLoggedToday: weightLoggedToday
            )
        )
    }
}
