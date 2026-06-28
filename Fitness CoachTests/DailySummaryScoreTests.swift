//
//  DailySummaryScoreTests.swift
//  Fitness CoachTests
//

import XCTest
@testable import Fitness_Coach

final class DailySummaryScoreTests: XCTestCase {

    func testEmptyDayScoresZeroWithAllTargetsNotMet() {
        let scorecard = TodayDailySummaryScoring.scorecard(from: makeInput(
            caloriesConsumed: 0,
            caloriesTarget: 1_800,
            proteinConsumed: 0,
            proteinTarget: 170,
            waterConsumedMl: 0,
            waterTargetMl: 3_500,
            hasWorkout: false,
            trainingFrequencyPerWeek: 4
        ))

        XCTAssertEqual(scorecard.overallPercent, 0)
        XCTAssertEqual(scorecard.items.count, 4)
        XCTAssertTrue(scorecard.items.allSatisfy { $0.status == .notMet })
    }

    func testPartialDayScoresShareOfMetTargets() {
        let scorecard = TodayDailySummaryScoring.scorecard(from: makeInput(
            caloriesConsumed: 1_720,
            caloriesTarget: 1_800,
            proteinConsumed: 165,
            proteinTarget: 170,
            waterConsumedMl: 1_200,
            waterTargetMl: 3_500,
            hasWorkout: true,
            appleHealthWorkoutCount: 1,
            trainingFrequencyPerWeek: 4
        ))

        XCTAssertEqual(status(for: .calories, in: scorecard), .met)
        XCTAssertEqual(status(for: .protein, in: scorecard), .met)
        XCTAssertEqual(status(for: .water, in: scorecard), .notMet)
        XCTAssertEqual(status(for: .workout, in: scorecard), .met)
        XCTAssertEqual(scorecard.overallPercent, 75)
    }

    func testCompleteDayScoresOneHundredPercent() {
        let scorecard = TodayDailySummaryScoring.scorecard(from: makeInput(
            caloriesConsumed: 1_750,
            caloriesTarget: 1_800,
            proteinConsumed: 175,
            proteinTarget: 180,
            waterConsumedMl: 3_100,
            waterTargetMl: 3_150,
            hasWorkout: true,
            appleHealthWorkoutCount: 1,
            trainingFrequencyPerWeek: 4
        ))

        XCTAssertEqual(scorecard.overallPercent, 100)
        XCTAssertTrue(scorecard.items.allSatisfy { $0.status == .met })
    }

    func testOverCaloriesButProteinMetDoesNotZeroOverallScore() {
        let scorecard = TodayDailySummaryScoring.scorecard(from: makeInput(
            caloriesConsumed: 2_100,
            caloriesTarget: 1_800,
            proteinConsumed: 175,
            proteinTarget: 180,
            waterConsumedMl: 3_100,
            waterTargetMl: 3_150,
            hasWorkout: true,
            appleHealthWorkoutCount: 1,
            trainingFrequencyPerWeek: 4
        ))

        XCTAssertEqual(status(for: .calories, in: scorecard), .notMet)
        XCTAssertEqual(status(for: .protein, in: scorecard), .met)
        XCTAssertEqual(status(for: .water, in: scorecard), .met)
        XCTAssertEqual(status(for: .workout, in: scorecard), .met)
        XCTAssertEqual(scorecard.overallPercent, 75)
    }

    func testNoWorkoutTargetOmitsWorkoutFromScore() {
        let scorecard = TodayDailySummaryScoring.scorecard(from: makeInput(
            caloriesConsumed: 1_750,
            caloriesTarget: 1_800,
            proteinConsumed: 175,
            proteinTarget: 180,
            waterConsumedMl: 3_100,
            waterTargetMl: 3_150,
            hasWorkout: false,
            trainingFrequencyPerWeek: nil
        ))

        XCTAssertEqual(scorecard.items.count, 3)
        XCTAssertNil(scorecard.items.first(where: { $0.kind == .workout }))
        XCTAssertEqual(scorecard.overallPercent, 100)
    }

    func testCaloriesWithinTenPercentToleranceCountsAsMet() {
        XCTAssertEqual(
            TodayDailySummaryScoring.caloriesStatus(
                CalorieSummary(consumed: 1_950, target: 1_800, remaining: 0, progress: 1.08, isOverTarget: true)
            ),
            .met
        )
    }

    func testBuilderAttachesScorecardToDashboardState() {
        let state = TodayDashboardFixtures.completeDay()

        XCTAssertEqual(state.dailyScorecard.overallPercent, 100)
        XCTAssertEqual(state.dailyScorecard.items.count, 3)
    }

    // MARK: - Helpers

    private func makeInput(
        caloriesConsumed: Int,
        caloriesTarget: Int,
        proteinConsumed: Double,
        proteinTarget: Double,
        waterConsumedMl: Int,
        waterTargetMl: Int,
        hasWorkout: Bool,
        appleHealthWorkoutCount: Int? = nil,
        trainingFrequencyPerWeek: Int?
    ) -> TodayDailySummaryScoreInput {
        TodayDailySummaryScoreInput(
            calorieSummary: CalorieSummary(
                consumed: caloriesConsumed,
                target: caloriesTarget,
                remaining: max(caloriesTarget - caloriesConsumed, 0),
                progress: caloriesTarget > 0 ? Double(caloriesConsumed) / Double(caloriesTarget) : 0,
                isOverTarget: caloriesConsumed > caloriesTarget
            ),
            macroSummary: MacroSummary(
                protein: MacroProgress(
                    consumed: proteinConsumed,
                    target: proteinTarget,
                    remaining: max(proteinTarget - proteinConsumed, 0),
                    progress: proteinTarget > 0 ? proteinConsumed / proteinTarget : 0
                ),
                carbs: MacroProgress(consumed: 0, target: 160, remaining: 160, progress: 0),
                fat: MacroProgress(consumed: 0, target: 60, remaining: 60, progress: 0)
            ),
            waterSummary: WaterSummary(
                consumedMl: waterConsumedMl,
                targetMl: waterTargetMl,
                remainingMl: max(waterTargetMl - waterConsumedMl, 0),
                progress: waterTargetMl > 0 ? Double(waterConsumedMl) / Double(waterTargetMl) : 0
            ),
            activity: ActivityTodayState(
                legacyWorkoutSummary: TodayWorkoutSummary(
                    workoutCaloriesBurned: hasWorkout ? 250 : 0,
                    workoutCount: hasWorkout ? 1 : 0,
                    hasWorkout: hasWorkout
                ),
                trainingIntegration: .connected,
                trainingDataSource: .appleHealth,
                appleHealthWorkoutCount: appleHealthWorkoutCount ?? (hasWorkout ? 1 : 0),
                stepsToday: nil,
                weeklyWorkoutCount: nil,
                stepGoalAssumption: nil,
                trainingFrequencyPerWeek: trainingFrequencyPerWeek,
                displayLine: hasWorkout ? "1 workout today" : "No Apple Health workout today",
                showsConnectCTA: false
            )
        )
    }

    private func status(
        for kind: TodayDailySummaryItemKind,
        in scorecard: TodayDailySummaryScorecardState
    ) -> TodayDailySummaryItemStatus {
        scorecard.items.first(where: { $0.kind == kind })?.status ?? .notApplicable
    }
}
